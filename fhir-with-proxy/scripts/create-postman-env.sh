#!/usr/bin/env bash
set -euo pipefail

# Find the path on the system of the script and repo
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_DIR="${SCRIPT_DIR}/.."

# Load from .env file from repo root
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

GROUP_UNIQUE_STR=`az group show --name $RESOURCE_GROUP --query id --output tsv | md5sum | cut -c1-5`
VAULT_NAME="${PREFIX}-${GROUP_UNIQUE_STR}-kv"

# Create Postman Environment for FHIR Proxy --- Author Steve Ordahl Principal Architect Health Data Platform

# FROM https://raw.githubusercontent.com/microsoft/fhir-proxy/main/scripts/createpostmanproxyenv.bash#

function retry {
  local n=1
  local max=5
  local delay=15
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
        ((n++))
        echo "Command failed. Retry Attempt $n/$max in $delay seconds:" >&2
        sleep $delay
      else
        fail "The command has failed after $n attempts."
      fi
    }
  done
}

function uuid() {
  uuidgen | tr -d - | tr -d '\n' | tr '[:upper:]' '[:lower:]' | pbcopy && pbpaste && echo
}

# Gets a secret from a keyvualt
# $1 = KeyVault Name
# $2 = Secret Name
function getVaultSecret() {
  az keyvault secret show --vault-name $1 --name $2 --query "value" --out tsv
}

#Check KV exists
echo "Checking for keyvault "$VAULT_NAME"..."
kvexists=$(az keyvault list --query "[?name == '$VAULT_NAME'].name" --out tsv)
if [[ -z "$kvexists" ]]; then
  echo "Cannot Locate Key Vault "$VAULT_NAME" this deployment requires access to the proxy keyvault...Is the Proxy Installed?"
  exit 1
fi
set +e

#Start deployment
echo "Creating Postman environment for FHIR Proxy..."
(
  echo "Loading configuration settings from key vault "$VAULT_NAME"..."
  FhirServerUrl=`getVaultSecret $VAULT_NAME "FS-URL"`
  FhirServerTenantId=`getVaultSecret $VAULT_NAME "FS-TENANT-NAME"`
  FhirServerClientId=`getVaultSecret $VAULT_NAME "FS-CLIENT-ID"`
  FhirServerClientSecret=`getVaultSecret $VAULT_NAME "FS-CLIENT-SECRET"`
  ProxyFunctionUrl=`getVaultSecret $VAULT_NAME "FP-HOST"`
  ProxyFunctionName=`echo $ProxyFunctionUrl| cut -d. -f1`

  FunctionAppClientId=`getVaultSecret $VAULT_NAME "FP-RBAC-CLIENT-ID"`
  FunctionAppClientSecret=`getVaultSecret $VAULT_NAME "FP-RBAC-CLIENT-SECRET"`

  PublicClientId=`getVaultSecret $VAULT_NAME "FP-SC-CLIENT-ID"`
  PublicClientSecret=`getVaultSecret $VAULT_NAME "FP-SC-SECRET"`
  
  if [ -z "$FhirServerClientId" ] || [ -z "$FunctionAppClientId" ]; then
    echo $VAULT_NAME" does not appear to contain fhir proxy settings...Is the Proxy Installed?"
    exit 1
  fi

  echo "Generating Postman environment for proxy access..."

  pmuuid=$(uuid)
  pmenv=$(<${SCRIPT_DIR}/postman-template.json)
  pmenv=${pmenv/~guid~/$pmuuid}
  pmenv=${pmenv/~envname~/$ProxyFunctionUrl}
  pmenv=${pmenv/~fhirurl~/$FhirServerUrl}
  pmenv=${pmenv/~tenentid~/$FhirServerTenantId}
  pmenv=${pmenv/~fhirClientId~/$FhirServerClientId}
  pmenv=${pmenv/~fhirClientSecret~/$FhirServerClientSecret}
  pmenv=${pmenv/~resource~/$FhirServerUrl}
  pmenv=${pmenv/~proxyFunctionUrl~/$ProxyFunctionUrl}
  pmenv=${pmenv/~functionClientId~/$FunctionAppClientId}
  pmenv=${pmenv/~functionClientSecret~/$FunctionAppClientSecret}
  pmenv=${pmenv/~publicClientId~/$PublicClientId}
  pmenv=${pmenv/~publicClientSecret~/$PublicClientSecret}

  echo $pmenv > "${REPO_DIR}/${ProxyFunctionName}.postman_environment.json"
)