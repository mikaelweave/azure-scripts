#!/usr/bin/env bash
set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error

# Find the path on the system of the script and repo
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_DIR="${SCRIPT_DIR}/.."

# Load from .env file from repo root
unset RESOURCE_GROUP; unset LOCATION; unset PRIVATE_SP; unset PUBLIC_SP; unset FUNCTION_SP;
if [ -f "${REPO_DIR}/.env" ]
then
  set -a
  export $(cat "${REPO_DIR}/.env" | sed -e '/^#/d;/^\s*$/d' -e "s/'/'\\\''/g" -e "s/=\(.*\)/='\1'/g" | xargs)
  set +a
fi

# Ensure the azure cli is logged in
if ! az account show &> /dev/null
then
    echo -e "\033[0;31m You must login to the azure cli before running this script.\033[0m\n"
    exit
fi

# Create resource group if needed
echo "Creating resource group if needed..."
az group create --name $RESOURCE_GROUP --location $LOCATION --output table

GROUP_UNIQUE_STR=`az group show --name $RESOURCE_GROUP --query id --output tsv | md5sum | cut -c1-5`

# Get executing user ID
CURRENT_USER=`az ad signed-in-user show | jq '.objectId'`

# Create the Private Service Principal if it's not set in our shell
if [ -z ${PRIVATE_SP+x} ]; then
  echo "Creating or updating private service principal..."
  export PRIVATE_SP=`SP_NAME="fhir-proxy-private-client-${GROUP_UNIQUE_STR}" ./scripts/create-proxy-spn.sh`
  echo "PRIVATE_SP=$(echo $PRIVATE_SP | tr -d ' ')" >> "${REPO_DIR}/.env"
fi

# Create the Public Service Principal if it's not set in our shell
if [ -z ${PUBLIC_SP+x} ]; then
  echo "Creating or updating public service principal..."
  export PUBLIC_SP=`SP_NAME="fhir-proxy-public-client-${GROUP_UNIQUE_STR}" ./scripts/create-proxy-spn.sh`
  echo "PUBLIC_SP=$(echo $PUBLIC_SP | tr -d ' ')" >> "${REPO_DIR}/.env"
fi

# Create the Function Service Principal if it's not set in our shell
if [ -z ${FUNCTION_SP+x} ]; then
  echo "Creating or updating function service principal..."
  FUNCTION_APP_NAME="fhir-with-proxy-${GROUP_UNIQUE_STR}-func"
  export FUNCTION_SP=`SP_NAME="$FUNCTION_APP_NAME" ./scripts/create-proxy-spn.sh`
  echo "FUNCTION_SP=$(echo $FUNCTION_SP | tr -d ' ')" >> "${REPO_DIR}/.env"
  az ad app update --id `echo $FUNCTION_SP | jq -r '.appId'` \
    --reply-urls "https://${FUNCTION_APP_NAME}.azurewebsites.net/.auth/login/aad/callback"
fi

# Create and assign app roles for our Proxy
echo "Setting up app roles..."
./scripts/assign-app-roles.sh

# Deploy bicep template
echo "Deploying infra via Bicep..."
az deployment group create \
    --name main \
    --resource-group $RESOURCE_GROUP \
    --template-file "${REPO_DIR}/main.bicep" \
    --parameters groupUniqueString="$GROUP_UNIQUE_STR" \
    --parameters adminPrincipalIds="[$CURRENT_USER]" \
    --parameters privateServicePrincipal="$PRIVATE_SP" \
    --parameters publicServicePrincipal="$PUBLIC_SP" \
    --parameters functionServicePrincipal="$FUNCTION_SP" \
    --output table