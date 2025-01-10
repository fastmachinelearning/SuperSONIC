-------------------
Getting Started
-------------------

Pre-requisites
~~~~~~~~~~~~~~~

   1. `Kubernetes <https://kubernetes.io>`_ cluster
   2. `Prometheus <https://prometheus.io>`_ monitoring system 
   3. `KEDA (Kubernetes Event-Driven Autoscaling) <https://keda.sh>`_ (if using autoscaling)

Installation
~~~~~~~~~~~~~~

   1. Create a values file with your configuration.
      
      - `Example values.yaml files <https://github.com/fastmachinelearning/SuperSONIC/tree/master/values>`_
      - `Full list of configuration parameters <https://github.com/fastmachinelearning/SuperSONIC/blob/master/helm/values.yaml>`_
      - `Configuration reference <configuration-reference>`_

   2. Modify the following command to install the chart at your cluster:

      .. code:: shell

         git clone https://github.com/fastmachinelearning/SuperSONIC
         cd SuperSONIC
         helm upgrade --install <release-name> ./helm --values values/<your-values.yaml> -n <namespace>

      Use a unique meaningful lowercase value as <release-name>, for example
      ``supersonic-cms-run3``.
      This value will be used as a prefix for all resources created by the chart,
      unless ``nameOverride`` is specified in the values file.

   Nicer installation from a Helm repository coming soon in `v0.1`

Uninstall SuperSONIC
~~~~~~~~~~~~~~~~~~~~~~~~~~

   .. code:: shell

      helm uninstall <release-name> -n <namespace>

Architecture
~~~~~~~~~~~~~~~

The SuperSONIC Helm chart will install
components depicted at the diagram below, excluding Prometheus and model repository,
which must be connected by specifying relevant parameters in configuration file
(see :doc:`configuration reference <configuration-reference>`).

The KEDA autoscaler can be enabled/disabled via the
``autoscaler.enabled`` parameter.

.. figure:: img/diagram.svg
   :alt: SONIC Server Infrastructure