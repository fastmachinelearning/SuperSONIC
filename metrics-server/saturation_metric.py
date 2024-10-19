import requests
import time
from flask import Flask, Response
from prometheus_client import generate_latest, Gauge
from ping3 import ping


app = Flask(__name__)


sonic_lb_saturated = Gauge('sonic_lb_saturated', 'SONIC saturation metric', ['lb_name'])
ping_latency = Gauge(
    'ping_latency_ms', 'Ping latency in milliseconds',
    [   'id',
        'name', 'ip',
        'latitude', 'longitude',
    ]
)


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


def measure_latency():
    ips_to_ping = [
        {"ip": "128.211.143.9", "name": "T2_US_Purdue", "lat": 40.4237, "lon": -86.9212},
        {"ip": "128.142.208.134", "name": "CERN LXPLUS", "lat": 46.2330, "lon": 6.0557},
        {"ip": "131.225.189.73", "name": "T1_US_FNAL", "lat": 41.8481, "lon": -88.2584},
        {"ip": "129.93.239.170", "name": "T2_US_Nebraska", "lat": 40.8202, "lon": -96.7005},
        {"ip": "144.92.180.76", "name": "T2_US_Wisconsin", "lat": 43.0766, "lon": -89.4125},
        {"ip": "169.228.130.105", "name": "T2_US_UCSD", "lat": 32.8812, "lon": -117.2344},
        {"ip": "198.32.43.67", "name": "T2_US_Caltech", "lat": 34.1377, "lon": -118.1253}, 
        {"ip": "128.227.64.205", "name": "T2_US_Florida", "lat": 29.6465, "lon": -82.3533}, # www.phys.ufl.edu
        {"ip": "18.12.1.172", "name": "T2_US_MIT", "lat": 42.3601, "lon": -71.0942}, 
        {"ip": "129.59.197.94", "name": "T2_US_Vanderbilt", "lat": 36.1447, "lon": -86.8027}, # xrootd
        {"ip": "128.55.126.10", "name": "NERSC", "lat": 37.875750, "lon": -122.252877}
    ]
    for data in ips_to_ping:
        name = data["name"]
        ip = data["ip"]
        lat = data["lat"]
        lon = data["lon"]

        latency = ping(ip, timeout=5)

        if latency:
            latency = latency * 1000

            print(name, latency)
            ping_latency.labels(
                id=name,
                name=name, 
                ip=ip,
                latitude=lat, 
                longitude=lon
            ).set(latency)

@app.route('/metrics')
def metrics():
    process_metrics()
    measure_latency()
    return Response(generate_latest(), mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8002)
