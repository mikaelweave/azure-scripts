#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BASE_NAME="mikaelw-go-func-test"

# First ensure you have a proper .env file (in the same format as .env.sample) with the deployment values filled out
# Load settings from .env file
export $(grep -v '^#' ${SCRIPT_DIR}/../.env | xargs)

# Expects an authenticated az shell
az account set --subscription $SUBSCRIPTION_ID

# Change to terraform directory
cd ${SCRIPT_DIR}/../deploy

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
#TODO - add logic test to see if this is running from CI, if so run 'terraform plan -out plan -no-color -input=false' instead
{ PLAN_OUT=$(terraform plan -out plan -var base_name=$BASE_NAME | tee /dev/fd/5); } 5>&1


#TODO - don't run in CI
if [[ "$PLAN_OUT" == *"No changes."* ]]; then
    echo "No terraform changes detected, continuing"
else
    while true; do
        read -p "Do you wish to deploy this plan?" yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    # Terraform apply
    #TODO - add logic to test if running from CI, of so run 'terraform apply -no-color -input=false -auto-approve plan' instead
    terraform apply plan
fi

# Deploys function app
cd "${SCRIPT_DIR}/../src"
func azure functionapp publish "${BASE_NAME}-fa" --no-build --force