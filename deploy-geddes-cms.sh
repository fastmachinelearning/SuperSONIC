helm repo add supersonic https://fastmachinelearning.org/SuperSONIC
helm install supersonic supersonic/supersonic --values values/values-geddes-cms.yaml -n cms