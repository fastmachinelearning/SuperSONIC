helm repo add fastml https://fastmachinelearning.org/SuperSONIC
helm install supersonic fastml/supersonic --values values/values-geddes-cms.yaml -n cms