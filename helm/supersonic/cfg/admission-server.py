#!/usr/bin/env python3
"""Envoy sidecar: start the first GPU Triton on RepositoryIndex."""

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
GPU_DEPLOYMENT = os.environ.get("GPU_DEPLOYMENT", "")
SCALEDOBJECT_NAME = os.environ.get("SCALEDOBJECT_NAME", "")
IDLE_MIN_REPLICAS = int(os.environ.get("IDLE_MIN_REPLICAS", "0"))
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "8080"))

_lock = threading.Lock()
_last_wake = 0.0
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


def demand_active():
    with _lock:
        return time.time() - _last_wake < HOLD_TTL


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


def wake():
    with _lock:
        global _last_wake
        _last_wake = time.time()
    ensure_gpu_replica()


def _watch_loop():
    last_scale_check = 0.0
    while True:
        now = time.time()
        if demand_active() and now - last_scale_check >= 2:
            ensure_gpu_replica()
            last_scale_check = now
        elif not demand_active():
            release_scale_hold()
        time.sleep(0.5)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    close_connection = True

    def log_message(self, fmt, *args):
        print(f"admission: {fmt % args}", flush=True)

    def _send(self, code, body):
        payload = body.encode("utf-8")
        self.close_connection = True
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
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
            wake()
            self._send(200, "ok\n")
            return
        if path == "/idle":
            time.sleep(1)
            self._send(200, "ok\n")
            return
        self._send(404, "not found\n")


def main():
    watcher = threading.Thread(target=_watch_loop, name="gpu-watch", daemon=True)
    watcher.start()
    server = ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), Handler)
    print(
        f"admission: listening on :{LISTEN_PORT} deployment={GPU_DEPLOYMENT}",
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
