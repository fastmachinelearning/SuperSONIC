# SuperSONIC

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![AppVersion: 0.1](https://img.shields.io/badge/AppVersion-0.1-informational?style=flat-square)

A Helm chart for SuperSONIC

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| autoscaler.enabled | bool | `false` | Enable autoscaling |
| autoscaler.maxReplicas | int | `2` |  |
| autoscaler.minReplicas | int | `1` | Minimum and maximum number of Triton servers. Warning: if min=0 and desired Prometheus metric is empty, the first server will never start |
| autoscaler.scaleDown.period | int | `30` |  |
| autoscaler.scaleDown.stepsize | int | `1` |  |
| autoscaler.scaleDown.window | int | `120` |  |
| autoscaler.scaleUp.period | int | `30` |  |
| autoscaler.scaleUp.stepsize | int | `1` |  |
| autoscaler.scaleUp.window | int | `120` |  |
| envoy.args | list | `["--config-path","/etc/envoy/envoy.yaml","--log-level","info","--log-path","/dev/stdout"]` | Arguments for Envoy |
| envoy.auth.enabled | bool | `false` | Enable authentication in Envoy proxy |
| envoy.configs | object | `{"luaConfig":"cfg/envoy-filter.lua"}` | Configuration files for Envoy  |
| envoy.enabled | bool | `true` | Enable Envoy Proxy |
| envoy.image | string | `"envoyproxy/envoy:v1.30-latest"` | Envoy Proxy Docker image |
| envoy.loadBalancerPolicy | string | `"LEAST_REQUEST"` | Envoy load balancer policy. Options: ROUND_ROBIN, LEAST_REQUEST, RING_HASH, RANDOM, MAGLEV |
| envoy.name | string | `"sonic-server"` | Envoy Proxy Deployment name |
| envoy.replicas | int | `1` | Number of Envoy Proxy pods in Deployment |
| envoy.resources | object | `{"limits":{"cpu":1,"memory":"2G"},"requests":{"cpu":1,"memory":"2G"}}` | Resource requests and limits for Envoy Proxy. Note: an Envoy Proxy with too many connections might run out of CPU |
| envoy.service.labels | object | `{"envoy":"true"}` | I don't remember why this label is here. |
| envoy.service.ports | list | `[{"name":"grpc","port":8001,"targetPort":8001},{"name":"admin","port":9901,"targetPort":9901}]` | Envoy Service ports |
| envoy.service.type | string | `"LoadBalancer"` | Service type: ClusterIP or LoadBalancer. If ClusterIP is chosen, you need to enable an Ingress for the servers. |
| ingress.enabled | bool | `false` |  |
| ingress.hostName | string | `""` |  |
| nodeSelector | object | `{}` | Node selector for all pods (Triton and Envoy) |
| prometheus.enabled | bool | `false` | Enable Prometheus |
| prometheus.port | int | `443` |  |
| prometheus.scheme | string | `"https"` | Specify whether Prometheus endpoint is exposed as http or https |
| prometheus.serverAvailabilityMetric | string | `"sum(\n  sum by (pod) (\n    rate(nv_inference_queue_duration_us{pod=~\"sonic-server.*\"}[5m:1m])\n  )\n  /\n  sum by (pod) (\n    (rate(nv_inference_exec_count{pod=~\"sonic-server.*\"}[5m:1m])) * 1000\n  )\n)"` | A metric which Envoy Proxy can use to decide whether to accept new client connections; # the same metric can be used by KEDA autoscaler. # The example below is average queue time for inference requests arriving at the server, in milliseconds. |
| prometheus.serverAvailabilityThreshold | int | `100` | Threshold for the metric |
| prometheus.url | string | `""` | Prometheus server url and port number (find in documentation of a given cluster or ask admins) |
| tolerations | list | `[]` | Tolerations for all pods (Triton and Envoy) |
| triton.affinity | object | `{}` | Affinity rules for Triton pods - another way to request GPUs |
| triton.args[0] | string | `"/opt/tritonserver/bin/tritonserver \\\n--model-repository=/path-to-models/ \\\n--allow-gpu-metrics=true \\\n--log-verbose=0 \\\n--strict-model-config=false \\\n--exit-timeout-secs=60\n"` |  |
| triton.command | list | `["/bin/sh","-c"]` | Command and arguments to run in Triton container |
| triton.image | string | `"fastml/triton-torchgeo:22.07-py3-geometric"` | Docker image for the Triton server |
| triton.modelRepository | object | `{"cvmfsPvc":false,"mountPath":"/cvmfs","storageType":"cvmfs-pvc"}` | Model repository configuration |
| triton.modelRepository.cvmfsPvc | bool | `false` | Whether to create a PVC for CMVFS (CVMFS StorageClass must be present at the cluster) |
| triton.modelRepository.mountPath | string | `"/cvmfs"` | Model repository mount path |
| triton.name | string | `"sonic-server-triton"` | Name of the Nvidia Triton inference server Deployment |
| triton.replicas | int | `1` | Number of Triton server instances (if autoscaling is disabled) |
| triton.resources | object | `{"limits":{"cpu":1,"memory":"2G"},"requests":{"cpu":1,"memory":"2G"}}` | Resource limits and requests for each Triton instance. You can add necessary GPU request here. |
| triton.service.annotations | object | `{}` |  |
| triton.service.labels.scrape_metrics | string | `"true"` |  |
| triton.service.ports | list | `[{"name":"http","port":8000,"protocol":"TCP","targetPort":8000},{"name":"grpc","port":8001,"protocol":"TCP","targetPort":8001},{"name":"metrics","port":8002,"protocol":"TCP","targetPort":8002}]` | Ports for communication with Triton servers |

