![Version](https://img.shields.io/github/v/release/fastmachinelearning/SuperSONIC)
[![DOI](https://zenodo.org/badge/876768230.svg)](https://doi.org/10.5281/zenodo.14815348)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/supersonic)](https://artifacthub.io/packages/search?repo=supersonic)
![Downloads](https://img.shields.io/github/downloads/fastmachinelearning/SuperSONIC/total)
![License](https://img.shields.io/github/license/fastmachinelearning/SuperSONIC)

# SuperSONIC

The [SuperSONIC](http://fastmachinelearning.org/SuperSONIC/ "SuperSONIC") project implements server infrastructure for **inference-as-a-service**
applications in large high energy physics (HEP) and multi-messenger astrophysics
(MMA) experiments. The server infrastructure is designed for deployment at [Kubernetes](https://kubernetes.io) clusters equipped with GPUs.

The main components of SuperSONIC are:
- [Nvidia Triton](https://developer.nvidia.com/triton-inference-server) inference servers
- Dynamic muti-purpose [Envoy Proxy](envoyproxy.io):
  - Load balancing
  - Rate limiting
  - GPU saturation prevention
  - Token-based authentication
- (optional) Load-based autoscaling via [KEDA](keda.sh)
- (optional) [Prometheus](https://prometheus.io) instance (deploy custom or connect to existing)
- (optional) Pre-configured [Grafana](https://grafana.com) dashboard
- (optional) [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) and [Tempo](https://opentelemetry.io/docs/tempo/) for advanced monitoring.


## Installation

```
helm repo add fastml https://fastmachinelearning.org/SuperSONIC
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install <release-name> fastml/supersonic --values <your-values.yaml> -n <namespace>
```

To construct the `values.yaml` file for your application, follow [Configuration guide](http://fastmachinelearning.org/SuperSONIC/configuration-guide.html "Configuration guide").

The full list of configuration parameters is available in the [Configuration reference](http://fastmachinelearning.org/SuperSONIC/configuration-reference.html "Configuration reference").


## Server diagram

<p align="center">
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/diagram.svg" alt="diagram" width="700"/>
</p>

## Grafana dashboard

<p align="center">
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/grafana.png" alt="grafana" width="700"/>
</p>

## Status of deployment

|  | **[CMS](https://home.cern/science/experiments/cms)**      | **[ATLAS](https://home.cern/science/experiments/atlas)**    | **[IceCube](https://icecube.wisc.edu)**  |
|:---|:---:|:---:|:---:|
| **[Purdue Geddes](https://www.rcac.purdue.edu/compute/geddes)**   | ✅ | - | - |
| **[Purdue Anvil](https://www.rcac.purdue.edu/compute/anvil)**   | ✅ | - | - |
| **[NRP Nautilus](https://docs.nationalresearchplatform.org)**    | ✅  |  ✅ |   ✅   |
