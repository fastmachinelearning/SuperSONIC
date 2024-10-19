
## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Parameters](#parameters)
    - [servers](#servers)
      - [triton](#triton)
      - [envoy](#envoy)
      - [prometheus](#prometheus)
      - [autoscaler](#autoscaler)
      - [ingress](#ingress)
    - [common](#common)
      - [tritonService](#tritonservice)
      - [envoyService](#envoyservice)
      - [affinity](#affinity)
- [Contributing](#contributing)


## Installation

```shell
helm upgrade --install sonic-load-balancers ./helm --values helm/values.yaml -n <namespace>
```

## Configuration reference

#### servers

- `servers`: List of server configurations: it is possible to deploy several configurations at the same time, for example when different server setups are needed for different workflows.

##### triton

- `servers.triton.name`: **(string)** Name of the Nvidia Triton inference server deployment.

- `servers.triton.replicas`: **(int)** Number of Triton replicas when autoscaling is disabled.
  - **Default**: `1`

- `servers.triton.image`: **(string)** Docker image for the Triton server.
  - **Example**: `nvcr.io/nvidia/tritonserver:22.07-py3`

- `servers.triton.command`: **(list)** Command to run in the Triton container.
  - **Example**: `["/bin/sh", "-c"]`

- `servers.triton.args`: **(list)** Arguments for the command.
  - **Example**:
    ```yaml
    - |
      /opt/tritonserver/bin/tritonserver \
      --model-repository=/models/repo1 \
      --model-repository=/models/repo2 \
      --allow-gpu-metrics=true \
      --log-verbose=1 \
      --strict-model-config=false \
      --exit-timeout-secs=60 \
      --backend-config=onnxruntime,enable-global-threadpool=1
    ```

- `servers.triton.resources`: **(object)** Resource requests and limits for the Triton server.
  - `limits`: Resource limits.
    - `nvidia.com/gpu`: **(int)** Number and type of GPUs to allocate.
    - `cpu`: **(string)** CPU limit.
    - `memory`: **(string)** Memory limit.
  - `requests`: Resource requests.
    - `nvidia.com/gpu`: **(int)** Number and type of GPUs to request.
    - `cpu`: **(string)** CPU request.
    - `memory`: **(string)** Memory request.

- `servers.triton.modelRepository`: **(object)** Configuration for the model repository.
  - `storageType`: **(string)** Type of storage for the model repository. Possible options are `nfs`, `pvc`, `cvmfs`, `cvmfs-pvc`, `s3`. 
  - `mountPath`: **(string)** Mount path for the model repository inside the container.
    - **Example**: `/models`

##### envoy

- `servers.envoy.name`: **(string)** Name of the Envoy deployment.

- `servers.envoy.replicas`: **(int)** Number of Envoy replicas.
  - **Default**: `1`

- `servers.envoy.image`: **(string)** Docker image for Envoy.
  - **Example**: `envoyproxy/envoy:v1.30-latest`

- `servers.envoy.args`: **(list)** Arguments for the Envoy container.
  - **Example**: `["--config-path", "/etc/envoy/envoy.yaml", "--log-level", "info", "--log-path", "/dev/stdout"]`

- `servers.envoy.resources`: **(object)** Resource requests and limits for Envoy.
  - `requests`:
    - `cpu`: **(string)** CPU request.
    - `memory`: **(string)** Memory request.
  - `limits`:
    - `cpu`: **(string)** CPU limit.
    - `memory`: **(string)** Memory limit.

- `servers.envoy.configs`: **(object)** Configuration files for Envoy.
  - `envoyConfig`: **(string)** Path to the Envoy configuration file.
    - **Example**: `cfg/envoy.yaml`
  - `luaConfig`: **(string)** Path to the Lua configuration file.
    - **Example**: `cfg/envoy-filter.lua`

- `servers.envoy.loadBalancerPolicy`: **(string)** Load balancing policy for Envoy.
  - **Example**: `LEAST_REQUEST`

##### prometheus

- `servers.prometheus.url`: **(string)** URL of the Prometheus server.

- `servers.prometheus.port`: **(int)** Port of the Prometheus server.

- `servers.prometheus.scheme`: **(string)** Scheme for Prometheus (`http` or `https`).

- `servers.prometheus.serverAvailabilityMetric`: **(string)** Prometheus query for server availability (saturation).

- `servers.prometheus.serverAvailabilityThreshold`: **(int)** Threshold for server availability metric.

##### autoscaler

- `servers.autoscaler.enabled`: **(bool)** Enable the autoscaler.

- `servers.autoscaler.minReplicas`: **(int)** Minimum number of replicas.
  - **Default**: `1`

- `servers.autoscaler.maxReplicas`: **(int)** Maximum number of replicas.
  - **Default**: `14`

##### ingress

- `servers.ingress.enabled`: **(bool)** Enable ingress for the service.
  - **Default**: `false`

- `servers.ingress.hostName`: **(string)** Hostname for ingress.

#### common

- `common.tritonService`: **(object)** Configuration for the Triton service.
  - `labels`: **(object)** Labels for the Triton service.
    - Example:
      ```yaml
      scrape_metrics: "true"
      ```
  - `annotations`: **(object)** Annotations for the Triton service.
    - Example:
      ```yaml
      metallb.universe.tf/address-pool: geddes-private-pool
      ```
  - `ports`: **(list)** List of ports exposed by the Triton service.
    - Each port entry includes:
      - `name`: **(string)** Name of the port.
      - `port`: **(int)** External port.
      - `targetPort`: **(int)** Container port.
      - `protocol`: **(string)** Protocol.

- `common.envoyService`: **(object)** Configuration for the Envoy service.
  - `type`: **(string)** Kubernetes service type.
  - `labels`: **(object)** Labels for the Envoy service.
    - Example:
      ```yaml
      envoy: "true"
      ```
  - `ports`: **(list)** List of ports exposed by the Envoy service.
    - Each port entry includes:
      - `name`: **(string)** Name of the port.
      - `port`: **(int)** External port.
      - `targetPort`: **(int)** Container port.

- `common.affinity`: **(object)** Affinity rules for pod scheduling.
  - **Default**: `{}` (no affinity rules)
