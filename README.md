![ci [CMS]](https://github.com/fastmachinelearning/SuperSONIC/actions/workflows/ci-github-cms.yaml/badge.svg)
![docs](https://github.com/fastmachinelearning/SuperSONIC/actions/workflows/sphinx-docs.yaml/badge.svg)

# SuperSONIC

The SuperSONIC project implements **common server infrastructure for GPU inference-as-a-service** to accelerate machine learining algorithms at large high energy physics (HEP) and multimissenger astrophysics (MMA) experiments. The server infrastructure is designed for deployment at [Kubernetes](https://kubernetes.io) clusters equipped with GPUs.

The main components of SuperSONIC are:
- Nvidia Triton inference servers
- Dynamic muti-purpose Envoy Proxy:
  - Load balancing
  - GPU saturation prevention
  - Token-based authentication (optional)
- Load-based autoscaling

## Documentation

- [Documentation](http://fastmachinelearning.org/SuperSONIC/ "Documentation")
  - [Installation](http://fastmachinelearning.org/SuperSONIC/Installation.html "Installation")
  - [Helm chart parameters](http://fastmachinelearning.org/SuperSONIC/Parameters.html# "Parameters")

## Server diagram

<p align="center">
  <img src="docs/img/diagram.svg" alt="diagram" width="700"/>
</p>

## Status of deployment

|  | **[CMS](https://home.cern/science/experiments/cms)**      | **[ATLAS](https://home.cern/science/experiments/atlas)**    | **[IceCube](https://icecube.wisc.edu)**  |
|:---|:---:|:---:|:---:|
| **[Geddes cluster](https://www.rcac.purdue.edu/compute/geddes) (Purdue)**   | ✅ | - | - |
| **[Nautilus cluster](https://docs.nationalresearchplatform.org) (NRP)**    | ✅  |  ⏳ |   ✅   |