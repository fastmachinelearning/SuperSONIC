![Version](https://img.shields.io/github/v/release/fastmachinelearning/SuperSONIC)
![License](https://img.shields.io/github/license/fastmachinelearning/SuperSONIC)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/supersonic)](https://artifacthub.io/packages/search?repo=supersonic)
![Downloads](https://img.shields.io/github/downloads/fastmachinelearning/SuperSONIC/total)


# SuperSONIC

The [SuperSONIC](http://fastmachinelearning.org/SuperSONIC/ "SuperSONIC") project implements server infrastructure for **inference-as-a-service**
applications in large high energy physics (HEP) and multi-messenger astrophysics
(MMA) experiments. The server infrastructure is designed for deployment at [Kubernetes](https://kubernetes.io) clusters equipped with GPUs.

The main components of SuperSONIC are:
- [Nvidia Triton](https://developer.nvidia.com/triton-inference-server) inference servers
- Dynamic muti-purpose [Envoy Proxy](envoyproxy.io):
  - Load balancing
  - Client connection rate limiting
  - GPU saturation prevention
  - Token-based authentication
- Load-based autoscaling via [KEDA](keda.sh)


## Installation

```
helm repo add supersonic https://fastmachinelearning.org/SuperSONIC
helm install <release-name> supersonic/supersonic --values <your-values.yaml> -n <namespace>
```

To construct the `values.yaml` file for your application, follow [Configuration guide](http://fastmachinelearning.org/SuperSONIC/configuration-guide.html "Configuration guide").

The full list of configuration parameters is available in the [Configuration reference](http://fastmachinelearning.org/SuperSONIC/configuration-reference.html "Configuration reference").


## Server diagram

<p align="center">
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/master/docs/img/diagram.svg" alt="diagram" width="700"/>
</p>

## Status of deployment

|  | **[CMS](https://home.cern/science/experiments/cms)**      | **[ATLAS](https://home.cern/science/experiments/atlas)**    | **[IceCube](https://icecube.wisc.edu)**  |
|:---|:---:|:---:|:---:|
| **[Geddes cluster](https://www.rcac.purdue.edu/compute/geddes) (Purdue)**   | ✅ | - | - |
| **[Nautilus cluster](https://docs.nationalresearchplatform.org) (NRP)**    | ✅  |  ⏳ |   ✅   |
