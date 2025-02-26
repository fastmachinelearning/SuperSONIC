import yaml
from typing import Dict

def generate_overrides(release_name: str, values: Dict) -> Dict:
    """Generate overrides to ensure internal consistency of SuperSONIC components"""

    # This will be changed in the future
    prometheus_host = values.get("prometheus", {}).get("host", "").split("//")[-1]
    grafana_host = values.get("grafana", {}).get("host", "").split("//")[-1]

    if values.get("prometheus", {}).get("external", {}).get("enabled", False):
        prometheus_server = values.get("prometheus", {}).get("external", {}).get("url", "")
        prometheus_server = "https://" + prometheus_server.split("//")[-1]
    elif values.get("prometheus", {}).get("enabled", False):
        prometheus_server = f"http://{release_name}-prometheus-server:9090"
    else:
        prometheus_server = ""

    # Start with overrides template
    overrides_yaml = f"""
prometheus:
  server:
    useExistingClusterRoleName: {release_name}-prometheus-role
    ingress:
      hosts: [{prometheus_host}]
      tls:
        - hosts: [{prometheus_host}]
  serviceAccounts:
    server:
      name: {release_name}-prometheus-sa

grafana:
  dashboardsConfigMaps:
    default: {release_name}-grafana-default-dashboard
  datasources:
    datasources.yaml:
      datasources:
        - name: prometheus
          type: prometheus
          access: proxy
          isDefault: true
          url: {prometheus_server}
          jsonData:
            timeInterval: "5s"
            tlsSkipVerify: true
        - name: tempo
          type: tempo
          url: http://{release_name}-tempo:3100
          access: proxy
          isDefault: false
          basicAuth: false
          jsonData:
            timeInterval: "5s"
            tlsSkipVerify: true
            serviceMap:
              datasourceUid: 'prometheus'
            nodeGraph:
              enabled: true
  ingress:
    hosts: [{grafana_host}]
    tls:
      - hosts: [{grafana_host}]
  grafana.ini:
    server:
      root_url: https://{grafana_host}
"""
    # Parse YAML string into dictionary
    overrides = yaml.safe_load(overrides_yaml)

    # Clean up empty values
    if not prometheus_host:
        del overrides["prometheus"]["server"]["ingress"]
    if not grafana_host:
        del overrides["grafana"]["ingress"]
        del overrides["grafana"]["grafana.ini"]

    # Add OpenTelemetry configuration to Triton args if enabled
    if values.get("opentelemetry-collector", {}).get("enabled", False):
        # Get existing args from values
        triton_args = values.get("triton", {}).get("args", [])
        sampling_rate = values.get("tracing_sampling_rate", 0.01)
        if triton_args and sampling_rate>0:
            # Get the first (and should be only) argument string
            args_str = triton_args[0]
            # Remove the last line continuation if it exists
            args_str = args_str.rstrip(" \\\n")
            # Calculate sampling rate for Triton (1/sampling)
            
            sampling = max(1, int(1/sampling_rate))
            # Add OpenTelemetry flags
            args_str += " \\\n"
            args_str += "--trace-config mode=opentelemetry \\\n"
            args_str += "--trace-config=opentelemetry,resource=pod_name=$(hostname) \\\n"
            args_str += f"--trace-config opentelemetry,url={release_name}-opentelemetry-collector:4318/v1/traces \\\n"
            args_str += f"--trace-config rate={sampling} \\\n"
            args_str += "--trace-config level=TIMESTAMPS \\\n"
            args_str += "--trace-config count=-1"
            
            overrides["triton"] = {"args": [args_str]}

    return overrides