import requests
import flask
import os
from flask import Flask, Response

app = Flask(__name__)

PROMETHEUS_URL = os.environ.get('PROMETHEUS_URL')
if not PROMETHEUS_URL:
    raise ValueError("PROMETHEUS_URL environment variable must be set")

@app.route("/metrics")
def metrics():
    metrics_output = []
    gpu_uuids = []
    
    try:
        response = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={"query": "nv_gpu_utilization"})
        if response.status_code == 200:
            data = response.json()
            if data["data"]["result"]:
                gpu_uuids = [result["metric"].get("gpu_uuid", "GPU-unknown") for result in data["data"]["result"]]
    except Exception as e:
        print("Error getting GPU UUIDs: " + str(e))
        gpu_uuids = ["GPU-unknown"]

    metric_queries = {
        "nv_pinned_memory_pool_used_bytes": {
            "help": "# HELP nv_pinned_memory_pool_used_bytes Pinned memory pool used in bytes",
            "type": "# TYPE nv_pinned_memory_pool_used_bytes gauge"
        },
        "nv_gpu_utilization": {
            "help": "# HELP nv_gpu_utilization GPU utilization rate [0.0 - 1.0)",
            "type": "# TYPE nv_gpu_utilization gauge"
        },
        "nv_gpu_memory_total_bytes": {
            "help": "# HELP nv_gpu_memory_total_bytes GPU total memory, in bytes",
            "type": "# TYPE nv_gpu_memory_total_bytes gauge"
        },
        "nv_gpu_memory_used_bytes": {
            "help": "# HELP nv_gpu_memory_used_bytes GPU used memory, in bytes",
            "type": "# TYPE nv_gpu_memory_used_bytes gauge"
        },
        "nv_gpu_power_usage": {
            "help": "# HELP nv_gpu_power_usage GPU power usage in watts",
            "type": "# TYPE nv_gpu_power_usage gauge"
        },
        "nv_gpu_power_limit": {
            "help": "# HELP nv_gpu_power_limit GPU power management limit in watts",
            "type": "# TYPE nv_gpu_power_limit gauge"
        }
    }

    for metric_name, metric_info in metric_queries.items():
        metrics_output.extend([metric_info["help"], metric_info["type"]])
        try:
            response = requests.get(PROMETHEUS_URL + "/api/v1/query", params={"query": metric_name})
            if response.status_code == 200:
                data = response.json()
                if data["data"]["result"]:
                    for result in data["data"]["result"]:
                        value = result["value"][1]
                        gpu_uuid = result["metric"].get("gpu_uuid", "GPU-unknown")
                        metrics_output.append(metric_name + "{gpu_uuid=\"" + gpu_uuid + "\"} " + str(value))
                else:
                    for gpu_uuid in gpu_uuids:
                        metrics_output.append(metric_name + "{gpu_uuid=\"" + gpu_uuid + "\"} 0")
        except Exception as e:
            print("Error querying " + metric_name + ": " + str(e))
            for gpu_uuid in gpu_uuids:
                metrics_output.append(metric_name + "{gpu_uuid=\"" + gpu_uuid + "\"} 0")

    return Response("\n".join(metrics_output), mimetype="text/plain")

@app.route("/health")
def health():
    return "Healthy"