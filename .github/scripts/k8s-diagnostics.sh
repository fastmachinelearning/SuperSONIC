#!/bin/bash
# Dump Kubernetes diagnostics for a namespace: pod status, events, deployment
# status, container termination states, KEDA/HPA state and pod logs.
# Used by .github/actions/k8s-diagnostics on CI failures and by ci-local.sh.
# Every command tolerates failure so a partially-broken cluster still yields output.
namespace="${1:?usage: k8s-diagnostics.sh <namespace>}"

group() { echo "::group::$1"; }
endgroup() { echo "::endgroup::"; }

group "Pod status ($namespace)"
kubectl get pods -n "$namespace" -o wide || true
endgroup

group "Events ($namespace)"
kubectl get events -n "$namespace" --sort-by=.lastTimestamp || true
endgroup

group "Deployment status ($namespace)"
kubectl get deploy -n "$namespace" -o yaml || true
endgroup

group "Container restart and termination states ($namespace)"
kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.name}={.restartCount} last={.lastState.terminated.reason}/{.lastState.terminated.exitCode}{" "}{end}{"\n"}{end}' || true
endgroup

group "KEDA ScaledObjects and HPAs ($namespace)"
kubectl get so -n "$namespace" -o yaml || true
kubectl get hpa -n "$namespace" -o yaml || true
endgroup

for pod in $(kubectl get pods -n "$namespace" -o name 2>/dev/null); do
  group "Logs: $pod"
  kubectl logs -n "$namespace" "$pod" --all-containers --tail=100 || true
  kubectl logs -n "$namespace" "$pod" --all-containers --tail=100 --previous 2>/dev/null || true
  endgroup
done
