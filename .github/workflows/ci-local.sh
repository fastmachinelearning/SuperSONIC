#!/bin/bash

set -e
CLUSTER_NAME=gh-k8s-cluster

# On any failure, dump cluster diagnostics (same script the CI failure step uses).
# Only do so when kubectl is actually pointed at our kind cluster: before kind has
# created/switched the context (e.g. `kind create cluster` failing), diagnostics
# would run against whatever context happens to be current.
on_error() {
  if [ "$(kubectl config current-context 2>/dev/null)" = "kind-${CLUSTER_NAME}" ]; then
    bash .github/scripts/k8s-diagnostics.sh cms
  else
    echo "Skipping diagnostics: current kube-context is not kind-${CLUSTER_NAME} (cluster not created or context not switched)."
  fi
}

# Always delete the kind cluster on exit (success or failure) so a failed run
# does not leave a cluster behind that makes the next `kind create cluster` fail.
# Bash runs the ERR trap at the failing command first, then (under set -e) exits,
# and the EXIT trap runs last -- so diagnostics are collected before the cluster
# is torn down.
cleanup() {
  echo "Cleaning up: Deleting Kind cluster ${CLUSTER_NAME}..."
  kind delete cluster --name "${CLUSTER_NAME}" 2>/dev/null || true
}

trap on_error ERR
trap cleanup EXIT

echo "Starting deployment process..."

# 1. Create a Kubernetes cluster with Kind
# If a previous run was interrupted before its EXIT trap could run (e.g. SIGKILL),
# a stale cluster with the same name would make `kind create cluster` fail, so
# delete it first to keep re-runs idempotent.
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "Kind cluster ${CLUSTER_NAME} already exists; deleting it before re-creating..."
  kind delete cluster --name "${CLUSTER_NAME}"
fi
echo "Creating Kind cluster..."
kind create cluster --name "${CLUSTER_NAME}"

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
  --version 89.2.4 \
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
    bash .github/scripts/k8s-diagnostics.sh cms
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
bash .github/scripts/wait-for-job.sh perf-analyzer-job cms 660

# 11. Cleanup of the Kind cluster happens in the EXIT trap (see top of script).
echo "Deployment process completed successfully!"
