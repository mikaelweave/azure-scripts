.DEFAULT_GOAL := help

## ----------------------------------------------------------------------
## Deploy FHIR With Proxy via Azure Bicep.
## 
## You must be logged into the Azure CLI and have the RESOURCE_GROUP and
## LOCATION environment variables set.
##
## export RESOURCE_GROUP="test" LOCATION="eastus" FUNCTION_CODE="~/PACKAGE.zip"
## 
## USAGE:
##    export RESOURCE_GROUP="test" LOCATION="eastus"
##    make deploy

##    export RESOURCE_GROUP="test"
##    make destropy
## ----------------------------------------------------------------------


## Create the azure resources and deploy the sample
.PHONY: deploy
deploy: deploy-infra deploy-func

## Create only the azure resources
.PHONY: deploy-infra
deploy-infra:
	az group create --name $(RESOURCE_GROUP) --location $(LOCATION) --output table
	az deployment group create --resource-group $(RESOURCE_GROUP) --template-file main.bicep --output table

## Deploy only the Function App. Depends on `deploy-infra` being run first.
.PHONY: deploy-func
deploy-func:
	export FUNCTION_APP_NAME=`az deployment group show -g ${RESOURCE_GROUP} -n main --query properties.outputs.functionAppName.value --output tsv`
	az functionapp deployment source config-zip -g ${RESOURCE_GROUP} -n ${FUNCTION_APP_NAME} --src ${FUNCTION_CODE}

## Remove the resource group and resources
.PHONY: destroy
destroy:
	az group delete --resource-group ${RESOURCE_GROUP}


## Show the help
.PHONY: help
help:
	@printf "Usage\n";

	@awk '{ \
			if ($$0 ~ /^.PHONY: [a-zA-Z\-\_0-9]+$$/) { \
				helpCommand = substr($$0, index($$0, ":") + 2); \
				if (helpMessage) { \
					printf "\033[36m%-20s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^[a-zA-Z\-\_0-9.]+:/) { \
				helpCommand = substr($$0, 0, index($$0, ":")); \
				if (helpMessage) { \
					printf "\033[36m%-20s\033[0m %s\n", \
						helpCommand, helpMessage; \
					helpMessage = ""; \
				} \
			} else if ($$0 ~ /^##/) { \
				if (helpMessage) { \
					helpMessage = helpMessage"\n                     "substr($$0, 3); \
				} else { \
					helpMessage = substr($$0, 3); \
				} \
			} else { \
				if (helpMessage) { \
					print "\n                     "helpMessage"\n" \
				} \
				helpMessage = ""; \
			} \
		}' \
		$(MAKEFILE_LIST)