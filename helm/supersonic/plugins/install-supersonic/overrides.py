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

    # Define overrides as YAML template
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

    return overrides