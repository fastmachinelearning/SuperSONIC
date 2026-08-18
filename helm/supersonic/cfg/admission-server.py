#!/usr/bin/env python3
"""Envoy sidecar: start the first GPU Triton on RepositoryIndex and wait until it is Ready."""

import json
import os
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
NS_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/namespace"

HOLD_TTL = int(os.environ.get("HOLD_MIN_REPLICAS_SECONDS", "300"))
READY_TIMEOUT = int(os.environ.get("READY_TIMEOUT_SECONDS", "300"))
GPU_DEPLOYMENT = os.environ.get("GPU_DEPLOYMENT", "")
SCALEDOBJECT_NAME = os.environ.get("SCALEDOBJECT_NAME", "")
IDLE_MIN_REPLICAS = int(os.environ.get("IDLE_MIN_REPLICAS", "0"))
TRITON_READY_URL = os.environ.get("TRITON_READY_URL", "")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "8080"))

_lock = threading.Lock()
_last_wake = 0.0
_ready = False
_so_held = False


def _namespace():
    with open(NS_PATH, encoding="utf-8") as fh:
        return fh.read().strip()


def _token():
    with open(TOKEN_PATH, encoding="utf-8") as fh:
        return fh.read().strip()


def _ssl_context():
    return ssl.create_default_context(cafile=CA_PATH)


def _api_url(path):
    host = os.environ["KUBERNETES_SERVICE_HOST"]
    port = os.environ["KUBERNETES_SERVICE_PORT"]
    return f"https://{host}:{port}{path}"


def _api_request(method, path, data=None):
    body = None
    headers = {"Authorization": f"Bearer {_token()}"}
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        headers["Content-Type"] = "application/merge-patch+json"
    req = urllib.request.Request(
        _api_url(path), data=body, headers=headers, method=method
    )
    with urllib.request.urlopen(req, context=_ssl_context(), timeout=3) as resp:
        return json.load(resp)


def triton_ready():
    if not TRITON_READY_URL:
        return False
    try:
        req = urllib.request.Request(TRITON_READY_URL, method="GET")
        with urllib.request.urlopen(req, timeout=2) as resp:
            return 200 <= resp.status < 300
    except (urllib.error.URLError, TimeoutError, OSError):
        return False


def demand_active():
    with _lock:
        return time.time() - _last_wake < HOLD_TTL


def is_ready():
    with _lock:
        return _ready


def set_scaledobject_min(min_replicas):
    if not SCALEDOBJECT_NAME:
        return
    ns = _namespace()
    path = f"/apis/keda.sh/v1alpha1/namespaces/{ns}/scaledobjects/{SCALEDOBJECT_NAME}"
    try:
        current = _api_request("GET", path)
        current_min = int((current.get("spec") or {}).get("minReplicaCount") or 0)
        if current_min == min_replicas:
            return
        _api_request("PATCH", path, {"spec": {"minReplicaCount": min_replicas}})
        print(
            f"admission: ScaledObject {SCALEDOBJECT_NAME} minReplicaCount {current_min} -> {min_replicas}",
            flush=True,
        )
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:300]
        print(f"admission: ScaledObject HTTP {exc.code}: {body}", flush=True)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError, ValueError) as exc:
        print(f"admission: ScaledObject patch failed: {exc}", flush=True)


def ensure_gpu_replica():
    """Keep KEDA min at 1 and scale the GPU Deployment to at least 1."""
    global _so_held
    set_scaledobject_min(1)
    _so_held = True
    if not GPU_DEPLOYMENT:
        return
    ns = _namespace()
    path = f"/apis/apps/v1/namespaces/{ns}/deployments/{GPU_DEPLOYMENT}/scale"
    try:
        current = _api_request("GET", path)
        replicas = int((current.get("spec") or {}).get("replicas") or 0)
        if replicas >= 1:
            return
        _api_request("PATCH", path, {"spec": {"replicas": 1}})
        print(f"admission: scaled {GPU_DEPLOYMENT} 0 -> 1", flush=True)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:300]
        print(f"admission: scale {GPU_DEPLOYMENT} HTTP {exc.code}: {body}", flush=True)
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError, ValueError) as exc:
        print(f"admission: scale {GPU_DEPLOYMENT} failed: {exc}", flush=True)


def release_scale_hold():
    global _so_held
    if not _so_held:
        return
    set_scaledobject_min(IDLE_MIN_REPLICAS)
    _so_held = False


def wait_until_ready():
    deadline = time.time() + READY_TIMEOUT
    while time.time() < deadline:
        if is_ready():
            return True
        time.sleep(0.5)
    return is_ready()


def wake():
    with _lock:
        global _last_wake
        _last_wake = time.time()
    ensure_gpu_replica()
    return wait_until_ready()


def _watch_loop():
    global _ready
    last_scale_check = 0.0
    while True:
        now = time.time()
        if demand_active() and now - last_scale_check >= 2:
            ensure_gpu_replica()
            last_scale_check = now
        elif not demand_active():
            release_scale_hold()
        ready = triton_ready()
        with _lock:
            _ready = ready
        time.sleep(0.5)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    close_connection = True

    def log_message(self, fmt, *args):
        print(f"admission: {fmt % args}", flush=True)

    def _send(self, code, body, content_type="text/plain"):
        payload = body if isinstance(body, bytes) else body.encode("utf-8")
        self.close_connection = True
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(payload)
        self.wfile.flush()

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/health":
            self._send(200, "ok\n")
            return
        if path == "/wake":
            if wake():
                self._send(200, "ready\n")
            else:
                self._send(503, "not-ready\n")
            return
        if path == "/ready":
            if is_ready():
                self._send(200, "ready\n")
            else:
                self._send(503, "not-ready\n")
            return
        self._send(404, "not found\n")


def main():
    watcher = threading.Thread(target=_watch_loop, name="gpu-watch", daemon=True)
    watcher.start()
    server = ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), Handler)
    print(
        f"admission: listening on :{LISTEN_PORT} ready_url={TRITON_READY_URL}",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
