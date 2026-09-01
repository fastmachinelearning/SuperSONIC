#!/usr/bin/env python3
"""Scale Triton to at least max(1, minReplicaCount) replicas on /wake."""

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
TRITON_DEPLOYMENT = os.environ.get("GPU_DEPLOYMENT", "")
SCALEDOBJECT_NAME = os.environ.get("SCALEDOBJECT_NAME", "")
IDLE_MIN_REPLICAS = int(os.environ.get("IDLE_MIN_REPLICAS", "0"))
# On wake, scale to the configured minReplicaCount, but never below one replica.
WAKE_MIN_REPLICAS = max(1, IDLE_MIN_REPLICAS)
# The hold deadline is shared between all Envoy replicas as an annotation on the
# ScaledObject (unix seconds), so one sidecar cannot release a peer's active hold
# and an expired hold survives sidecar restarts.
HOLD_ANNOTATION = "supersonic.fastmachinelearning.org/hold-until"
LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "8080"))

# _state_lock guards _last_wake and is never held across Kubernetes API calls,
# so /wake handlers do not queue behind slow API traffic. _scale_lock serializes
# the API scaling passes themselves and guards _scaled_object_held, which only
# controls how eagerly this sidecar checks for release; the authoritative hold
# state is the HOLD_ANNOTATION on the ScaledObject.
_state_lock = threading.Lock()
_scale_lock = threading.Lock()
_last_wake = 0.0
_scaled_object_held = False
_ssl_ctx = None
_namespace_name = None


class ApiError(Exception):
    pass


def _log(message):
    print(f"admission: {message}", flush=True)


def _namespace():
    global _namespace_name
    if _namespace_name is None:
        with open(NS_PATH, encoding="utf-8") as fh:
            _namespace_name = fh.read().strip()
    return _namespace_name


def _token():
    with open(TOKEN_PATH, encoding="utf-8") as fh:
        return fh.read().strip()


def _ssl_context():
    global _ssl_ctx
    if _ssl_ctx is None:
        _ssl_ctx = ssl.create_default_context(cafile=CA_PATH)
    return _ssl_ctx


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
    try:
        with urllib.request.urlopen(req, context=_ssl_context(), timeout=3) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:300]
        raise ApiError(f"HTTP {exc.code}: {detail}") from exc
    except (urllib.error.URLError, TimeoutError, OSError, KeyError) as exc:
        raise ApiError(str(exc)) from exc
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ApiError(f"invalid JSON: {exc}") from exc


def _spec_int(obj, key, default=0):
    value = (obj.get("spec") or {}).get(key, default)
    if value is None:
        value = default
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ApiError(f"invalid spec.{key}: {exc}") from exc


def _hold_active():
    with _state_lock:
        return time.time() - _last_wake < HOLD_TTL


def _so_path():
    return (
        f"/apis/keda.sh/v1alpha1/namespaces/{_namespace()}"
        f"/scaledobjects/{SCALEDOBJECT_NAME}"
    )


def _hold_until(scaled_object):
    annotations = (scaled_object.get("metadata") or {}).get("annotations") or {}
    try:
        return float(annotations[HOLD_ANNOTATION])
    except (KeyError, TypeError, ValueError):
        return None


def ensure_triton_replica(extend_hold=False):
    """Raise the ScaledObject minimum and the Triton Deployment to the wake target.

    With extend_hold, also advance the shared hold annotation to now + HOLD_TTL
    in the same patch (it is only ever moved forward)."""
    global _scaled_object_held
    try:
        scaled_object = _api_request("GET", _so_path())
        current_min = _spec_int(scaled_object, "minReplicaCount")
        patch = {}
        if current_min != WAKE_MIN_REPLICAS:
            patch["spec"] = {"minReplicaCount": WAKE_MIN_REPLICAS}
        if extend_hold:
            new_until = int(time.time()) + HOLD_TTL
            current_until = _hold_until(scaled_object)
            if current_until is None or current_until < new_until:
                patch["metadata"] = {"annotations": {HOLD_ANNOTATION: str(new_until)}}
        if patch:
            _api_request("PATCH", _so_path(), patch)
            if "spec" in patch:
                _log(
                    f"ScaledObject {SCALEDOBJECT_NAME} minReplicaCount {current_min} -> {WAKE_MIN_REPLICAS}"
                )
    except ApiError as exc:
        _log(f"ScaledObject {SCALEDOBJECT_NAME}: {exc}")
        return False
    _scaled_object_held = True
    path = (
        f"/apis/apps/v1/namespaces/{_namespace()}/deployments/{TRITON_DEPLOYMENT}/scale"
    )
    try:
        current = _api_request("GET", path)
        replicas = _spec_int(current, "replicas")
        if replicas < WAKE_MIN_REPLICAS:
            _api_request("PATCH", path, {"spec": {"replicas": WAKE_MIN_REPLICAS}})
            _log(f"scaled {TRITON_DEPLOYMENT} {replicas} -> {WAKE_MIN_REPLICAS}")
        return True
    except ApiError as exc:
        _log(f"scale {TRITON_DEPLOYMENT}: {exc}")
        return False


def maybe_release(assume_held=False):
    """Restore the idle minimum once the shared hold annotation has expired.

    Any sidecar may release an expired hold (including one left behind by a
    restarted peer), and none releases while the annotation is still in the
    future. With assume_held, a missing annotation is treated as our own
    expired hold. Returns False only on an API error."""
    global _scaled_object_held
    try:
        scaled_object = _api_request("GET", _so_path())
        hold_until = _hold_until(scaled_object)
        if hold_until is not None and time.time() < hold_until:
            # A hold (possibly a peer's) is still active; its owner or the
            # periodic sweep will release it later.
            _scaled_object_held = False
            return True
        current_min = _spec_int(scaled_object, "minReplicaCount")
        patch = {}
        if hold_until is not None:
            patch["metadata"] = {"annotations": {HOLD_ANNOTATION: None}}
        if current_min != IDLE_MIN_REPLICAS and (hold_until is not None or assume_held):
            patch["spec"] = {"minReplicaCount": IDLE_MIN_REPLICAS}
        if patch:
            _api_request("PATCH", _so_path(), patch)
            if "spec" in patch:
                _log(
                    f"ScaledObject {SCALEDOBJECT_NAME} minReplicaCount {current_min} -> {IDLE_MIN_REPLICAS}"
                )
        _scaled_object_held = False
        return True
    except ApiError as exc:
        _log(f"ScaledObject {SCALEDOBJECT_NAME}: {exc}")
        return False


def wake():
    global _last_wake
    with _state_lock:
        _last_wake = time.time()
    with _scale_lock:
        return ensure_triton_replica(extend_hold=True)


def _watch_loop():
    last_reassert = 0.0
    last_sweep = 0.0
    while True:
        try:
            now = time.time()
            if _hold_active():
                if now - last_reassert >= 2:
                    with _scale_lock:
                        ensure_triton_replica()
                    last_reassert = now
            elif _scaled_object_held:
                with _scale_lock:
                    # Re-check: a wake may have landed since the check above.
                    if not _hold_active():
                        maybe_release(assume_held=True)
            elif now - last_sweep >= 60:
                # Backstop: release an expired hold left behind by a crashed or
                # restarted sidecar (ours or a peer's).
                with _scale_lock:
                    maybe_release()
                last_sweep = now
        except Exception as exc:
            _log(f"watch: {exc}")
        time.sleep(0.5)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    close_connection = True

    def log_message(self, fmt, *args):
        _log(fmt % args)

    def _send(self, code, body):
        payload = body.encode("utf-8")
        self.close_connection = True
        try:
            self.send_response(code)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(payload)
            self.wfile.flush()
        except OSError as exc:
            _log(f"write failed: {exc}")

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/health":
            self._send(200, "ok\n")
            return
        if path == "/wake":
            try:
                ok = wake()
            except Exception as exc:
                _log(f"/wake: {exc}")
                ok = False
            self._send(200 if ok else 503, "ok\n" if ok else "scale failed\n")
            return
        if path == "/sleep":
            # Delay primitive for the Envoy Lua filter, which cannot sleep on its
            # own: it paces its healthy-upstream poll loop by calling this endpoint.
            time.sleep(1)
            self._send(200, "ok\n")
            return
        self._send(404, "not found\n")


def main():
    if not TRITON_DEPLOYMENT or not SCALEDOBJECT_NAME:
        raise SystemExit(
            "admission: GPU_DEPLOYMENT and SCALEDOBJECT_NAME are required"
        )
    try:
        _namespace()
        _ssl_context()
        _token()
    except OSError as exc:
        raise SystemExit(f"admission: cannot read service account: {exc}") from exc
    watcher = threading.Thread(target=_watch_loop, name="scale-watch", daemon=True)
    watcher.start()
    server = ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler)
    _log(f"listening on {LISTEN_HOST}:{LISTEN_PORT} deployment={TRITON_DEPLOYMENT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
