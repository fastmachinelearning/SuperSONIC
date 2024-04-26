k delete configmap envoy-config -n cms
k delete deployment envoy-proxy -n cms 
k delete svc envoy-proxy -n cms

k create configmap envoy-config --from-file=envoy.yaml=envoy.yaml -n cms
k apply -f envoy-resources.yaml -n cms
