Installation
------------

**Pre-requisites:**

   1. `Kubernetes cluster <kubernetes.io>`_
   2. `Prometheus <prometheus.io>`_ monitoring system 
   3. if using autoscaling: `KEDA (Kubernetes Event-Driven Autoscaling) <keda.sh>`_

**Installation:**

   Modify the following command to install the chart at your cluster:

   .. code:: shell

      helm upgrade --install super-sonic ./helm --values helm/values.yaml -n 