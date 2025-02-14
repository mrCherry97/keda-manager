#!/usr/bin/env bash

SKIP_ASSETS=$3

# standard bash error handling
set -o nounset  # treat unset variables as an error and exit immediately.
set -o errexit  # exit immediately when a command fails.
set -E          # must be set if you want the ERR trap
set -o pipefail # prevents errors in a pipeline from being masked

# This script has the following arguments:
#                       - Keda Manager binary image tag - mandatory
#                       - Keda Operator OCI module image tag - mandatory
#                       --skip-template - optional
#
# ./await_artifacts.sh 1.1.0 v1.1.0

# Expected variables:
#             KEDA_MANAGER_REPO - keda-operator binary image repository
#             KEDA_OPERATOR_REPO - keda-operator OCI module image repository
#             GITHUB_TOKEN - github token

export IMAGE_TAG=$1
export MODULE_TAG=$2

PROTOCOL=docker://

RELEASES_URL="https://api.github.com/repos/kyma-project/keda-manager/releases"
ARTIFACTS_REGEX="(rendered.yaml|keda-manager.yaml)"

if [ "${SKIP_ASSETS}" != "--skip-templates" ]
then
  echo "Finding assets for: ${IMAGE_TAG}"
  # all 3  artifacts available?
  until [ $(curl -sL -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" ${RELEASES_URL} | jq '.[] | select(.tag_name == env.IMAGE_TAG) | .assets[] | .browser_download_url | split("/") | last ' | sort -u | grep -Ec ${ARTIFACTS_REGEX}) -eq 3 ]; do
    echo 'waiting for the assets'
    sleep 10
  done
  echo "assets available"
fi

until $(skopeo list-tags ${PROTOCOL}${KEDA_OPERATOR_REPO} | jq '.Tags|any(. == env.MODULE_TAG)'); do
  echo "Waiting for Keda Operator OCI module image: ${KEDA_OPERATOR_REPO}:${MODULE_TAG}"
  sleep 10
done

echo "Keda Operator OCI module image available"

until $(skopeo list-tags ${PROTOCOL}${KEDA_MANAGER_REPO} | jq '.Tags|any(. == env.IMAGE_TAG)'); do
  echo "Waiting for Keda Manager binary image: ${KEDA_MANAGER_REPO}:${IMAGE_TAG}"
  sleep 10
done

echo "Keda Manager binary image available"
