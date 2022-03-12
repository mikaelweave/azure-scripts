#!/usr/bin/env bash
set -euo pipefail

# Find the path on the system of the script and repo
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_DIR="${SCRIPT_DIR}/.."

# Create Postman Environment for FHIR Proxy --- Author Steve Ordahl Principal Architect Health Data Platform

# FROM https://raw.githubusercontent.com/microsoft/fhir-proxy/main/scripts/createpostmanproxyenv.bash#

usage() {
  echo "Usage: $0 -k <keyvault>" 1>&2
  exit 1
}

function fail {
  echo $1 >&2
  exit 1
}

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


# Initialize parameters specified from command line
while getopts ":k:n:sp" arg; do
  case "${arg}" in
  k)
    kvname=${OPTARG}
    ;;
  esac
done
shift $((OPTIND - 1))
echo "Executing "$0"..."

# Ensure the azure cli is logged in
if ! az account show &> /dev/null
then
    echo -e "\033[0;31m You must login to the azure cli before running this script.\033[0m\n"
    exit
fi

#Prompt for parameters is some required parameters are missing
if [[ -z "$kvname" ]]; then
  echo "Enter keyvault name that contains the fhir proxy configuration: "
  read kvname
fi
if [ -z "$kvname" ]; then
  echo "Keyvault name must be specified"
  usage
fi

#Check KV exists
echo "Checking for keyvault "$kvname"..."
kvexists=$(az keyvault list --query "[?name == '$kvname'].name" --out tsv)
if [[ -z "$kvexists" ]]; then
  echo "Cannot Locate Key Vault "$kvname" this deployment requires access to the proxy keyvault...Is the Proxy Installed?"
  exit 1
fi
set +e

#Start deployment
echo "Creating Postman environment for FHIR Proxy..."
(
  echo "Loading configuration settings from key vault "$kvname"..."
  FHIR_URL=`getVaultSecret $kvname "FS-URL"`
  TENANT=`getVaultSecret $kvname "FS-TENANT-NAME"`
  FHIR_CLIENT_ID=`getVaultSecret $kvname "FS-CLIENT-ID"`
  FHIR_CLIENT_SECRET=`getVaultSecret $kvname "FS-CLIENT-SECRET"`
  PROXY_HOST=`getVaultSecret $kvname "FP-HOST"`
  PROXY_CLIENT_ID=`getVaultSecret $kvname "FP-SC-CLIENT-ID"`
  PROXY_CLIENT_SECRET=`getVaultSecret $kvname "FP-SC-SECRET"`
  PROXY_RESOURCE=`getVaultSecret $kvname "FP-RBAC-CLIENT-ID"`
  
  if [ -z "$FHIR_CLIENT_ID" ] || [ -z "$PROXY_CLIENT_ID" ]; then
    echo $kvname" does not appear to contain fhir proxy settings...Is the Proxy Installed?"
    exit 1
  fi

  echo "Generating Postman environment for proxy access..."

  pmuuid=$(uuid)
  pmenv=$(<${SCRIPT_DIR}/postman-template.json)
  pmscope="https://"$PROXY_HOST"/.default"
  pmfhirurl="https://"$PROXY_HOST"/fhir"
  pmstsurl="https://"$PROXY_HOST"/AadSmartOnFhirProxy"
  pmenv=${pmenv/~guid~/$pmuuid}
  pmenv=${pmenv/~envname~/$PROXY_HOST}

  pmenv=${pmenv/~fhirurl~/$FHIR_URL}
  pmenv=${pmenv/~tenentid~/$TENANT}
  pmenv=${pmenv/~fhirClientId~/$FHIR_CLIENT_ID}
  pmenv=${pmenv/~fhirClientSecret~/$FHIR_CLIENT_SECRET}
  pmenv=${pmenv/~resource~/$FHIR_URL}
  pmenv=${pmenv/~proxyHost~/$PROXY_HOST}
  pmenv=${pmenv/~proxyClientId~/$PROXY_CLIENT_ID}
  pmenv=${pmenv/~proxyClientSecret~/$PROXY_CLIENT_SECRET}
  pmenv=${pmenv/~proxyResource~/$PROXY_RESOURCE}

  echo $pmenv > "${REPO_DIR}/${PROXY_HOST}.postman_environment.json"
)
