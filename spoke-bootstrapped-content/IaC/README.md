# AI Landing Zone Workload IaC

Bicep templates for deploying optional workload resources into an existing AI Landing Zone spoke network.

This deployment assumes onboarding Terraform has already created the spoke VNet, subnets, private DNS integration, and central Microsoft Foundry project. It only deploys workload-side optional services and RBAC.

## What It Deploys

Depending on feature flags, `main.bicep` can deploy:

- Workload user-assigned managed identity
- Log Analytics workspace and Application Insights
- Cosmos DB, AI Search, Storage, Key Vault, ACR, and App Configuration
- Internal Container Apps Environment with private endpoint
- Private endpoints for selected services
- Workload, developer, and Foundry project RBAC assignments

It does not create VNets, subnets, VNet peerings, private DNS zones, Foundry accounts, or Foundry projects.

## Main Files

| File | Purpose |
|------|---------|
| `main.bicep` | Root deployment template |
| `main.parameters.json` | Workload deployment parameters |
| `modules/optional-platform-resources.bicep` | Optional PaaS resources, private endpoints, and workload identity |
| `modules/monitoring/monitoring.bicep` | Log Analytics and Application Insights |
| `modules/rbac-workload.bicep` | Least-privilege workload identity roles |
| `modules/rbac-developer.bicep` | Optional developer access roles |
| `modules/rbac/foundry-project-role-assignment.bicep` | Central Foundry project access |

## Required Inputs

The downstream deployment workflow supplies network and Foundry values from onboarding Terraform, including:

- `existingVnetId`
- `privateEndpointSubnetId`
- `containerAppsSubnetId` when `deployContainerApps` is `true`
- `privateDnsZoneIds`
- `foundryProjectId`

Common workload parameters:

| Parameter | Description |
|-----------|-------------|
| `baseName` | Base resource name |
| `appName` | App identifier used for the workload identity name |
| `location` | Azure region |
| `deployerPrincipalId` | Optional developer principal for broad dev/debug access |

## Feature Flags

Set these booleans in `main.parameters.json` to choose what gets deployed:

- `deployContainerApps`
- `deployAcr`
- `deployAppConfig`
- `deployGenaiCosmos`
- `deployGenaiSearch`
- `deployGenaiStorage`
- `deployGenaiKeyVault`

## Deploy

```bash
az deployment group create \
  --resource-group <rg-name> \
  --template-file main.bicep \
  --parameters main.parameters.json
```

Downstream GitHub Actions deployments merge Terraform-created network variables into `main.parameters.json` before running the deployment.
