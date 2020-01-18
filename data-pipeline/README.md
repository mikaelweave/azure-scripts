# Data Pipeline

This is a work in progress for a basic data pipeline in Azure using Azure Data Factory, Azure Databricks, Azure Data Lake Gen 2, and SQL Data Warehouse. The goal of this repository is an example solution tying all of these pieces together.

## Design choices

The resources will be accessed using a service principal whose details are provided at provisioning time.

## How to run the sample

Provisiong
```
terraform init
terraform plan -var "spnObjectId=<spn object id>" -var "spnAppId=<spn app id>" -out plan
terraform apply play
```

Adding external user to SQL
```
pwsh setupSql.ps1 -ServicePrincipalId "<spn app id>" -ServicePrincipalPassword "<spn password>" -TenantId "<tenant id>" -SQLServerName "sqlspnauthtest" -userObjectId "<user to add AAD object id>" -userName "<user to add sql username>"
```