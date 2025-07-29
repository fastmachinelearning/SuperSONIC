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

### Install from Helm repository

```
helm repo add fastml https://fastmachinelearning.org/SuperSONIC
helm repo update
helm install <release-name> fastml/supersonic -n <namespace> -f <your-values.yaml>
```

To construct the `values.yaml` file for your application, follow [Configuration guide](http://fastmachinelearning.org/SuperSONIC/configuration-guide.html "Configuration guide").

The full list of configuration parameters is available in the [Configuration reference](http://fastmachinelearning.org/SuperSONIC/configuration-reference.html "Configuration reference").

### Install from GitHub 

```
git clone https://github.com/fastmachinelearning/SuperSONIC.git
cd SuperSONIC
git checkout <branch-or-commit>
helm dependency build helm/supersonic
helm install <release-name> helm/supersonic -n <namespace> -f <your-values.yaml>
```

## Server diagram

<p align="center">
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/diagram.svg#gh-light-mode-only" alt="diagram" width="700"/>
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/diagram-dark.svg#gh-dark-mode-only" alt="diagram-dark" width="700"/>
</p>

## Publications

```bibtex
@inproceedings{10.1145/3708035.3736049,
author = {Kondratyev, Dmitry and Riedel, Benedikt and Chou, Yuan-Tang and Cochran-Branson, Miles and Paladino, Noah and Schultz, David and Liu, Mia and Duarte, Javier and Harris, Philip and Hsu, Shih-Chieh},
title = {SuperSONIC: Cloud-Native Infrastructure for ML Inferencing},
year = {2025},
isbn = {9798400713989},
publisher = {Association for Computing Machinery},
address = {New York, NY, USA},
url = {https://doi.org/10.1145/3708035.3736049},
doi = {10.1145/3708035.3736049},
booktitle = {Practice and Experience in Advanced Research Computing 2025: The Power of Collaboration},
articleno = {29},
numpages = {5},
keywords = {heterogeneous computing, machine learning, inference as a service},
location = {
},
series = {PEARC '25}
}
```

## Status of deployment

|  | **[CMS](https://home.cern/science/experiments/cms)**      | **[ATLAS](https://home.cern/science/experiments/atlas)**    | **[IceCube](https://icecube.wisc.edu)**  |
|:---|:---:|:---:|:---:|
| **[Purdue Geddes](https://www.rcac.purdue.edu/compute/geddes)**   | ✅ | - | - |
| **[Purdue Anvil](https://www.rcac.purdue.edu/compute/anvil)**   | ✅ | - | - |
| **[NRP Nautilus](https://docs.nationalresearchplatform.org)**    | ✅  |  ✅ |   ✅   |
| **[UChicago](https://af.uchicago.edu/)**    |  -  |  ✅ |   -   |
