#!/bin/bash

# Script to remove the container named 'sidecar' from all Deployments and StatefulSets in a given namespace.
# This is to solve a one-off issue where an extra sidecar can linger in a Deployment or StatefulSet after
# a recent greymatter-core update renamed "sidecar" to "sidecar18". 
# See GMP-962 for further details.

set -euo pipefail

# Check if the user has provided a namespace argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <namespace>"
  exit 1
fi

NAMESPACE="$1"

# Function to remove the sidecar container from the given resource
remove_sidecar() {
  local resource=$1
  local name=$2

  # Get the current JSON definition of the resource
  resource_json=$(kubectl -n "${NAMESPACE}" get "${resource}" "${name}" -o json)

  # Remove the sidecar container from the JSON definition
  updated_resource_json=$(echo "${resource_json}" | jq 'del(.spec.template.spec.containers[] | select(.name == "sidecar"))')

  # Update the resource with the modified JSON definition
  echo "${updated_resource_json}" | kubectl -n "${NAMESPACE}" replace -f -
}

# Iterate through all Deployments in the namespace
for deployment in $(kubectl -n "${NAMESPACE}" get deployments -o jsonpath='{.items[*].metadata.name}'); do
  remove_sidecar "deployment" "${deployment}"
done

# Iterate through all StatefulSets in the namespace
for statefulset in $(kubectl -n "${NAMESPACE}" get statefulsets -o jsonpath='{.items[*].metadata.name}'); do
  remove_sidecar "statefulset" "${statefulset}"
done

echo "Removed 'sidecar' container from all Deployments and StatefulSets in namespace '${NAMESPACE}'"
