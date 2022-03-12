#!/usr/bin/env bash
set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error


# Ensure jq is installed
if ! command -v jq &> /dev/null
then
    printf "\033[0;31m jq could not be found. jq must be installed for this script.\033[0m\n"
    exit
fi


# Creates service principal and sets variables to informatino aboiut service principal
# $1 name of the service principal to create
# $2 name of the variable to set as the service principal appId
# $3 name of the variable to set as the service principal objectId
# $4 name of the variable to set as the service principal tenantId
# $5 name of the variable to set as the service principal secret
function createServicePrincipal()
{
    local -n APP_ID=$2
    local -n OBJECT_ID=$3
    local -n TENANT_ID=$4
    local -n SECRET=$5

    SP=`az ad sp create-for-rbac --name $1 --only-show-errors --output json`
    APP_ID=`echo $SP | jq -r '.appId'`
    OBJECT_ID=`az ad sp show --id $APP_ID --query "objectId" --out tsv`
    TENANT_ID=`echo $SP | jq -r '.tenant'`
    SECRET=`echo $SP | jq -r '.password'`

    echo $SP | jq --arg objectId $OBJECT_ID '. + {objectId: $objectId}'
}

createServicePrincipal "$SP_NAME" "SP_APP_ID" "SP_OBJECT_ID" "SP_TENAET_ID" "SP_SECRET"


