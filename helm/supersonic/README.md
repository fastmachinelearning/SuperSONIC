![Version](https://img.shields.io/github/v/release/fastmachinelearning/SuperSONIC)
[![DOI](https://zenodo.org/badge/876768230.svg)](https://doi.org/10.5281/zenodo.14815348)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/supersonic)](https://artifacthub.io/packages/search?repo=supersonic)
![Downloads](https://img.shields.io/github/downloads/fastmachinelearning/SuperSONIC/total)
![License](https://img.shields.io/github/license/fastmachinelearning/SuperSONIC)

<h1>
<span style="margin: -10px -10px -10px -5px">
  <img src="./docs/img/SuperSONIC_small_light_128.png#gh-dark-mode-only" alt="logo" height="40">
  <img src="./docs/img/SuperSONIC_small_128.png#gh-light-mode-only" alt="logo" height="40">
</span>
   SuperSONIC
</h1>

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
- (optional) [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) and [Grafana Tempo](https://grafana.com/docs/tempo/latest/) for advanced monitoring.


## Installation

The installation is done via a custom Helm plugin which takes care of
internal connectivity of the chart components. Standard Helm installation
is also supported, but requires a lot more manual configuration.

```
helm plugin install https://github.com/fastmachinelearning/SuperSONIC/
helm install-supersonic <release-name> -n <namespace> -f <your-values.yaml>
```

Installer plugin usage:
```
Usage:
  helm install-supersonic [RELEASE_NAME] [flags]

Flags:
  -h, --help              Show this help message
  -f, --values            Specify values file for custom configuration
  -n, --namespace         Specify Kubernetes namespace for deployment
  --version               Specify chart version (default: latest version)
                          Note: Ignored if --local flag is set
  --local                 Install from local chart path instead of remote repository
  --path                  Local chart path (default: ./helm/supersonic)
                          Only used when --local flag is set
Additional flags will be passed directly to the 'helm install' command
```

To construct the `values.yaml` file for your application, follow [Configuration guide](http://fastmachinelearning.org/SuperSONIC/configuration-guide.html "Configuration guide").

The full list of configuration parameters is available in the [Configuration reference](http://fastmachinelearning.org/SuperSONIC/configuration-reference.html "Configuration reference").


## Server diagram

<p align="center">
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/diagram.svg#gh-light-mode-only" alt="diagram" width="700"/>
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/diagram-dark.svg#gh-dark-mode-only" alt="diagram-dark" width="700"/>
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
| **[UChicago](https://af.uchicago.edu/)**    |  -  |  ✅ |   -   |
