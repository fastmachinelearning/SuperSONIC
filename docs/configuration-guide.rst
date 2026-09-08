Configuration Guide
####################

The following guide will help you configure ``values.yaml`` file for a SuperSONIC deployment.
The full list of parameters can be found in the `Configuration Reference <configuration-reference>`_.

You can find example values files in the `SuperSONIC GitHub repository <https://github.com/fastmachinelearning/SuperSONIC/tree/main/values>`_.

1. Select a Triton Inference Server Version
=============================================

- Official versions can be found at `NVIDIA NGC <https://ngc.nvidia.com/catalog/containers/nvidia:tritonserver>`_.
- You can also use custom-built Triton images.
- Refer to the `Nvidia Frameworks Support Matrix <https://docs.nvidia.com/deeplearning/frameworks/support-matrix/index.html>`_ 
  for compatibility information (CUDA versions, NVIDIA drivers, etc.).

Triton version must be specified in the ``triton.image`` parameter in the values file.


2. Configure Triton model repository
=============================================
   
- To learn about the structure of model repositories, refer to the
  `NVIDIA Model Repository Guide <https://docs.nvidia.com/deeplearning/triton-inference-server/user-guide/docs/user_guide/model_repository.html>`_.
- Model repositories are specified in the ``triton.args`` parameter in the values file.
  The parameter contains the full command that launches a Triton server; you can specify
  one or multiple model repositories via the ``--model-repository`` flag.
- For example, the following command loads multiple CMS models hosted at CVMFS:
     
.. code-block:: yaml

   args: 
     - |
      /opt/tritonserver/bin/tritonserver \
      --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoBTag/Combined/data/models/ \
      --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoTauTag/TrainingFiles/data/DeepTauIdSONIC/ \
      --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoMET/METPUSubtraction/data/models/ \
      --allow-gpu-metrics=true \
      --log-verbose=0 \
      --strict-model-config=false \
      --exit-timeout-secs=60 

- Make sure that the model repository paths exist. You can load models from a volume mounted to the Triton container.
  The following options for model repository mounting are provided via ``triton.modelRepository`` parameter in ``values.yaml``:

.. raw:: html

    <details>
    <summary>Model repository options</summary>

.. code-block:: yaml

   # -- Model repository configuration
   modelRepository:
     # Set to `true` to enable model repository mounting
     enabled: true

     # -- Model repository mount path (e.g /cvmfs/)
     mountPath: ""

     ## Model repository options:

     ## Option 1: mount an arbitrary PersistentVolumeClaim
     storageType: "pvc"
     pvc:
       claimName: 

     ## -- OR --
     ## Option 2: mount CVMFS as PersistentVolumeClaim (CVMFS StorageClass must be installed at the cluster)
     storageType: "cvmfs-pvc"
     
     ## -- OR --
     ## Option 3: mount CVMFS via hostPath (CVMFS must be already mounted on the nodes)
     storageType: "cvmfs-hostPath"

     ## -- OR --
     ## Option 4: mount an NFS storage volume
     storageType: "nfs"
     nfs:
       server:
       path:

.. raw:: html

   </details>

.. raw:: html

    <br><br>


1. Select Resources for Triton Pods
=============================================

- You can configure CPU, memory, and GPU resources for Triton pods via the ``triton.resources`` parameter in the values file:

.. code-block:: yaml

   resources:
     limits:
       nvidia.com/gpu: 1
       cpu: 2
       memory: 16G
     requests:
       nvidia.com/gpu: 1
       cpu: 2
       memory: 16G

- In addition, you can use ``triton.nodeSelector``, ``triton.tolerations``,
  ``triton.annotations``, and ``triton.affinity`` to steer Triton pods to specific nodes.
  This is particularly useful for co-locating Triton pods with Envoy proxy to reduce latency.


4. Configure Envoy Proxy
================================================

By default, Envoy proxy is enabled and configured to provide per-request
load balancing between Triton inference servers.

Once the SuperSONIC chart is installed, you need an address by which clients
can connect to the Envoy proxy and send inference requests.

There are two options:

-  **Ingress** (recommended): Use an Ingress to expose the Envoy proxy to the outside world.
   You can configure the Ingress resource via the ``envoy.ingress`` parameters in the values file:

   .. code-block:: yaml

      envoy:
        ingress:
          enabled: true
          hostName: "<ingress_url>"
          ingressClassName: "<ingress_class>"
          annotations: {}

   In this case, the client connections should be established to  ``<ingress_url>:443`` and use SSL.

   For information on how to configure Ingress for your cluster, please refer to cluster documentation or contact cluster administrators.

-  **LoadBalancer Service**: This option allows to expose the Envoy proxy without using Ingress, but it may
   not be allowed at some Kubernetes clusters. To enable this, set the following parameters in the values file:

   - ``envoy.service.type: LoadBalancer``
   - ``envoy.ingress.enabled: false``
  
   The LoadBalancer service can then be mapped to an external URL, depending on the settings of a given cluster.
   Please contact cluster administrators for more information.

   In this case, the client connections should be established to  ``<load_balancer_url>:8001`` and NOT use SSL.

Some Envoy Proxy parameters, such as load balancing policy, rate limiting, and authentication,
can be cofigured directly in the ``values.yaml`` file as described in sections below.

Alternatively, you can provide an external Envoy configuration file to override the
default configuration completely (the configuration file must be supplied as a ConfigMap):

.. code-block:: yaml

   envoy:
     external_config:
       load_from_configmap: true
       configmap_name: external-envoy-config
       configmap_key: envoy.yaml

.. warning::

   ``scaleFromZero.enabled`` cannot be used with ``envoy.external_config.load_from_configmap``.
   Scale-from-zero injects Envoy clusters and a Lua filter that an external ConfigMap would replace.

5. (Optional) Configure Rate Limiting in Envoy Proxy
======================================================
   
There are two types of rate limiting available in Envoy Proxy: *listener-level*, and *prometheus-based*.

- **Listener-level rate limiting** allows to explicitly limit the number of client connections established to the Envoy proxy endpoint.
  It can be useful to prevent overloading the proxy with too many simultaneous client connections.

  The listener-level rate limiting is implemented via "token bucket" algorithm.
  Each new connection consumes a token from the bucket, and the bucket is refilled at a constant rate.

  Example configuration in ``values.yaml``:

  .. code-block:: yaml

     envoy:
       enabled: true
       rate_limiter:
         listener_level:
           # -- Enable rate limiter
           enabled: false
           # -- Maximum number of simultaneous connections to the Envoy Proxy.
           max_tokens: 5
           # -- ``tokens_per_fill`` tokens are added to the "bucket" every ``fill_interval``, allowing new connections to be established.
           tokens_per_fill: 1
           # -- For example, adding a new token every 12 seconds allows 5 new connections every minute.
           fill_interval: 12s

- **Prometheus-based rate limiting** allows an additional layer of rate limiting based on a metric queried from a Prometheus server.
  This can be useful to dynamically control server load and stop accepting new connections when GPUs are saturated.

  This rate limiter can be enabled via the ``envoy.rate_limiter.prometheus_based`` parameter in the values file.

  At the moment, this functionality is configured to only reject ``RepositoryIndex`` requests to Triton servers, and it ignores
  any other requests in order not to slow down the inferences.

  The metric and threshold for the Prometheus-based rate limiter are the same as those used for the autoscaler (see Prometheus Configuration).

6. (Optional) Configure Authentication in Envoy Proxy
======================================================

At the moment, the only supported authentication method is JWT. Example configuration for IceCube:

.. code-block:: yaml

   envoy:
     auth:
       enabled: true
       jwt_issuer: https://keycloak.icecube.wisc.edu/auth/realms/IceCube
       jwt_remote_jwks_uri: https://keycloak.icecube.wisc.edu/auth/realms/IceCube/protocol/openid-connect/certs
       audiences: [icecube]
       url: keycloak.icecube.wisc.edu
       port: 443


7. Deploy a Prometheus Server or Connect to an Existing One
============================================================

Prometheus is needed to scrape metrics for monitoring, as well as for the rate limiter and autoscaler.

- **Option 1** (recommended): Deploy a new Prometheus server.

  This will allow to configure a shorter scraping interval, resulting in a more responsive
  rate limiter and autoscaler. Prometheus server typically uses only a small amount of resources
  and does not require special permissions for installation.

  This option installs Prometheus as a subchart, the default values for it are set to reasonable values.
  You can further customize the Prometheus installation by passing parameters from
  official Prometheus `values.yaml <https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus/values.yaml>`_ file
  under the ``prometheus`` section of the SuperSONIC values file:

  .. code-block:: yaml

     prometheus:
       enabled: true
       server:
         ingress:
           enabled: true
           ingressClassName: "<ingress_class>"
           hosts:
              - "<prometheus_url>"
           tls:
             - hosts:
                 - "<prometheus_url>"

  The parameters you will most likely need to configure in your values file are related to
  Ingress for web access to Prometheus UI.

  .. warning::

    This option requires permissions to list pods in the installation namespace.
    Permission validation is performed automatically: if you don't have the necessary permissions,
    an error message will be printed when running ``helm install`` command.

- **Option 2**: Connect to an existing Prometheus server.

  If you don't have enough permissions to install a new Prometheus server,
  you can connect to an existing one. If ``prometheus.external.enabled`` is set to ``true``,
  all  parameters in the ``prometheus`` section, except the ones under
  ``prometheus.external``, are ignored.

  .. code-block:: yaml

    prometheus:
      external:
        enabled: true
          scheme: "<https or http>"
          url: "<prometheus_url>"
          port: <prometheus_port>


8. (Optional) Configure Metrics for Scaling and Rate Limiting
===============================================================

The autoscaler and the Prometheus-based rate limiter are driven by one Prometheus
query, defined by the ``serverLoadMetric`` parameter at the root of the values file
(rendered in ``templates/_helpers/_scaling-metric.tpl``).

The default metric: occupancy ratio
------------------------------------

By default, SuperSONIC estimates **how many Triton replicas the current in-flight
work needs**:

.. math::

   R_{needed} = \frac{L_{envoy}}{\max(L_{service} / R_{healthy},\ 1)}

All three inputs are measured, with no model-specific constants:

- :math:`L_{envoy}` — mean number of requests in flight between Envoy and the
  Triton fleet (queued, executing, or on the wire). By Little's law
  (:math:`L = \lambda W`), this equals the per-second rate of Envoy's cumulative
  request-time counter:
  ``sum(rate(envoy_cluster_upstream_rq_time_sum{...}[1m])) / 1e3`` (the counter is
  in milliseconds).
- :math:`L_{service}` — mean number of requests being actively executed across all
  models and pods, from Triton's cumulative counters:
  ``sum(rate(nv_inference_request_duration_us - nv_inference_queue_duration_us)) / 1e6``.
  Request duration minus queue duration covers every phase a replica spends working
  on a request (input copy, inference, output copy, overhead), so models are
  weighted by the time they consume rather than by request counts.
- :math:`R_{healthy}` — Triton endpoints Envoy currently routes to:
  ``max(envoy_cluster_membership_healthy{...})`` (``max`` across Envoy pods, which
  all report the same upstream cluster).

In PromQL the division is spelled with ``clamp_min``, which is simply
:math:`\max(v, s)`:

.. code-block:: text

   L_envoy * clamp_min(R_healthy, 1) / clamp_min(clamp_min(L_service, R_healthy), 1)

The two floors encode physical facts rather than tuning:

- ``clamp_min(L_service, R_healthy)`` — each healthy replica can execute at least
  one request concurrently, so the fleet's serving capacity is never below its
  replica count. This is what makes scale-down work at low load: an underutilized
  fleet reads *below* 1 per replica instead of being stuck at the network floor.
- the outer ``clamp_min(..., 1)`` — at zero replicas (scale-from-zero) the metric
  degrades to "requests in flight" instead of dividing by zero, and never yields
  ``+Inf`` (which KEDA would treat as "scale to maximum").

Interpretation: divided by :math:`R_{healthy}`, the metric is the *sojourn-time
inflation* clients experience — 1.0 means every in-flight request is being
executed; 2.0 means requests spend as long waiting as being served. Because
in-flight work grows with offered load while serving capacity is bounded, the
metric is **linear in the overload factor**, which is exactly what the HPA's
proportional formula assumes; and it is invariant under the model mixture, since
every term is a time integral.

Thresholds and how they are consumed
-------------------------------------

- ``serverLoadThreshold`` (default ``2``) — KEDA consumes the metric with
  ``metricType: AverageValue``: desired replicas = ``ceil(metric / threshold)``.
  The threshold is the tolerated inflation: ``2`` targets "waiting ≈ serving";
  ``1.5`` buys lower latency at higher GPU cost. The unloaded floor is ~1.2–1.3
  (network transit), so values at or below ~1.3 over-provision.
- ``serverAdmissionThreshold`` (default ``3``) — the Envoy rate limiter compares
  the *per-replica* form of the metric against this value and rejects new
  ``RepositoryIndex`` requests above it. It is deliberately higher than
  ``serverLoadThreshold``: the autoscaler settles the system near its threshold,
  so gating admission at the same value would reject new clients during normal
  operation.
- ``serverLoadRateInterval`` (default ``1m``) — the ``rate()`` window. Keep it at
  or above 4× your Prometheus scrape interval; shorter windows add noise without
  detecting load faster (the control loop is dominated by HPA sync and pod
  startup), longer windows add lag.

Custom metrics
---------------

If ``serverLoadMetric`` is set, it is used **verbatim** by both KEDA and the rate
limiter. KEDA compares it against ``serverLoadThreshold`` and the rate limiter
against ``serverAdmissionThreshold`` — set them to the same value if you want the
two consumers coupled. Also set ``keda.metricType`` to match your metric's
semantics (``Value`` for per-replica quantities, ``AverageValue`` for fleet-wide
ones).

9. (Optional) Deploy Grafana Dashboard
==========================================

Grafana is used to visualize metrics collected by Prometheus.
We provide a pre-configured Grafana dashboard which includes many useful metrics,
including latency breakdown, GPU utilization, and more.

If you have a Grafana instance already installed, you can deploy SuperSONIC dashboars
by copying one of the JSON files from the
`SuperSONIC repository <https://github.com/fastmachinelearning/SuperSONIC/tree/main/helm/supersonic/dashboards>`_.

If you don't have a Grafana instance already installed, you can deploy one as a subchart of SuperSONIC,
in which case the dashboard will be automatically deployed.

You can further customize the Grafana installation by passing parameters from
official Grafana `values.yaml <https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml>`_ file
under the ``grafana`` section of the SuperSONIC values file:

.. code-block:: yaml

   grafana:
     enabled: true
     ingress:
       enabled: true
       ingressClassName: "<ingress_class>"
       hosts:
          - "<grafana_url>"
       tls:
         - hosts:
             - "<grafana_url>"

The values you will most likely need to configure in your values file are related to
Grafana Ingress for web access, and datasources to connect to Prometheus,

.. figure:: img/grafana.png
  :align: center
  :height: 200
  :alt: SuperSONIC Grafana Dashboard

10. Enable KEDA Autoscaler
==========================================

Autoscaling is implemented via `KEDA (Kubernetes Event-Driven Autoscaler) <https://keda.sh/>`_ and
can be enabled via the ``keda.enabled`` parameter in the values file.

.. warning::

   Deploying KEDA autoscaler requires KEDA CustomResourceDefinitions to be installed in the cluster.
   Please contact cluster administrators if this step of installation fails.

The parameters ``keda.minReplicaCount`` and ``keda.maxReplicaCount`` define the range in which
the number of Triton servers can scale. ``keda.pollingInterval`` is how often KEDA queries
Prometheus, and ``keda.cooldownPeriod`` is how long the load metric must stay below the
threshold before KEDA scales down to ``minReplicaCount``.

Additional optional parameters can control how quickly the autoscaler reacts to changes in the Prometheus metric:

.. code-block:: yaml

   keda:
     enabled: true

     minReplicaCount: 1
     maxReplicaCount: 10

     pollingInterval: 30
     cooldownPeriod: 120

     scaleUp:
       stabilizationWindowSeconds: 120
       periodSeconds: 30
       stepsize: 1
     scaleDown:
       stabilizationWindowSeconds: 120
       periodSeconds: 30
       stepsize: 1

To keep **zero** Triton replicas when idle, set ``keda.minReplicaCount`` to ``0`` and enable
``scaleFromZero``. Envoy stays running. On a ``RepositoryIndex`` request (the first RPC
used by CMS SONIC clients), SuperSONIC scales Triton to ``max(1, keda.minReplicaCount)``
replicas and returns the index only after Envoy has a healthy Triton upstream. KEDA then
scales up to ``maxReplicaCount`` using the Prometheus load metric. After
``scaleFromZero.holdMinReplicasSeconds`` with no further ``RepositoryIndex`` requests,
the ScaledObject minimum returns to ``keda.minReplicaCount``, and KEDA can scale back to zero.

.. code-block:: yaml

   envoy:
     enabled: true

   keda:
     enabled: true
     minReplicaCount: 0
     maxReplicaCount: 10

   scaleFromZero:
     enabled: true
     readyTimeoutSeconds: 300
     holdMinReplicasSeconds: 300

.. warning::

   The client deadline for ``RepositoryIndex`` must cover Triton startup. If no healthy
   upstream is available within ``scaleFromZero.readyTimeoutSeconds``, the index request
   is rejected.

``triton.replicas`` is unused when ``scaleFromZero`` is enabled; KEDA owns the replica
count. Helm upgrades keep the live ScaledObject ``minReplicaCount`` so they do not
interrupt an active hold. The hold deadline is stored as an annotation on the
ScaledObject, so the admission sidecars of multiple Envoy replicas share one hold
and none can release a peer's active hold. ``scaleFromZero`` requires ``keda.enabled`` and
``envoy.enabled``, and cannot be used with an external Envoy ConfigMap.

Do not set ``keda.zeroIdleReplicas: true`` together with ``minReplicaCount: 0``.
``zeroIdleReplicas`` sets KEDA ``idleReplicaCount`` to 0 and cannot scale from 0 back to 1
when the load metric is scraped from Triton. Use ``scaleFromZero`` for that.

An example is ``values/values-geddes-cms.yaml``.

11. (Optional) Configure Metrics Collector for Running ``perf_analyzer``
=========================================================================

To collect Prometheus metrics when using ``perf_analyzer`` for testing,
a Metrics Collector can be deployed to format Prometheus metrics properly.
The Metrics Collector is installed as a subchart with most of the default
values pre-configured. To enable the Metrics Collector, set the
``metricsCollector.enabled`` parameter to ``true`` in your values file
and configure ingress settings if needed as shown below:

.. code-block:: yaml

    metricsCollector:
      enabled: true
      ingress:
        enabled: true
        hostName: "<metrics_collector_url>"
        ingressClassName: "<ingress_class>"
        annotations: {}

Running with ``perf_analyzer`` is then done with:

.. code-block:: bash

    perf_analyzer -m <model_name> -u <envoy_engress> -i grpc \
        --collect-metrics --metrics-url <metrics_collector_url>/metrics \
        --verbose-csv -f <out_csv_file_name>.csv

If ingress is not desired, port-forward the metrics collector service and call
``--metrics-url localhost:8003/metrics`` to access the metrics. 
