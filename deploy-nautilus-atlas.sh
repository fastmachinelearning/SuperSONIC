helm repo add supersonic https://fastmachinelearning.org/SuperSONIC
helm install atlas-sonic supersonic/supersonic --values values/values-nautilus-atlas.yaml -n atlas-sonic