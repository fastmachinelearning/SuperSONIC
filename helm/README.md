# SuperSONIC

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![AppVersion: 0.1](https://img.shields.io/badge/AppVersion-0.1-informational?style=flat-square)

A Helm chart for SuperSONIC

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| common.cvmfsPvc | bool | `false` | Whether to create a PVC for CMVFS (CVMFS StorageClass must be present at the cluster) |
| common.envoyService.labels | object | `{"envoy":"true"}` | I don't remember why this label is here. |
| common.envoyService.ports | list | `[{"name":"grpc","port":8001,"targetPort":8001},{"name":"admin","port":9901,"targetPort":9901}]` | Envoy Service ports |
| common.envoyService.type | string | `"LoadBalancer"` | Service type: ClusterIP or LoadBalancer. If ClusterIP is chosen, you need to enable an Ingress for the servers. |
| common.nodeSelector | object | `{}` | Node selector for all pods (Triton and Envoy) |
| common.tolerations | list | `[]` | Tolerations for all pods (Triton and Envoy) |
| common.tritonService.annotations | object | `{}` |  |
| common.tritonService.labels | object | `{"scrape_metrics":"true"}` | Labels and annotations for the Service. This can be useful to enable Prometheus to scrape metrics from Triton servers. |
| common.tritonService.ports | list | `[{"name":"http","port":8000,"protocol":"TCP","targetPort":8000},{"name":"grpc","port":8001,"protocol":"TCP","targetPort":8001},{"name":"metrics","port":8002,"protocol":"TCP","targetPort":8002}]` | Ports for communication with Triton servers |
| servers[0].autoscaler.enabled | bool | `false` | Enable autoscaling |
| servers[0].autoscaler.maxReplicas | int | `2` |  |
| servers[0].autoscaler.minReplicas | int | `1` | Minimum and maximum number of Triton servers. Warning: if min=0 and desired Prometheus metric is empty, the first server will never start |
| servers[0].envoy.args | list | `["--config-path","/etc/envoy/envoy.yaml","--log-level","info","--log-path","/dev/stdout"]` | Arguments for Envoy |
| servers[0].envoy.auth.enabled | bool | `false` | Enable authentication in Envoy proxy |
| servers[0].envoy.configs | object | `{"luaConfig":"cfg/envoy-filter.lua"}` | Configuration files for Envoy  |
| servers[0].envoy.enabled | bool | `true` | Enable Envoy Proxy |
| servers[0].envoy.image | string | `"envoyproxy/envoy:v1.30-latest"` | Envoy Proxy Docker image |
| servers[0].envoy.loadBalancerPolicy | string | `"LEAST_REQUEST"` | Envoy load balancer policy. Options: ROUND_ROBIN, LEAST_REQUEST, RING_HASH, RANDOM, MAGLEV |
| servers[0].envoy.name | string | `"sonic-server"` | Envoy Proxy Deployment name |
| servers[0].envoy.replicas | int | `1` | Number of Envoy Proxy pods in Deployment |
| servers[0].envoy.resources | object | `{"limits":{"cpu":2,"memory":"4G"},"requests":{"cpu":2,"memory":"4G"}}` | Resource requests and limits for Envoy Proxy. Note: an Envoy Proxy with too many connections might run out of CPU |
| servers[0].ingress.enabled | bool | `false` |  |
| servers[0].ingress.hostName | string | `""` |  |
| servers[0].prometheus.enabled | bool | `false` | Enable Prometheus |
| servers[0].prometheus.port | int | `443` |  |
| servers[0].prometheus.scheme | string | `"https"` | Specify whether Prometheus endpoint is exposed as http or https |
| servers[0].prometheus.serverAvailabilityMetric | string | `"sum(\n  sum by (pod) (\n    rate(nv_inference_queue_duration_us{pod=~\"sonic-server.*\"}[5m:1m])\n  )\n  /\n  sum by (pod) (\n    (rate(nv_inference_exec_count{pod=~\"sonic-server.*\"}[5m:1m])) * 1000\n  )\n)"` | A metric which Envoy Proxy can use to decide whether to accept new client connections; # the same metric can be used by KEDA autoscaler. # The example below is average queue time for inference requests arriving at the server, in milliseconds. |
| servers[0].prometheus.serverAvailabilityThreshold | int | `100` | Threshold for the metric |
| servers[0].prometheus.url | string | `""` | Prometheus server url and port number (find in documentation of a given cluster or ask admins) |
| servers[0].triton.affinity | object | `{}` | Affinity rules for Triton pods - another way to request GPUs |
| servers[0].triton.args[0] | string | `"/opt/tritonserver/bin/tritonserver \\\n--model-repository=/path-to-models/ \\\n--allow-gpu-metrics=true \\\n--log-verbose=0 \\\n--strict-model-config=false \\\n--exit-timeout-secs=60\n"` |  |
| servers[0].triton.command | list | `["/bin/sh","-c"]` | Command and arguments to run in Triton container |
| servers[0].triton.image | string | `"fastml/triton-torchgeo:22.07-py3-geometric"` | Docker image for the Triton server |
| servers[0].triton.modelRepository | object | `{"mountPath":"/cvmfs","storageType":"cvmfs-pvc"}` | Model repository configuration |
| servers[0].triton.modelRepository.mountPath | string | `"/cvmfs"` | Model repository mount path |
| servers[0].triton.name | string | `"sonic-server-triton"` | Name of the Nvidia Triton inference server Deployment |
| servers[0].triton.replicas | int | `1` | Number of Triton server instances (if autoscaling is disabled) |
| servers[0].triton.resources | object | `{"limits":{"cpu":2,"memory":"16G"},"requests":{"cpu":2,"memory":"16G"}}` | Resource limits and requests for each Triton instance. You can add necessary GPU request here. |

