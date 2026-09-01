#!/bin/bash

# Dump Kubernetes diagnostics for a namespace.
# Mirrors the command set of .github/actions/k8s-diagnostics/action.yml
# (composite actions cannot be reused from a shell script).
dump_diagnostics() {
  local namespace="$1"
  kubectl get pods -n "$namespace" -o wide || true
  kubectl get events -n "$namespace" --sort-by=.lastTimestamp || true
  kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.name}={.restartCount} last={.lastState.terminated.reason}/{.lastState.terminated.exitCode}{" "}{end}{"\n"}{end}' || true
  kubectl get deploy -n "$namespace" -o yaml || true
  kubectl get so -n "$namespace" -o yaml || true
  kubectl get hpa -n "$namespace" -o yaml || true
  for pod in $(kubectl get pods -n "$namespace" -o name 2>/dev/null); do
    echo "========== Logs: $pod =========="
    kubectl logs -n "$namespace" "$pod" --all-containers --tail=100 || true
    kubectl logs -n "$namespace" "$pod" --all-containers --tail=100 --previous 2>/dev/null || true
  done
}

echo "Starting deployment process..."

# 1. Create a Kubernetes cluster with Kind
echo "Creating Kind cluster..."
kind create cluster --name gh-k8s-cluster

# 2. (Assuming Helm is installed and at the proper version)

# 3. Create CMS namespace
echo "Creating CMS namespace..."
kubectl create namespace cms

# 4. Install Prometheus Operator CRDs
echo "Installing Prometheus Operator CRDs..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus-operator prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheusOperator.createCustomResource=false \
  --set defaultRules.create=false \
  --set alertmanager.enabled=false \
  --set prometheus.enabled=false \
  --set grafana.enabled=false

# 5. Install KEDA Autoscaler
echo "Installing KEDA Autoscaler..."
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
kubectl create namespace keda
helm install keda kedacore/keda --namespace keda

# 6. Mount CVMFS
echo "Mounting CVMFS..."
kubectl create namespace cvmfs-csi
helm install -n cvmfs-csi cvmfs-csi oci://registry.cern.ch/kubernetes/charts/cvmfs-csi \
  --values cvmfs/values-cvmfs-csi.yaml
kubectl apply -f cvmfs/cvmfs-storageclass.yaml -n cvmfs-csi

# 7. Deploy the Helm chart for supersonic
echo "Deploying Helm chart for supersonic..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm dependency build ./helm/supersonic
helm upgrade --install supersonic ./helm/supersonic --values values/values-minimal-full.yaml -n cms

# 8. Wait for components to become ready

echo "Waiting for CVMFS pods to be ready..."
kubectl wait --for=condition=Ready pod --all -n cvmfs-csi --timeout 120s

echo "Waiting for Envoy proxy pods to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=envoy --timeout 180s -n cms

echo "Waiting for Prometheus pods to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus --timeout 120s -n cms
kubectl get svc,pod -l app.kubernetes.io/name=prometheus -n cms

echo "Waiting for Grafana pods to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana --timeout 120s -n cms

echo "Waiting for KEDA Autoscaler to be ready..."
kubectl wait --for=condition=AbleToScale hpa -l app.kubernetes.io/component=keda --timeout 120s -n cms
kubectl wait --for=condition=Ready so -l app.kubernetes.io/component=keda --timeout 120s -n cms

echo "Waiting for Triton Deployment spec.replicas=0..."
for i in $(seq 1 36); do
  replicas=$(kubectl get deploy -l app.kubernetes.io/component=triton -n cms -o jsonpath='{.items[0].spec.replicas}')
  echo "Triton spec.replicas=${replicas:-unset}"
  if [ "${replicas}" = "0" ]; then
    break
  fi
  if [ "$i" -eq 36 ]; then
    echo "Triton did not scale to 0 replicas"
    dump_diagnostics cms
    exit 1
  fi
  sleep 5
done

# 9. Validate the Deployment
echo "Validating Deployment in 'cms' namespace..."
kubectl get all -n cms

# 10. Run Perf Analyzer Job
echo "Running Perf Analyzer Job..."
kubectl apply -f tests/perf-analyzer-job-ci.yaml
kubectl wait --for=condition=complete job/perf-analyzer-job -n cms --timeout=800s || {
  echo "Perf-analyzer job did not complete in time or failed."
  exit 1
}

# Retrieve and print the logs from the Perf Analyzer pod
POD_NAME=$(kubectl get pods -n cms -l job-name=perf-analyzer-job -o jsonpath="{.items[0].metadata.name}")
echo "========== Perf Analyzer Logs =========="
kubectl logs -n cms "$POD_NAME"
echo "========================================"

# 11. Cleanup the Kind cluster
echo "Cleaning up: Deleting Kind cluster..."
kind delete cluster --name gh-k8s-cluster

echo "Deployment process completed successfully!"