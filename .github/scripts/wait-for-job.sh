#!/bin/bash
# Wait for a Kubernetes Job to reach a terminal state.
# Exits 0 on Complete, 1 on Failed (immediately, instead of waiting for the
# timeout as `kubectl wait --for=condition=complete` would), 1 on timeout.
job="${1:?usage: wait-for-job.sh <job> <namespace> <timeout-seconds>}"
namespace="${2:?usage: wait-for-job.sh <job> <namespace> <timeout-seconds>}"
timeout="${3:?usage: wait-for-job.sh <job> <namespace> <timeout-seconds>}"

deadline=$((SECONDS + timeout))
while [ "$SECONDS" -lt "$deadline" ]; do
  complete=$(kubectl get job "$job" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null)
  failed=$(kubectl get job "$job" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null)
  if [ "$complete" = "True" ]; then
    echo "Job $job completed."
    exit 0
  fi
  if [ "$failed" = "True" ]; then
    reason=$(kubectl get job "$job" -n "$namespace" -o jsonpath='{.status.conditions[?(@.type=="Failed")].reason}: {.status.conditions[?(@.type=="Failed")].message}' 2>/dev/null)
    echo "Job $job failed: $reason"
    exit 1
  fi
  sleep 5
done
echo "Job $job did not reach a terminal state within ${timeout}s."
exit 1
