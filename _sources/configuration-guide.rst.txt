Configuration Guide
####################

The following guide will help you configure ``values.yaml`` file for a SuperSONIC deployment.
The full list of parameters can be found in the `Configuration Reference <configuration-reference>`_.

Triton Inference Server Configuration
****************************************

1. Select a Triton Inference Server version
=============================================

- Official versions can be found at `NVIDIA NGC <https://ngc.nvidia.com/catalog/containers/nvidia:tritonserver>`_.
- You can also use custom-built Triton images.
- Refer to the `Nvidia Frameworks Support Matrix <https://docs.nvidia.com/deeplearning/frameworks/support-matrix/index.html>`_ 
  for compatibility information (CUDA versions, NVIDIA drivers, etc.).

Triton version must be specified in the ``triton.image`` parameter in the values file.

2. Configure Triton model repository.
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
        --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoEgamma/EgammaPhotonProducers/data/models/ \
        --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoTauTag/TrainingFiles/data/DeepTauIdSONIC/ \
        --model-repository=/cvmfs/cms.cern.ch/el9_amd64_gcc12/cms/cmssw/CMSSW_14_1_0_pre7/external/el9_amd64_gcc12/data/RecoMET/METPUSubtraction/data/models/ \
        --allow-gpu-metrics=true \
        --log-verbose=0 \
        --strict-model-config=false \
        --exit-timeout-secs=60 

- Make sure that the model repository paths exist. You can load models from a volume mounted to the Triton container.
  The following options for model repository mouning are provided via ``triton.modelRepository`` parameter in ``values.yaml``:

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
     storageType: "cvmfs"

     ## -- OR --
     ## Option 4: mount an NFS storage volume
     storageType: "nfs"
     nfs:
     server:
     path:

   </details>

|

3. Select resources for Triton pods.
=============================================

- You can configure CPU, memory, and GPU resources for Triton pods via the ``triton.resources`` parameter in the values file.

  .. code-block:: yaml

     # Example:
     resources:
       limits: { nvidia.com/gpu: 1, cpu: 2, memory: 16G}
       requests: { nvidia.com/gpu: 1, cpu: 2, memory: 16G}

- Alternatively, you can use ``triton.affinity`` to steer Triton pods to nodes with specific GPU models.

  .. code-block:: yaml

     # Example:
     affinity:
       nodeAffinity:
         requiredDuringSchedulingIgnoredDuringExecution:
           nodeSelectorTerms:
             - matchExpressions:
               - key: nvidia.com/gpu.product
                 operator: In
                 values:
                   - NVIDIA-A10
                   - NVIDIA-A40
                   - NVIDIA-L40
                   - NVIDIA-L4

Envoy Proxy Configuration
****************************************

By default, Envoy proxy is enabled and configured to provide per-request load balancing between Triton inference servers.

1. Configure external endpoint for Envoy Proxy.
================================================

Once the SuperSONIC server is installed, you need an URL to which clients can connect and send inference requests.

There are two options:

-  **Ingress**: Use an Ingress to expose the Envoy proxy to the outside world.
   You can configure the Ingress resource via the ``ingress`` parameters in the values file:

   .. code-block:: yaml

      ingress:
        enabled: false
        hostName: "<ingress_url>"

   In this case, the client connections should be established to  ``<ingress_url>:443`` and use SSL.

-  **LoadBalancer Service**: This option allows to expose the Envoy proxy without using Ingress, but it may
   not be allowed at some Kubernetes clusters. To enable this, set the following parameters in the values file:

   - ``envoy.service.type: LoadBalancer``
   - ``ingress.enabled: false``
  
   The LoadBalancer service can then be mapped to an external URL, depending on the settings of a given cluster.
   Please contact cluster administrators for more information.

   In this case, the client connections should be established to  ``<load_balancer_url>:8001`` and NOT use SSL.


5. (optional) Configure rate limiting in Envoy Proxy.
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

  The metric and thershold for the Prometheus-based rate limiter are the same as those used for the autoscaler (see below).

Prometheus Configuration
****************************************

6. (optional) Connect to Prometheus server.
======================================================

If you are using either the Prometheus-based rate limiter or the KEDA autoscaler,
you need to connect SuperSONIC to an existing Prometheus server. This is done via
the ``prometheus.url`` and ``prometheus.port`` parameters in the values file,
and you can choose between ``http`` and ``https`` schemes using ``prometheus.scheme`` parameter.

Both the rate limiter and the autoscaler are currently configured to use the same Prometheus metric and threshold.
They are defined in the ``prometheus.serverLoadMetric`` and ``prometheus.serverLoadThreshold`` parameters in the values file.
The default metric is the inference queue time at the Triton servers, as defined
`here <https://github.com/fastmachinelearning/SuperSONIC/blob/1793fdad3bf74bf9cdf33737b64c5f8486a6357f/helm/supersonic/templates/_helpers.tpl#L22>`_.

When the metric value exceeds the threshold, the following happens:
- Autoscaler scales up the number of Triton servers if possible.
- Envoy proxy rejects new ``RepositoryIndex`` requests.

Autoscaler Configuration
****************************************

7. (optional) Enable KEDA autoscaler.
==========================================

Autoscaling is implemented via `KEDA (Kubernetes Event-Driven Autoscaler) <https://keda.sh/>`_ and
can be enabled via the ``autoscaler.enabled`` parameter in the values file.

The parameters ``autoscaler.minReplicas`` and ``autoscaler.maxReplicas`` define the range in which
the number of Triton servers can scale.

Additional optional parameters can control how quickly the autoscaler reacts to changes in the Prometheus metric:

.. code-block:: yaml

   autoscaler:
     enabled: true

     minReplicas: 1
     maxReplicas: 10

     scaleUp:
       window: 120
       period: 30
       stepsize: 1
     scaleDown:
       window: 120
       period: 30
       stepsize: 1
