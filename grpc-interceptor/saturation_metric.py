import requests
from flask import Flask, Response
from prometheus_client import generate_latest, Gauge

app = Flask(__name__)

# Define the new gauge metric
sonic_lb_saturated = Gauge('sonic_lb_saturated', 'SONIC saturation metric', ['lb_name'])

def query_prometheus(query):
    url = 'http://prometheus-service.cms.geddes.rcac.purdue.edu:8080/api/v1/query'
    response = requests.get(url, params={'query': query})
    response.raise_for_status()  # Raises an HTTPError for bad responses
    return response.json()['data']['result']

def process_metrics():
    query = """
    max by (lb_name) (
        avg by (model, lb_name, version) (
            label_replace(irate(nv_inference_queue_duration_us{pod=~"triton-.*"}[5m]), "lb_name", "$1", "pod", "(.*)-(.*)-(.*)$")
            /
            (1000 * (1 + 
            label_replace(irate(nv_inference_request_success{pod=~"triton-.*"}[5m]), "lb_name", "$1", "pod", "(.*)-(.*)-(.*)$")
            ))
        )
    )
    """
    results = query_prometheus(query)
    threshold = 20 

    for result in results:
        lb_name = result['metric']['lb_name']
        value = float(result['value'][1])
        saturated_value = 1 if value > threshold else 0
        sonic_lb_saturated.labels(lb_name=lb_name).set(saturated_value)


@app.route('/metrics')
def metrics():
    process_metrics()
    return Response(generate_latest(), mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8002)
