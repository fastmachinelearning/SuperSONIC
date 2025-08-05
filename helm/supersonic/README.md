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

Currently, SuperSONIC supports the following functionality:
- GPU inference-as-a-service via [Nvidia Triton Inference Server](https://developer.nvidia.com/triton-inference-server)
- Load balancing across many GPUs via [Envoy Proxy](envoyproxy.io)
- Load-based autoscaling via [KEDA](keda.sh)
- Monitoring via [Prometheus](https://prometheus.io), [Grafana](https://grafana.com), and [OpenTelemetry](https://opentelemetry.io/docs/collector/)
- Rate limiting
- Token-based authentication


## Installation

### Pre-requisites

  <details>
  <summary><strong>Kubernetes cluster</strong></summary>
  
  ideally with access to GPUs, but CPUs are enough for a minimal deployment.
  </details>

  <details>
  <summary><strong>Helm</strong></summary>

  Helm is a package manager for Kubernetes. 
  To install Helm on your machine, follow the official instructions at [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/).
  </details>

  <details>
  <summary><strong>Custom Resource Definitions (CRDs)</strong></summary>

  These CRDs are not required for a minimal deployment.

  - [Prometheus](https://prometheus.io) CRDs

    If you are using an established Kubernetes cluster (e.g. at an HPC), there is a high chance that these CRDs are already installed. Otherwise, cluster admin can use the following commands:
    <details>
    <summary><strong>How to install Prometheus CRDs</strong></summary>

    ```
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    kubectl create namespace monitoring
    helm install prometheus-operator prometheus-community/kube-prometheus-stack --namespace monitoring --set prometheusOperator.createCustomResource=false --set defaultRules.create=false --set alertmanager.enabled=false --set prometheus.enabled=false --set grafana.enabled=false
    ```
    </details>
  - [KEDA](https://keda.sh) CRDs (only if using autoscaling)
    
    <details>
    <summary><strong>How to install Prometheus CRDs</strong></summary>

    ```
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    kubectl create namespace keda
    helm install keda kedacore/keda --namespace keda
    ```
    </details>
  </details>

---

### Standard deployment

If you are installing SuperSONIC for the first time, proceed to the [Minimal deployment](#minimal-deployment) section below.

If you already have a functional `values.yaml` and/or installed SuperSONIC previously, use the following installation commands:

```
helm repo add fastml https://fastmachinelearning.org/SuperSONIC
helm repo update
helm install <release-name> fastml/supersonic -n <namespace> -f <values.yaml>
```

To construct the `values.yaml` file for your application, follow [Configuration guide](http://fastmachinelearning.org/SuperSONIC/configuration-guide.html "Configuration guide").

The full list of configuration parameters is available in the [Configuration reference](http://fastmachinelearning.org/SuperSONIC/configuration-reference.html "Configuration reference").

---

### Minimal deployment

<details>
<summary><strong>1. Install cvmfs-csi plugin to load models from CVMFS</strong></summary>

For an example installation, we will use CMS models loaded from [CVMFS](https://cvmfs.readthedocs.io/en/stable/). SuperSONIC allows other types of model repository, including 
an arbitrary Persistent Volume, an NFS volume, or S3 storage.

[cvmfs-csi](https://github.com/cvmfs-contrib/cvmfs-csi) plugin allows to easily mount CVMFS
into a Kubernetes cluster by creating a new storage class. A Persistent Volume created with this
storage class will have CVMFS contents visible inside. 

Cluster admin can use the following commands to install `cvmfs-csi`:
```
kubectl create namespace cvmfs-csi
helm install -n cvmfs-csi cvmfs-csi oci://registry.cern.ch/kubernetes/charts/cvmfs-csi --values cvmfs/values-cvmfs-csi.yaml
kubectl apply -f cvmfs/cvmfs-storageclass.yaml -n cvmfs-csi
```
</details>

<details>
<summary><strong>2. Install SuperSONIC with minimal configuration</strong></summary>

The minimal deployment will install only a single CPU-based Triton server and an Envoy Proxy.
We will use [`values/values-minimal.yaml`](values/values-minimal.yaml) as our minimal
configuration file.

```
helm repo add fastml https://fastmachinelearning.org/SuperSONIC
helm repo update
helm install <release-name> fastml/supersonic -n <namespace> -f values/values-minimal.yaml
```
</details>

<details>
<summary><strong>3. Deploy a test job to run inferences</strong></summary>

To test your SuperSONIC installation, we will create a small [Nvidia Performance Analyzer](https://docs.nvidia.com/deeplearning/triton-inference-server/archives/triton-inference-server-2280/user-guide/docs/user_guide/perf_analyzer.html) job,
which will send a single inference request with random input data to Envoy Proxy endpoint.

1. In `tests/perf-analyzer-job.yaml`, edit the following parameters to match your deployment:

    ```
    metadata:
      namespace: <namespace>
    ```

    In `perf_analyzer` command: 

    ```
    -u <release-name>.<namespace>.svc.cluster.local:8001
    ```

2. Submit the job to your Kubernetes cluster:

    ```
    kubectl apply -n <namespace> -f tests/perf-analyzer-job.yaml
    ```

3. Track job performance and inspect logs:

    ```
    kubectl get pods -l job-name=perf-analyzer-job -n <namespace>
    kubectl logs <pod-name> -n <namespace>
    ```

</details>

---

### Installing from a GitHub branch/tag/commit

This option may be useful for testing unreleased features.
<details>
<summary><strong>Instructions</strong></summary>

```
git clone https://github.com/fastmachinelearning/SuperSONIC.git
cd SuperSONIC
git checkout <branch-or-commit>
helm dependency build helm/supersonic
helm install <release-name> helm/supersonic -n <namespace> -f <your-values.yaml>
```

</details>


## Server diagram

<p align="center">
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/diagram.svg#gh-light-mode-only" alt="diagram" width="700"/>
  <img src="https://github.com/fastmachinelearning/SuperSONIC/blob/main/docs/img/diagram-dark.svg#gh-dark-mode-only" alt="diagram-dark" width="700"/>
</p>


## Status of deployment

|  | **[CMS](https://home.cern/science/experiments/cms)**      | **[ATLAS](https://home.cern/science/experiments/atlas)**    | **[IceCube](https://icecube.wisc.edu)**  |
|:---|:---:|:---:|:---:|
| **[Purdue Geddes](https://www.rcac.purdue.edu/compute/geddes)**   | ✅ | - | - |
| **[Purdue Anvil](https://www.rcac.purdue.edu/compute/anvil)**   | ✅ | - | - |
| **[NRP Nautilus](https://docs.nationalresearchplatform.org)**    | ✅  |  ✅ |   ✅   |
| **[UChicago](https://af.uchicago.edu/)**    |  -  |  ✅ |   -   |
| **[UW–Madison](https://www.hep.wisc.edu/cms/comp/)**  | ⏳ | - | - |

## Publications

> Dmitry Kondratyev, Benedikt Riedel, Yuan-Tang Chou, Miles Cochran-Branson, Noah Paladino, David Schultz, Mia Liu, Javier Duarte, Philip Harris, and Shih-Chieh Hsu  
> **SuperSONIC: Cloud-Native Infrastructure for ML Inferencing**  
> *In Practice and Experience in Advanced Research Computing 2025: The Power of Collaboration (PEARC '25)*  
> Association for Computing Machinery, New York, NY, USA. Article 29, 1–5. 2025.  
> [https://doi.org/10.1145/3708035.3736049](https://doi.org/10.1145/3708035.3736049)
