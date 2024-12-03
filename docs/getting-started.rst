-------------------
Getting Started
-------------------

**Pre-requisites:**

   1. `Kubernetes cluster <kubernetes.io>`_
   2. `Prometheus <prometheus.io>`_ monitoring system 
   3. if using autoscaling: `KEDA (Kubernetes Event-Driven Autoscaling) <keda.sh>`_

**Installation:**

   Modify the following command to install the chart at your cluster:

   .. code:: shell

      helm upgrade --install super-sonic ./helm --values helm/values.yaml -n 

**Architecture**

The SuperSONIC Helm chart will install
components depicted at the diagram below, excluding Prometheus and model repository,
which must be connected by specifying relevant parameters in configuration file
(see :doc:`configuration reference <configuration-reference>`).

In its current form, the chart allows to deploy multiple server
instances with different settings at once. This can be useful if you
need to host servers with different GPU models, different Triton server
versions, or different model repository mounts.

For correct behavior, the server saturation metric
(``servers[].prometheus.serverAvailabilityMetric``) used by Envoy proxy
and autoscaler must be carefully defined. It is recommended to start
with examining the metric in Prometheus interface, in order to define an
appropriate threshold and avoid typos in the metric definition.

The KEDA autoscaler can be enabled / disabled via the
``servers[].autoscaler.enabled`` parameter.

.. figure:: img/diagram.svg
   :alt: SONIC Server Infrastructure