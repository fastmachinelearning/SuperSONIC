k delete configmap envoy-config -n cms
k delete deployment triton-run2 -n cms 
k delete svc triton-run2 -n cms


k create configmap envoy-config --from-file=envoy.yaml=envoy.yaml -n cms
k apply -f envoy-resources.yaml -n cms
