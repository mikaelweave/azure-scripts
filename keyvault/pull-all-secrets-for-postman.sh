#!/usr/bin/env bash

set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error

# Find the path on the system of the script and repo
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
usage() {
  echo "Usage: $0 [ -k VAULT-NAME ] [ -o OUTPUT-FILENAME ]" 1>&2 
}
exit_abnormal() {
  usage
  exit 1
}

declare VAULT_NAME=""
declare OUTPUT_FILE=""

while getopts ":k:o:" options; do
  case "${options}" in
    k)
      VAULT_NAME=${OPTARG}
      ;;
    o)
      OUTPUT_FILE=${OPTARG}
      ;;
    :)
      echo "Error: -${OPTARG} requires an argument."
      exit_abnormal
      ;;
    *)
      exit_abnormal
      ;;
  esac
done

if [ "$VAULT_NAME" = "" ]; then
    echo "Error: -k arguement is required"
    exit_abnormal
fi
if [ "$OUTPUT_FILE" = "" ]; then
    OUTPUT_FILE="${SCRIPT_DIR}/${VAULT_NAME}-output.json"
fi

# Ensure the azure cli is logged in
if ! az account show &> /dev/null
then
    echo -e "\033[0;31m You must login to the azure cli before running this script.\033[0m\n"
    exit
fi

#Check KV exists
echo "Checking for KeyVault "$VAULT_NAME"..."
VAULT_EXISTS=$(az keyvault list --query "[?name == '$VAULT_NAME'].name" --out tsv)
if [[ -z "$VAULT_EXISTS" ]]; then
        echo "Cannot Locate Key Vault ${VAULT_NAME}."
        exit 1
fi

# Pull secrets
echo "Pulling list of secrets..."
SECRETS+=($(az keyvault secret list --vault-name $VAULT_NAME --query "[].id" -o tsv))

OUTPUT="{"

echo "Pulling secret values..."
for SECRET in "${SECRETS[@]}"; do
    SECRET_NAME=$(echo "$SECRET" | sed 's|.*/||')
    SECRET=$(az keyvault secret show --vault-name $VAULT_NAME -n $SECRET_NAME --query "value" -o tsv)
    OUTPUT+="\"${SECRET_NAME}\": \"${SECRET}\","
done

OUTPUT=`echo $OUTPUT | sed 's/,$//'`
OUTPUT+="}"

echo $OUTPUT | jq '.' > $OUTPUT_FILE
echo "Done!"

exit 0