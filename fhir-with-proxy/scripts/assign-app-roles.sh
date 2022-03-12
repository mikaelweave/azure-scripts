#!/usr/bin/env bash
set -euo pipefail

# -e: immediately exit if any command has a non-zero exit status
# -o pipefail: prevents errors in a pipeline from being masked
# -u: unset variables cause script exit and error

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_DIR="${SCRIPT_DIR}/.."

# Ensure jq is installed
if ! command -v jq &> /dev/null
then
    printf "\033[0;31m jq could not be found. jq must be installed for this script.\033[0m\n"
    exit
fi

# Checks to see if app role is already assigned
function checkAppRoleAssignment()
{
    APP_ROLE_ASSIGNMENTS=$(az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals/$1/appRoleAssignedTo")

    echo `echo $APP_ROLE_ASSIGNMENTS | \
        jq -r --arg APP_ROLE_ID "$3" --arg PUBLIC_SP_OBJECT_ID "$2" \
            '.value[] | select(.appRoleId==$APP_ROLE_ID and .principalId==$PUBLIC_SP_OBJECT_ID)'` \
        | wc -c

    return
}

#6e2b10a7-46d0-4b6d-ad76-c6da56d487bb e167ec49-f0e9-46f3-b3af-0a04d3561196 24c50db1-1e11-4273-b6a0-b697f734bcb4
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

FUNCTION_SP_OBJECT_ID=`echo $FUNCTION_SP | jq -r '.objectId'`
FUNCTION_SP_APP_ID=`echo $FUNCTION_SP | jq -r '.appId'`
PUBLIC_SP_OBJECT_ID=`echo $PUBLIC_SP | jq -r '.objectId'`
PUBLIC_SP_APP_ID=`echo $PUBLIC_SP | jq -r '.appId'`

mkdir -p "${REPO_DIR}/tmp" >/dev/null 2>&1
curl -L -Z 'https://raw.githubusercontent.com/microsoft/fhir-proxy/main/scripts/fhirroles.json' --output "${REPO_DIR}/tmp/fhirroles.json"
az ad app update --id $FUNCTION_SP_APP_ID --app-roles @"${REPO_DIR}/tmp/fhirroles.json"

echo "Granting FHIR Proxy Client Service Principal access to FHIR Proxy..."
for APP_ROLE_ID in '24c50db1-1e11-4273-b6a0-b697f734bcb4' '2d1c681b-71e0-4f12-9040-d0f42884be86'
do
    # JSON will be empty if no role is assigned
    if [[ `checkAppRoleAssignment "$FUNCTION_SP_OBJECT_ID" "$PUBLIC_SP_OBJECT_ID" "$APP_ROLE_ID"` -lt 4 ]]
    then
        echo "Granting role ${APP_ROLE_ID}..."
        grantAppRole "$FUNCTION_SP_OBJECT_ID" "$PUBLIC_SP_OBJECT_ID" "$APP_ROLE_ID"
    fi
done