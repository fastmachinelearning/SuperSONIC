helm repo add fastml https://fastmachinelearning.org/SuperSONIC
helm install atlas-sonic fastml/supersonic --values values/values-nautilus-atlas.yaml -n atlas-sonic