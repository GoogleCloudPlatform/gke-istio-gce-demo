#! /usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script creates a GKE cluster with Istio installed in it using scripts
# in the SHARED_DIR directory.

set -e

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Include the user set variables
# shellcheck source=properties.env
source "${ROOT}/properties.env"

ISTIO_SHARED_DIR="${ROOT}/gke-istio-shared"
ISTIO_DIR="${ROOT}/istio-${ISTIO_VERSION}"

# Source utility functions for checking the existence of various resources.
# shellcheck source=gke-istio-shared/verify-functions.sh
source "${ISTIO_SHARED_DIR}/verify-functions.sh"

# Ensure that the directory containing all of the necessary scripts exists
if ! directory_exists "${ISTIO_SHARED_DIR}" ; then
  echo "${ISTIO_SHARED_DIR} does not exist, please ensure"
  echo "the submodule was cloned correctly."
  echo "Exiting..."
  exit 1
fi

# Ensure that the selected project exists
if ! project_exists "${PROJECT}" ; then
  echo "The ${PROJECT} specified for use the with the demo does not exist."
  echo "Please update the properties file with a project that exists."
  echo "Terminating..."
  exit 1
fi

# Ensure the necessary dependencies are installed
if ! dependency_installed "gcloud"; then
  echo "I require gcloud but it's not installed. Aborting."
fi

if ! dependency_installed "kubectl"; then
  echo "I require kubectl but it's not installed. Aborting."
fi

if ! dependency_installed "curl" ; then
  echo "I require curl but it's not installed. Aborting."
fi

# Ensure the required APIs are enabled
enable_project_api "${PROJECT}" "compute.googleapis.com"
enable_project_api "${PROJECT}" "container.googleapis.com"

# Begin creating the GCP resources necessary to run Istio

# Download Istio components to be used in installation
# Globals:
#   None
# Arguments:
#   ISTIO_VERSION     - Version of Istio to use for deployment
#   ISTIO_SHARED_DIR  - Directory containing scripts shared by other demos
#   ISTIO_DIR         - Directory containing the verify-functions.sh file
# Returns:
#   None
"${ISTIO_SHARED_DIR}/download-istio.sh" "${ISTIO_VERSION}" "${ROOT}"

if ! directory_exists "$ISTIO_DIR" ; then
  echo "${ISTIO_DIR} does not exist, please ensure it downloaded correctly."
  echo ""
  echo "Aborting..."
  exit 1
fi

# Create the network to be used by the cluster.
# TODO: the assumption is currently that the network will be an auto-mode
# network. Does this assumption break anything? What happens if a user provides
# their own custom mode network?
if ! network_exists "${PROJECT}" "${NETWORK_NAME}"; then
  gcloud compute networks create "${NETWORK_NAME}" --project "${PROJECT}"
fi

# Create a cluster to install Istio on if it doesn't exist
# Globals:
#   None
# Arguments:
#   PROJECT            - Project to contain Istio cluster
#   CLUSTER_NAME       - Name to use for GKE cluster
#   ZONE               - Zone to locate created cluster
#   NETWORK_NAME - Name of network to use for cluster
# Returns:
#   None
if ! cluster_exists "${PROJECT}" "${CLUSTER_NAME}"; then
  "${ISTIO_SHARED_DIR}/create-istio-cluster.sh" "${PROJECT}" "${CLUSTER_NAME}" "${ZONE}" "${NETWORK_NAME}"
fi

# Set context to "default" to ensure following kubectl commands work
kubectl config set-context "$(kubectl config current-context)" --namespace=default

# Install Istio control plane into the cluster
# Globals:
#   None
# Arguments:
#   ISTIO_DIR         - Directory containing Istio components
#   ISTIO_YAML        - Name of the file used to deploy the Istio k8s resources
#   ISTIO_NAMESPACE   - Namespace containing Istio components
#   ISTIO_SHARED_DIR  - Directory containing scripts shared by other demos
# Returns:
#   None
"${ISTIO_SHARED_DIR}/install-istio.sh" "${ISTIO_DIR}" "${ISTIO_YAML}" "${ISTIO_NAMESPACE}" "${ISTIO_SHARED_DIR}"

# Install the BookInfo application into the cluster
# Globals:
#   None
# Arguments:
#   ISTIO_DIR         - Directory containing Istio components
#   NAMESPACE         - Namespace containing BookInfo services
#   ISTIO_SHARED_DIR  - Directory containing scripts shared by other demos
#   ISTIO_AUTH_POLICY - Whether MUTUAL_TLS authentication is turned on
# Returns:
#   None
"${ISTIO_SHARED_DIR}/install-bookinfo-1.0.x.sh" "${ISTIO_DIR}" "default" \
  "${ISTIO_SHARED_DIR}" "${ISTIO_AUTH_POLICY}"

# Validate that the BookInfo application has all of the components installed
# Globals:
#   None
# Arguments:
#   ISTIO_NAMESPACE   - Namespace containing Istio components
#   ISTIO_SHARED_DIR  - Directory containing scripts shared by other demos
# Returns:
#   None
"${ISTIO_SHARED_DIR}/verify-bookinfo-setup.sh" "${ISTIO_NAMESPACE}" \
  "${ISTIO_SHARED_DIR}"

# Install Istio service mesh expansion into cluster
# Globals:
#   None
# Arguments:
#   ISTIO_DIR       - Directory containing Istio components
#   ISTIO_NAMESPACE - Namespace containing Istio components
#   SHARED_DIR      - Directory containing scripts shared by other demos
# Returns:
#   None
"${ISTIO_SHARED_DIR}/install-istio-mesh-exp.sh" "${ISTIO_DIR}" "${ISTIO_NAMESPACE}" \
  "${ISTIO_SHARED_DIR}"

# Create GCE instance to install MySQL DB on and expand the Istio mesh
# Globals:
#   None
# Arguments:
#   GCE_VM     - Name of the GCE VM
#   PROJECT      - Project housing all of the infrastructure
#   NETWORK_NAME - Name of network to use for cluster
#   ZONE         - Zone to locate created cluster
# Returns:
#   None
"${ISTIO_SHARED_DIR}/create-istio-mesh-exp-gce.sh" "${GCE_VM}" "${PROJECT}" \
  "${NETWORK_NAME}" "${ZONE}"

# Create configuration files for Istio mesh expansion
# Globals:
#   PROJECT            - Project housing all of the infrastructure
#   ZONE               - Zone housing all of the infrastructure
#   CLUSTER_NAME       - GKE cluster to expand
#   ISTIO_AUTH_POLICY  - Whether MUTUAL_TLS authentication is turned on
#   EXP_SRVC_NAMESPACE - k8s/Istio namespace the GCE instance lives in
#   ISTIO_DIR          - Directory holding all of the Istio configuration files
# Arguments:
#   None
# Returns:
#   None
"${ISTIO_SHARED_DIR}/create-istio-mesh-exp-files-1.0.x.sh" "${PROJECT}" "${ZONE}" \
  "${CLUSTER_NAME}" "${ISTIO_AUTH_POLICY}" "${EXP_SRVC_NAMESPACE}" "${ISTIO_DIR}"

# Configure the expansion instance as a prerequisite to joining the mesh
# Globals:
#   None
# Arguments:
#   PROJECT    - Project housing all of the infrastructure
#   GCE_VM   - Name of the GCE VM
#   ISTIO_DIR  - Directory holding all of the Istio configuration files
#   SHARED_DIR - Directory containing scripts shared by other demos
#   ZONE       - Zone housing all of the infrastructure
# Returns:
#   None
"${ISTIO_SHARED_DIR}/setup-istio-mesh-exp-gce-1.0.x.sh" "${PROJECT}" "${GCE_VM}" \
  "${ISTIO_DIR}" "${ISTIO_SHARED_DIR}" "${ZONE}"

# Integrate GCE service into existing Istio infrastructure on GKE
# Globals:
#   None
# Arguments:
#   PROJECT    - Project housing all of the infrastructure
#   ZONE       - Zone housing all of the infrastructure
#   GCE_VM   - Name of the GCE VM
#   ISTIO_DIR  - Directory holding all of the Istio configuration files
# Returns:
#   None
"${ISTIO_SHARED_DIR}/integrate-service-into-istio-1.0.x.sh" "${PROJECT}" "${ZONE}" \
  "${GCE_VM}" "${ISTIO_DIR}" "${ISTIO_SHARED_DIR}"

EXT_IP=$(kubectl get svc -n istio-system | grep istio-ingressgateway | awk '{ print $4 }')
echo "$EXT_IP/productpage"
