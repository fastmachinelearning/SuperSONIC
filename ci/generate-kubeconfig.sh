#!/bin/bash

# Variables
CLUSTER_NAME="geddes"
SERVICE_ACCOUNT_NAME="super-sonic-ci-sa"
NAMESPACE="cms"
OUTPUT_FILE="kubeconfig-${CLUSTER_NAME}.yaml"

# Ensure the service account exists
if ! kubectl -n ${NAMESPACE} get sa ${SERVICE_ACCOUNT_NAME} &>/dev/null; then
  echo "Error: Service account '${SERVICE_ACCOUNT_NAME}' does not exist in namespace '${NAMESPACE}'"
  exit 1
fi

# Create a token request for the service account
TOKEN=$(kubectl -n ${NAMESPACE} create token ${SERVICE_ACCOUNT_NAME} --duration=24h)

if [ -z "${TOKEN}" ]; then
  echo "Error: Failed to retrieve token for service account '${SERVICE_ACCOUNT_NAME}'"
  exit 1
fi

# Get the current cluster CA certificate
CA_CERT=$(kubectl get secret $(kubectl get secret -n kube-system | grep default | awk '{print $1}' | head -n 1) -n kube-system -o jsonpath="{.data['ca\.crt']}" | base64 --decode)

# Get the current cluster API server URL
CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Create a kubeconfig file
cat <<EOF > ${OUTPUT_FILE}
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(echo ${CA_CERT} | base64 | tr -d '\n')
    server: ${CLUSTER_URL}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${SERVICE_ACCOUNT_NAME}
  name: ${CLUSTER_NAME}
current-context: ${CLUSTER_NAME}
users:
- name: ${SERVICE_ACCOUNT_NAME}
  user:
    token: ${TOKEN}
EOF

echo "Kubeconfig for service account '${SERVICE_ACCOUNT_NAME}' created at '${OUTPUT_FILE}'"