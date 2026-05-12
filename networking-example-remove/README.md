# Standalone Hub-Spoke Networking Modules

This folder contains vibecoded placeholder networking modules for the demo. They exist only so the repository can show an end-to-end onboarding flow.

Adopting teams should replace or wrap this deployment with their own governed VNet vending/IPAM process so the central networking platform owns address allocation, peering, DNS, routing, security policy, and approvals. Preserve the downstream contract by publishing the vendored VNet and subnet IDs to the same GitHub Actions variables used by workload deployments.

## Modules

| Module | Purpose |
| --- | --- |
| `modules/hub/main.bicep` | Deploys the hub VNet, Azure Bastion, a small Windows jump VM, NAT Gateway, and hub-owned Private DNS zones. |
| `modules/spoke/main.bicep` | Deploys one spoke VNet, creates bidirectional hub/spoke peering, and links the spoke VNet to hub-owned Private DNS zones. |
| `modules/shared/hub-peering.bicep` | Internal helper used by the spoke module to create hub-to-spoke peering at the hub resource-group scope. |
| `modules/shared/private-dns-zone-links.bicep` | Internal helper used by the spoke module to link a spoke VNet to hub-owned Private DNS zones. |

## Hub module

The hub module deploys:

- Hub VNet, default `10.0.0.0/16`.
- `AzureBastionSubnet`, default `10.0.0.0/26`.
- `snet-management`, default `10.0.1.0/24`.
- Optional `snet-private-endpoints`, default `10.0.2.0/24`.
- Management NSG allowing RDP only from Azure Bastion.
- NAT Gateway for jump VM outbound access.
- Azure Bastion with Standard public IP.
- Windows 11 jump VM without public IP.
- Hub-owned Private DNS zones and hub VNet links.

The module always deploys these Private DNS zones:

- `privatelink.cognitiveservices.azure.com`
- `privatelink.openai.azure.com`
- `privatelink.services.ai.azure.com`

It can also deploy zones for Storage, Cosmos DB, AI Search, Key Vault, ACR, App Configuration, and Container Apps.

Important outputs:

- `hubVnetId`
- `hubVnetName`
- `managementSubnetId`
- `bastionHostName`
- `jumpVmName`
- `jumpVmPrincipalId`
- `privateDnsZoneIds`

## Spoke module

The spoke module deploys:

- Spoke VNet.
- `snet-private-endpoints`.
- Optional `snet-ai-foundry-agent` delegated to `Microsoft.App/environments`.
- Optional `snet-container-apps` delegated to `Microsoft.App/environments`.
- Spoke-to-hub VNet peering.
- Hub-to-spoke VNet peering.
- VNet links from hub-owned Private DNS zones to the spoke VNet.

The spoke module expects the hub module outputs as inputs. At minimum, pass:

- `hubVnetId`
- `hubVnetName`
- `hubResourceGroupName`
- `privateDnsZoneIds`

## Automatic spoke address allocation

Terraform onboarding always allocates the spoke VNet address space before deploying this module. The allocator lives at `scripts/allocate-spoke-address-space.ps1` and is called from `../onboarding/main.tf` through Terraform's external data source.

The allocator uses Azure CLI to query the connected hub topology:

- the hub VNet address prefixes
- all VNet peerings on the hub VNet
- the address prefixes of each directly peered remote VNet

It then selects the first non-overlapping `/16` from `10.0.0.0/8` and passes concrete prefixes to `modules/spoke/main.bicep`. The Bicep module remains declarative and still receives explicit address prefixes at deployment time.

The derived subnet pattern is:

- `snet-private-endpoints`: `10.x.0.0/24`
- `snet-ai-foundry-agent`: `10.x.1.0/24`
- `snet-container-apps`: `10.x.6.0/23`

The allocation scope is the connected network: the hub VNet plus VNets directly peered to that hub. For cross-repository concurrent onboarding, use a shared Terraform backend lock or external IPAM to avoid two runs reserving the same next prefix at the same time.

## Deployment order

1. Deploy the hub module to the hub resource group.
2. Capture hub outputs.
3. Deploy each spoke module to the target spoke resource group with the hub outputs.
4. Deploy workload private endpoints into the spoke private endpoint subnet and use the hub Private DNS zone IDs in private endpoint DNS zone groups.

## Example commands

Set the jump VM password before deploying the hub example:

```powershell
$env:HUB_JUMP_ADMIN_PASSWORD = '<strong-password>'
az deployment group create `
  --resource-group '<hub-rg>' `
  --template-file 'networking-example-remove/modules/hub/main.bicep' `
  --parameters 'networking-example-remove/examples/hub.main.bicepparam'
```

Deploy the hub and store its outputs in reusable files for spoke deployments:

```powershell
.\networking-example-remove\scripts\export-hub-outputs.ps1 `
  -HubResourceGroupName '<hub-rg>' `
  -HubDeploymentName 'hub-network' `
  -HubJumpAdminPassword '<strong-password>'
```

This creates:

- `networking-example-remove/.outputs/hub-network.env.ps1`, a PowerShell file that sets the environment variables used by `spoke.main.bicepparam`.
- `networking-example-remove/.outputs/hub-network.outputs.json`, a JSON copy of the hub output values.

Deploy a spoke by loading the saved hub output file and running the spoke module:

```powershell
. .\networking-example-remove\.outputs\hub-network.env.ps1

az deployment group create `
  --resource-group '<spoke-rg>' `
  --template-file 'networking-example-remove/modules/spoke/main.bicep' `
  --parameters 'networking-example-remove/examples/spoke.main.bicepparam'
```

If you are not using the exported environment file, set the spoke example environment variables manually:

```powershell
$hub = az deployment group show `
  --resource-group '<hub-rg>' `
  --name '<hub-deployment-name>' `
  --query properties.outputs `
  -o json | ConvertFrom-Json

$env:HUB_SUBSCRIPTION_ID = az account show --query id -o tsv
$env:HUB_RESOURCE_GROUP_NAME = '<hub-rg>'
$env:HUB_PRIVATE_DNS_RESOURCE_GROUP_NAME = '<hub-rg>'
$env:HUB_VNET_NAME = $hub.hubVnetName.value
$env:HUB_VNET_ID = $hub.hubVnetId.value
$env:DNS_COGNITIVE_SERVICES_ID = $hub.privateDnsZoneIds.value.cognitiveServices
$env:DNS_OPENAI_ID = $hub.privateDnsZoneIds.value.openAi
$env:DNS_AI_SERVICES_ID = $hub.privateDnsZoneIds.value.aiServices
$env:DNS_BLOB_ID = $hub.privateDnsZoneIds.value.blob
$env:DNS_FILE_ID = $hub.privateDnsZoneIds.value.file
$env:DNS_COSMOS_ID = $hub.privateDnsZoneIds.value.cosmos
$env:DNS_SEARCH_ID = $hub.privateDnsZoneIds.value.search
$env:DNS_KEYVAULT_ID = $hub.privateDnsZoneIds.value.keyVault
$env:DNS_ACR_ID = $hub.privateDnsZoneIds.value.acr
$env:DNS_APPCONFIG_ID = $hub.privateDnsZoneIds.value.appConfig
$env:DNS_CONTAINERAPPS_ID = $hub.privateDnsZoneIds.value.containerApps
```

Then deploy the spoke:

```powershell
az deployment group create `
  --resource-group '<spoke-rg>' `
  --template-file 'networking-example-remove/modules/spoke/main.bicep' `
  --parameters 'networking-example-remove/examples/spoke.main.bicepparam'
```

## Reachability model

- The hub jump VM can reach hub private endpoints through local VNet routing and hub DNS links.
- The hub jump VM can reach spoke private endpoints through hub-to-spoke peering and hub-owned Private DNS zones.
- Spoke resources can reach hub private endpoints through spoke-to-hub peering and spoke DNS links.
- Spoke resources can resolve private endpoints in their own spoke when private endpoint DNS zone groups target the hub DNS zone IDs.
- Spoke-to-spoke routing is not transitive through VNet peering. Add Azure Firewall, an NVA, route tables, and forwarded traffic settings if transitive spoke-to-spoke routing is required later.
