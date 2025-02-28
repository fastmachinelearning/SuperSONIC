#!/usr/bin/env python3

import os
import time
import requests
import logging
from prometheus_client import start_http_server, Gauge
from kubernetes import client, config

# Configure logging based on environment variable
log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
logging.basicConfig(
    level=getattr(logging, log_level, logging.INFO),
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)
logger.info(f"Log level set to {log_level}")

# Initialize Prometheus metrics
logger.info("Initializing Prometheus metrics")
MODEL_STATUS = Gauge(
    'supersonic_triton_model_status',
    'Model status on Triton server',
    ['model_name', 'version', 'state', 'server_pod']
)

MODEL_VERSION_COUNT = Gauge(
    'supersonic_triton_model_version_count',
    'Number of servers a specific model version is loaded into',
    ['model_name', 'version', 'state']
)

def get_triton_pods():
    """Get all Triton server pods in the current namespace."""
    logger.info("Getting Triton pods from Kubernetes API")
    try:
        config.load_incluster_config()
        logger.info("Loaded in-cluster Kubernetes config")
    except config.ConfigException:
        logger.warning("Failed to load in-cluster config, falling back to local kubeconfig")
        config.load_kube_config()
    
    v1 = client.CoreV1Api()
    namespace = os.getenv('NAMESPACE', 'default')
    label_selector = 'app.kubernetes.io/component=triton'
    logger.info(f"Searching for Triton pods in namespace {namespace} with labels {label_selector}")
    
    pods = v1.list_namespaced_pod(
        namespace=namespace,
        label_selector=label_selector
    )
    running_pods = [(pod.metadata.name, pod.status.pod_ip) for pod in pods.items if pod.status.phase == 'Running']
    logger.info(f"Found {len(running_pods)} running Triton pods: {running_pods}")
    return running_pods

def get_loaded_models(pod_ip):
    """Query a Triton server for its loaded models."""
    logger.info(f"Querying models from Triton server at {pod_ip}")
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
    }
    try:
        # First check if server is ready
        health_url = f'http://{pod_ip}:8000/v2/health/ready'
        logger.debug(f"Checking server health at {health_url}")
        health_response = requests.get(health_url, headers=headers, timeout=5)
        if health_response.status_code != 200:
            logger.warning(f"Server at {pod_ip} is not ready, status code: {health_response.status_code}")
            return []

        # Get model repository index
        url = f'http://{pod_ip}:8000/v2/repository/index'
        logger.debug(f"Making HTTP POST request to {url}")
        response = requests.post(url, headers=headers, json={}, timeout=5)
        
        if response.status_code == 200:
            try:
                models = response.json()
                if not isinstance(models, list):
                    logger.warning(f"Unexpected response format from {pod_ip}: {models}")
                    return []
                logger.info(f"Found {len(models)} models on {pod_ip}: {models}")
                return models
            except ValueError as e:
                logger.error(f"Failed to parse JSON response from {pod_ip}: {str(e)}")
                return []
        else:
            logger.warning(f"Failed to get models from {pod_ip}, status code: {response.status_code}, response: {response.text}")
            return []
    except requests.exceptions.Timeout:
        logger.error(f"Timeout querying Triton server at {pod_ip}")
        return []
    except requests.exceptions.RequestException as e:
        logger.error(f"Error querying Triton server at {pod_ip}: {str(e)}")
        return []

def update_metrics():
    """Update Prometheus metrics based on current state."""
    logger.info("Starting metrics update cycle")
    
    # Clear existing metrics
    logger.debug("Clearing existing metrics")
    MODEL_STATUS.clear()
    MODEL_VERSION_COUNT.clear()
    
    # Get current state
    pods = get_triton_pods()
    model_version_count = {}
    
    # Update metrics for each pod
    for pod_name, pod_ip in pods:
        logger.info(f"Processing pod {pod_name} ({pod_ip})")
        models = get_loaded_models(pod_ip)
        for model in models:
            model_key = (model['name'], model['version'], model['state'])
            logger.debug(f"Setting model status for {model_key} on {pod_name}")
            
            # Set individual model status
            MODEL_STATUS.labels(
                model_name=model['name'],
                version=model['version'],
                state=model['state'],
                server_pod=pod_name
            ).set(1)
            
            # Update version count
            model_version_count[model_key] = model_version_count.get(model_key, 0) + 1
    
    # Update model version count metrics
    logger.info("Updating model version count metrics")
    for (name, version, state), count in model_version_count.items():
        logger.debug(f"Setting version count metric for {name}:{version} ({state}): {count}")
        MODEL_VERSION_COUNT.labels(
            model_name=name,
            version=version,
            state=state
        ).set(count)
    
    logger.info("Metrics update cycle completed")

def main():
    """Main function to run the metrics server."""
    logger.info("Starting model loader metrics server")
    
    # Start Prometheus HTTP server
    port = 8080
    logger.info(f"Starting Prometheus HTTP server on port {port}")
    start_http_server(port)
    
    # Update metrics periodically
    interval = 30
    logger.info(f"Entering main loop with {interval} second update interval")
    while True:
        try:
            update_metrics()
        except Exception as e:
            logger.error(f"Error in metrics update cycle: {str(e)}", exc_info=True)
        
        logger.debug(f"Sleeping for {interval} seconds")
        time.sleep(interval)

if __name__ == '__main__':
    main() 