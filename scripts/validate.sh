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

set -e

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Include the user set variables
# shellcheck source=properties.env
source "${ROOT}/properties.env"

ISTIO_SHARED_DIR="${ROOT}/gke-istio-shared"

# Source utility functions for checking the existence of various resources.
# shellcheck source=gke-istio-shared/verify-functions.sh
source "${ISTIO_SHARED_DIR}/verify-functions.sh"

dependency_installed "kubectl"

# shellcheck source=gke-istio-shared/verify-db-ratings.sh
source "${ISTIO_SHARED_DIR}/verify-db-ratings.sh" "$((1 + RANDOM % 5))"
