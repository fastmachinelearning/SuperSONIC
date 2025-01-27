-------------------
Getting Started
-------------------

Pre-requisites
~~~~~~~~~~~~~~~

   1. `Kubernetes <https://kubernetes.io>`_ cluster
   2. `Prometheus <https://prometheus.io>`_ monitoring system (if using autoscaling or rate limiting)
   3. `KEDA (Kubernetes Event-Driven Autoscaling) <https://keda.sh>`_ (if using autoscaling)

Installation
~~~~~~~~~~~~~~

   1. Create a values file with your configuration.

      - `Configuration guide <configuration-guide>`_
      - `Configuration reference <configuration-reference>`_
      - `Example values.yaml files <https://github.com/fastmachinelearning/SuperSONIC/tree/master/values>`_

   2. Modify the following command to install the chart at your cluster:

      .. code:: shell

         helm repo add fastml https://fastmachinelearning.org/SuperSONIC
         helm repo update
         helm install <release-name> fastml/supersonic --values <your-values.yaml> -n <namespace>

      Use a unique meaningful lowercase value as <release-name>, for example
      ``supersonic-cms-run3``.
      This value will be used as a prefix for all resources created by the chart,
      unless ``nameOverride`` is specified in the values file.

Uninstall SuperSONIC
~~~~~~~~~~~~~~~~~~~~~~~~~~

   .. code:: shell

      helm uninstall <release-name> -n <namespace>

Architecture
~~~~~~~~~~~~~~~

The SuperSONIC Helm chart will install
components depicted at the diagram below, excluding Prometheus server and model repository,
which must be connected by specifying relevant parameters in configuration file
(see :doc:`configuration guide <configuration-guide>`).

The KEDA autoscaler can be enabled/disabled via the
``autoscaler.enabled`` parameter.

.. figure:: img/diagram.svg
   :alt: SONIC Server Infrastructure