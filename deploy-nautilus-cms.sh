helm repo add fastml https://fastmachinelearning.org/SuperSONIC
helm install supersonic fastml/supersonic --values values/values-nautilus-cms.yaml -n sonic-server