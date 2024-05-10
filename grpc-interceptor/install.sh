k delete configmap envoy-config -n cms
k delete deployment triton-run2 -n cms 
k delete svc triton-run2 -n cms
k delete configmap lua-config -n cms

k create configmap envoy-config --from-file=envoy.yaml=envoy.yaml -n cms
k apply -f envoy-resources.yaml -n cms
k create configmap lua-config --from-file=envoy-filter.lua -n cms

