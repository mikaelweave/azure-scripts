#!/usr/bin/env bash
set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error

# Load from .env file
if [ -f .env ]
then
  export $(cat .env | sed 's/#.*//g' | xargs)
fi

# Ensure the azure cli is logged in
if ! az account show &> /dev/null
then
    printf "\033[0;31m You must login to the azure cli before running this script.\033[0m\n"
    exit
fi


# Get token for our FHIR Service
FHIR_TOKEN=`az account get-access-token \
           --resource=$FHIR_ENDPOINT \
           --query accessToken --output tsv`


# Sends resource to the FHIR Service.
# $1 The string representation of the resouce
function sendResource() 
{
    RESOURCE_TYPE=`echo $1 | jq -r '.resourceType'`
    HAS_ID=`echo $1 | jq 'has ("id")'`
    if [ "$HAS_ID" = "true" ]
    then
        ID=`echo $1 | jq -r '.id'`

        echo "PUT ${FHIR_ENDPOINT}/${RESOURCE_TYPE}/${ID}"
        curl --silent --output /dev/null --show-error --fail \
            -X PUT --header "Authorization: Bearer $FHIR_TOKEN" \
            --header 'Content-Type: application/json' \
            "${FHIR_ENDPOINT}/${RESOURCE_TYPE}/${ID}" \
            -d "$1"
        echo ""
    else
        echo "POST $FHIR_ENDPOINT/$RESOURCE_TYPE"
        curl --silent --output /dev/null --show-error --fail \
            -X POST --header "Authorization: Bearer $FHIR_TOKEN" \
            --header 'Content-Type: application/json' \
            "${FHIR_ENDPOINT}/${RESOURCE_TYPE}" \
            -d "$1"
        echo ""
    fi
}


# Loop over all json files and 
for FILE in *.json
do
    echo "Processing $FILE..."
    FILE_TYPE=`cat $FILE | jq -r 'if type=="array" then "ARRAY" else "RESOURCE" end'`
    if [ $FILE_TYPE == "ARRAY" ]
    then
        for k in $(jq '. | keys | .[]' $FILE); do
            echo "Processing array item ${k}..."
            ITEM=$(jq -r ".[$k]" $FILE)
            sendResource "$ITEM"
        done
    else
        sendResource "$(cat $FILE)"
    fi

done
