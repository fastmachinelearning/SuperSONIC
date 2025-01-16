helm repo add supersonic https://fastmachinelearning.org/SuperSONIC
helm install supersonic supersonic/supersonic --values values/values-nautilus-cms.yaml -n sonic-server