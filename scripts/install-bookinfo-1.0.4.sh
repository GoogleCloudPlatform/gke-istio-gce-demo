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

# shellcheck source=verify-functions.sh

ISTIO_DIR="${1}"
NAMESPACE="${2}"
SHARED_DIR="${3}"
ISTIO_AUTH_POLICY="${4}"

source "${SHARED_DIR}/verify-functions.sh"

# Install the istio bookinfo applicaton
kubectl apply -f <("${ISTIO_DIR}"/bin/istioctl kube-inject -f \
  "${ISTIO_DIR}"/samples/bookinfo/platform/kube/bookinfo.yaml)

# Label the default namespace with 
kubectl label namespace default istio-injection=enabled

kubectl apply -f "${ISTIO_DIR}"/samples/bookinfo/platform/kube/bookinfo.yaml

kubectl apply -f "${ISTIO_DIR}"/samples/bookinfo/networking/bookinfo-gateway.yaml

echo "Check that BookInfo services are installed"

for SERVICE_LABEL in "details" "productpage" "ratings" "reviews"; do
  # Poll 3 times on a 5 second interval
  if ! service_is_installed "${SERVICE_LABEL}" 3 5 "${NAMESPACE}" ; then
    echo "Service ${SERVICE_LABEL} in Istio deployment is not created. Aborting..."
    exit 1
  fi
done

# verify  bookinfo pods
for POD_LABEL in "app=details" "app=productpage" "app=ratings" "app=reviews"; do
  if ! pod_is_running "${POD_LABEL}" 10 15 "${NAMESPACE}" ; then
    echo "Pod ${POD_LABEL} in BookInfo is not running. Aborting..."
    exit 1
  fi
done
