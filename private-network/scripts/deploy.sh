#!/bin/bash

set -eou pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# First ensure you have a proper .env file (in the same format as .env.sample) with the deployment values filled out
# Load settings from .env file
cd ${SCRIPT_DIR}/../
if [[ -f ".env" ]]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set TF_VARS
export TF_VAR_AZURE_CLIENT_ID=$AZURE_CLIENT_ID
export TF_VAR_AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET

# Expects an authenticated az shell
az account set --subscription $AZURE_SUBSCRIPTION_ID

# Setup terraform backend
rm -rf beconf.tfvars
cat << EOT >> beconf.tfvars
resource_group_name = "${TF_STATE_RG_NAME}"
storage_account_name = "${TF_STATE_STORAGE_ACCOUNT_NAME}"
container_name = "${TF_STATE_CONTAINER_NAME}"
key = "master.tfstate"
EOT

# Initialize terraform
terraform init -backend-config=beconf.tfvars

# Validate terraform
terraform validate

# Terraform plan
{ PLAN_OUT=$(terraform plan -out plan -var base_name=$BASE_NAME -var location=$LOCATION \
                                      -var vm_username=$VM_USERNAME -var vm_password=$VM_PASSWORD \
                                      | tee /dev/fd/5); } 5>&1

# Terraform Apply
if [[ "$PLAN_OUT" == *"No changes."* ]]; then
    echo "No terraform changes detected, continuing"
else
    while true; do
        read -p "Do you want to deploy this plan? " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    terraform apply plan
fi