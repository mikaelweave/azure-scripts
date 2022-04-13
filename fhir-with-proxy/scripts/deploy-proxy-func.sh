#!/usr/bin/env bash

set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error

# Find the path on the system of the script and repo
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_DIR="${SCRIPT_DIR}/.."

# Load from .env file from repo root
if [ -f "${REPO_DIR}/.env" ]
then
  export $(cat "${REPO_DIR}/.env" | sed 's/#.*//g' | xargs)
fi

# Downloads a zip file from a URL and extracts it. Useful for downolad repo zips.
# $1 URL to the zip for the repo
function downloadAndExtractZip()
{
    # Make temp dir if needed
    mkdir -p "${REPO_DIR}/tmp" >/dev/null 2>&1

    # Download FHIR Proxy code
    curl -L $1 --output "${REPO_DIR}/tmp/repo.zip"

    unzip -o "${REPO_DIR}/tmp/repo.zip" -d "${REPO_DIR}/tmp" 
}


# Deploys functionapp from git repo
# $1 = Resource Group Name
# $2 = Function App Name
# $4 = Git repo url
function deployFromRepo()
{

  az functionapp stop -g $1 -n $2

  echo "Deploying function from ${3} to function app ${2} in resource group ${1}"

  az functionapp deployment source config --branch main --manual-integration  \
    -g $1 -n $2 --repo-url $3

    az functionapp start -g $1 -n $2
}


# Deploys functionapp from a local folder (zip)
# $1 = Resource Group Name
# $2 = Function App Name
# $4 = Local folder path
function deployFromLocal()
{
  eval "${SCRIPT_DIR}/package-func.sh" $3 "${REPO_DIR}/tmp/deploy-func.zip"

  az functionapp stop -g $1 -n $2

  echo "Deploying function from ${3} to function app ${2} in resource group ${1}"

  az functionapp deployment source config-zip -g $1 -n $2 \
    --src "${REPO_DIR}/tmp/deploy-func.zip"

  az functionapp start -g $1 -n $2
}


FUNCTION_APP_NAME=`az deployment group show -g ${RESOURCE_GROUP} \
                   -n main --query properties.outputs.functionAppName.value \
                   --output tsv`

downloadAndExtractZip "https://github.com/microsoft/fhir-proxy/archive/refs/heads/main.zip"
deployFromLocal "$RESOURCE_GROUP" "$FUNCTION_APP_NAME" "${REPO_DIR}/tmp/fhir-proxy-main/FHIRProxy"