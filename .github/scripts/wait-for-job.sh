#!/bin/bash
# Wait for a Kubernetes Job to reach a terminal state, then print its pod logs
# and the namespace pod list (with RESTARTS) regardless of the outcome.
#
# Exit codes:
#   0  Job condition Complete=True
#   1  Job condition Failed=True (reported immediately with reason/message,
#      instead of idling until the timeout as `kubectl wait --for=condition=complete`
#      would), or no terminal state within <timeout-seconds>
#   2  kubectl error (RBAC, unreachable apiserver, job NotFound after the grace
#      window, missing jq) -- fails fast instead of polling until the timeout
#
# Env overrides:
#   WAIT_FOR_JOB_GRACE     seconds during which NotFound is tolerated after start,
#                          so a just-applied Job has time to land (default 30)
#   WAIT_FOR_JOB_INTERVAL  poll interval in seconds (default 5)
usage="usage: wait-for-job.sh <job> <namespace> <timeout-seconds>"
job="${1:?$usage}"
namespace="${2:?$usage}"
timeout="${3:?$usage}"
grace="${WAIT_FOR_JOB_GRACE:-30}"
interval="${WAIT_FOR_JOB_INTERVAL:-5}"

if ! command -v jq >/dev/null 2>&1; then
  echo "wait-for-job.sh: jq is required but not found on PATH" >&2
  exit 2
fi

dump_logs() {
  echo "========== Logs: job/$job =========="
  kubectl logs -n "$namespace" -l "job-name=$job" --all-containers --tail=-1 || true
  echo "========== Pods: namespace/$namespace =========="
  kubectl get pods -n "$namespace" || true
}

start=$SECONDS
deadline=$((start + timeout))
grace_deadline=$((start + grace))

while [ "$SECONDS" -lt "$deadline" ]; do
  # Single API call per iteration; stderr is captured so errors are visible.
  if ! out=$(kubectl get job "$job" -n "$namespace" -o json 2>&1); then
    if [[ "$out" == *NotFound* ]] && [ "$SECONDS" -lt "$grace_deadline" ]; then
      echo "Job $job not found yet (waiting up to ${grace}s for it to appear)..."
      sleep "$interval"
      continue
    fi
    echo "kubectl get job $job -n $namespace failed:" >&2
    echo "$out" >&2
    exit 2
  fi

  # Extract Complete status, Failed status, and Failed reason/message from the
  # one JSON document (four lines, in that order).
  mapfile -t fields < <(jq -r '
    (.status.conditions // []) as $c
    | ($c | map(select(.type == "Complete"))[0] | .status // ""),
      ($c | map(select(.type == "Failed"))[0] | (.status // ""), (.reason // ""), (.message // ""))
  ' <<< "$out")
  complete="${fields[0]}"
  failed="${fields[1]}"
  reason="${fields[2]}"
  message="${fields[3]}"

  if [ "$complete" = "True" ]; then
    echo "Job $job completed."
    dump_logs
    exit 0
  fi
  if [ "$failed" = "True" ]; then
    echo "Job $job failed: ${reason:-unknown}: ${message}"
    dump_logs
    exit 1
  fi
  sleep "$interval"
done

echo "Job $job did not reach a terminal state within ${timeout}s."
dump_logs
exit 1
