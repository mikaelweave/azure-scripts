#!/usr/bin/env bash
set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error


PRIVATE_SP_NAME="fhir-proxy-private-client"
PUBLIC_SP_NAME="fhir-proxy-public-client"


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

    SP=`az ad sp create-for-rbac --name $1 --output json`
    APP_ID=`echo $SP | jq -r '.appId'`
    OBJECT_ID=`az ad sp show --id $APP_ID --query "objectId" --out tsv`
    TENANT_ID=`echo $SP | jq -r '.tenant'`
    SECRET=`echo $SP | jq -r '.password'`

    echo "Service Principal Information:"
    echo $SP | jq .
}


# Checks to see if app role is already assigned
function checkAppRoleAssignment()
{
    APP_ROLE_ASSIGNMENTS=$(az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignedTo")

    echo $APP_ROLE_ASSIGNMENTS | \
        jq -r --arg APP_ROLE_ID "$3" --arg PUBLIC_SP_OBJECT_ID "$2" \
            '.value[] | select(.appRoleId==$APP_ROLE_ID and .principalId==$PUBLIC_SP_OBJECT_ID)'

    return
}


# Grants specified app role on an AAD application to a specified principal
# $1 ObjectId of the App access is being granted to
# $2 PrincipalID of the user, group, or service principal access is granted to
# $3 App Role ID
function grantAppRole()
{
    az rest --method POST \
        --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignments" \
        --body "{\"principalId\": \"$2\", \"resourceId\": \"$1\", \"appRoleId\": \"$3\"}"
}

echo "Creating private service principal for the proxy to connect to FHIR..."
createServicePrincipal "$PRIVATE_SP_NAME" "PRIVATE_SP_APP_ID" "PRIVATE_SP_OBJECT_ID" "PRIVATE_SP_TENAET_ID" "PRIVATE_SP_SECRET"

#echo "Creating public service principal for the proxy to connect to FHIR..."
#createServicePrincipal "$PUBLIC_SP_NAME" "PUBLIC_SP_APP_ID" "PUBLIC_SP_OBJECT_ID" "PUBLIC_SP_TENAET_ID" "PUBLIC_SP_SECRET"

#echo "Granting FHIR Proxy Client Service Principal access to FHIR Proxy..."
#for APP_ROLE_ID in '24c50db1-1e11-4273-b6a0-b697f734bcb4' '2d1c681b-71e0-4f12-9040-d0f42884be86'
#do
#    if [ -z `checkAppRoleAssignment "$PRIVATE_SP_OBJECT_ID" "$PUBLIC_SP_OBJECT_ID" "$APP_ROLE_ID"` ]
#    then
#       grantAppRole "$PRIVATE_SP_OBJECT_ID" "$PUBLIC_SP_OBJECT_ID" "$APP_ROLE_ID"
#    fi
#done
