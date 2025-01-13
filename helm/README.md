![ci [CMS]](https://github.com/fastmachinelearning/SuperSONIC/actions/workflows/ci-github-cms.yaml/badge.svg)
![docs](https://github.com/fastmachinelearning/SuperSONIC/actions/workflows/sphinx-docs.yaml/badge.svg)
![helm lint](https://github.com/fastmachinelearning/SuperSONIC/actions/workflows/helm-lint.yaml/badge.svg)
![helm docs](https://github.com/fastmachinelearning/SuperSONIC/actions/workflows/helm-docs.yaml/badge.svg)

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/supersonic)](https://artifacthub.io/packages/search?repo=supersonic)

# SuperSONIC

The SuperSONIC project implements **common server infrastructure for GPU inference-as-a-service** to accelerate machine learining algorithms at large high energy physics (HEP) and multi-messenger astrophysics (MMA) experiments. The server infrastructure is designed for deployment at [Kubernetes](https://kubernetes.io) clusters equipped with GPUs.

The main components of SuperSONIC are:
- [Nvidia Triton](https://developer.nvidia.com/triton-inference-server) inference servers
- Dynamic muti-purpose [Envoy Proxy](envoyproxy.io):
  - Load balancing
  - Client connection rate limiting
  - GPU saturation prevention
  - Token-based authentication (optional)
- Load-based autoscaling via [KEDA](keda.sh)

## Documentation

- [Documentation](http://fastmachinelearning.org/SuperSONIC/ "Documentation")
  - [Installation](http://fastmachinelearning.org/SuperSONIC/getting-started.html "Installation")
  - [Helm chart parameters](http://fastmachinelearning.org/SuperSONIC/configuration-reference.html "Parameters")

## Server diagram

<p align="center">
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/master/docs/img/diagram.svg" alt="diagram" width="700"/>
</p>

## Status of deployment

|  | **[CMS](https://home.cern/science/experiments/cms)**      | **[ATLAS](https://home.cern/science/experiments/atlas)**    | **[IceCube](https://icecube.wisc.edu)**  |
|:---|:---:|:---:|:---:|
| **[Geddes cluster](https://www.rcac.purdue.edu/compute/geddes) (Purdue)**   | ✅ | - | - |
| **[Nautilus cluster](https://docs.nationalresearchplatform.org) (NRP)**    | ✅  |  ⏳ |   ✅   |
