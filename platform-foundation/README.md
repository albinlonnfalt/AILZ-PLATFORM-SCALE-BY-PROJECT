# Platform Foundation

This folder deploys the shared Microsoft Foundry resources for the AI Landing Zone.

It creates one central Microsoft Foundry / AI Services account with shared capability-host dependencies such as Storage, Cosmos DB, Azure AI Search, and optional Key Vault. It always deploys Log Analytics and Application Insights in the configured location, then connects Application Insights to the shared Foundry account. Future workload onboarding does not create separate Foundry accounts. Instead, each workload gets its own project in this shared Foundry account.

## Before Deployment

Deploy or identify the network that the platform foundation should use, then provide the required network parameters in [main.bicepparam](main.bicepparam). Replace the placeholder values for the hub VNet, subnet address ranges, and Private DNS zone IDs before deploying.

## Deployment

Deploy manually with Azure CLI, or add a platform-specific workflow that runs the same Bicep deployment.

```powershell
az group create `
  --name '<platform-foundation-rg>' `
  --location 'swedencentral'

az deployment group create `
  --resource-group '<platform-foundation-rg>' `
  --template-file 'platform-foundation/main.bicep' `
  --parameters 'platform-foundation/main.bicepparam'
```

## Publish Outputs

After deployment, copy the central Foundry outputs into [../manifests/_shared/platform-foundry.json](../manifests/_shared/platform-foundry.json). Onboarding uses these values to create one project per workload inside the shared Foundry account.