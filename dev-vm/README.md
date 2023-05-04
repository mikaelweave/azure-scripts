# Dev VM Deployment

1. Fill out `output.parameters.json`

2. Deploy template to your resource group.

```bash
az deployment group create --resource-group <myrg> --template-file azure-deploy.bicep --parameters output.parameters.json
```