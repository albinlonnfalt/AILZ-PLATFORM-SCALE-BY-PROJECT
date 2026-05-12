# Onboarding Terraform Module

This folder contains the Terraform configuration that provisions the prerequisites to onboard the Azure AI Landing Zone. The automation creates:

- A private GitHub repository prepared for the landing zone workload
- A user-assigned managed identity bound to the target subscription
- A demo spoke VNet peered to a pre-existing hub VNet, or the variable contract needed to plug in a governed VNet vending process
- Private DNS virtual network links from the hub-owned zones to the spoke VNet
- An APPID-derived project in the central Microsoft Foundry account deployed by `platform-foundation`
- Project-scoped RBAC, project connections, and an optional project capability host for the APPID-derived Foundry project identity against the shared capability-host dependencies
- Supporting GitHub Actions variables and federated credentials for OIDC-based automation

## Prerequisites

- Terraform v1.5 or later installed locally, or the GitHub Actions workflow in `.github/workflows/onboard.yml`
- Azure CLI or `azurerm` provider authentication with rights to the target subscription, including permission to create subscription-scoped role assignments
- Access to create repositories within the configured GitHub organization
- GitHub repository secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `GH_ORG_ADMIN_TOKEN` configured for the onboarding workflow
- A connectivity hub VNet deployed once before onboarding. Capture the hub outputs listed below in a Terraform variables file.
- A central Microsoft Foundry account deployed once by `platform-foundation` into the platform/foundation spoke. Capture the platform outputs in `manifests/_shared/platform-foundry.json`.

Onboarding grants the GitHub deployment user-assigned managed identity both `Contributor` and `Role Based Access Control Administrator` at the onboarded subscription scope. The downstream Bicep workload deployment creates resource-scoped role assignments for workload and developer identities, so the UAMI needs `Microsoft.Authorization/roleAssignments/write` in addition to normal resource deployment permissions. The principal running this Terraform must therefore have a role such as `Owner`, `User Access Administrator`, or sufficiently scoped `Role Based Access Control Administrator` at the target subscription.

## Local Terraform Variables

For local Terraform usage, create an untracked `*.auto.tfvars` file in this folder and set the onboarding, hub, and central Foundry values. The spoke network deployment needs values from the one-time hub deployment, and the central Foundry project module needs values from `platform-foundation`.

```hcl
ONBOARD_SUB_ID = "<spoke-subscription-guid>"
APPID          = "<appid>"
GITHUB_ORG     = "<github-org>"
LOCATION       = "swedencentral"

DEPLOY_SPOKE_NETWORK            = true
SPOKE_BASE_NAME                 = "az-ailz-<appid>"
DEPLOY_AI_FOUNDRY_AGENT_SUBNET  = true
DEPLOY_CONTAINER_APPS_SUBNET    = false
SPOKE_ADDRESS_POOL_PREFIX       = "10.0.0.0/8"
SPOKE_PREFIX_LENGTH             = 16
SPOKE_ALLOW_FORWARDED_TRAFFIC   = false
SPOKE_USE_REMOTE_GATEWAYS       = false
HUB_ALLOW_GATEWAY_TRANSIT       = false

HUB_SUBSCRIPTION_ID                  = "<hub-subscription-guid>" # optional when same as ONBOARD_SUB_ID
HUB_RESOURCE_GROUP_NAME              = "<hub-resource-group-name>"
HUB_PRIVATE_DNS_RESOURCE_GROUP_NAME  = "<hub-dns-resource-group-name>"
HUB_VNET_NAME                        = "<hub-vnet-name>"
HUB_VNET_ID                          = "<hub-vnet-resource-id>"

HUB_PRIVATE_DNS_ZONE_IDS = {
  cognitiveServices = "<privatelink.cognitiveservices.azure.com-zone-id>"
  openAi            = "<privatelink.openai.azure.com-zone-id>"
  aiServices        = "<privatelink.services.ai.azure.com-zone-id>"
  blob              = "<privatelink.blob.core.windows.net-zone-id>"
  file              = "<privatelink.file.core.windows.net-zone-id>"
  cosmos            = "<privatelink.documents.azure.com-zone-id>"
  search            = "<privatelink.search.windows.net-zone-id>"
  keyVault          = "<privatelink.vaultcore.azure.net-zone-id>"
  acr               = ""
  appConfig         = ""
  containerApps     = ""
}

CENTRAL_FOUNDRY_SUBSCRIPTION_ID      = "<foundry-subscription-guid>"
CENTRAL_FOUNDRY_RESOURCE_GROUP_NAME  = "<foundry-resource-group-name>"
CENTRAL_FOUNDRY_ACCOUNT_NAME         = "<foundry-account-name>"
CENTRAL_FOUNDRY_ACCOUNT_ID           = "<foundry-account-resource-id>"
CENTRAL_FOUNDRY_ACCOUNT_ENDPOINT     = "https://<foundry-account-name>.services.ai.azure.com/"
CENTRAL_FOUNDRY_PROJECT_NAME_PREFIX  = "ailz"

CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_NAME = "<storage-account-name>"
CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_ID   = "<storage-account-resource-id>"
CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_NAME       = "<cosmos-db-name>"
CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_ID         = "<cosmos-db-resource-id>"
CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_NAME  = "<ai-search-name>"
CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_ID    = "<ai-search-resource-id>"
CENTRAL_FOUNDRY_CAPABILITY_HOST_KEY_VAULT_NAME       = "<key-vault-name>"
CENTRAL_FOUNDRY_CAPABILITY_HOST_KEY_VAULT_ID         = "<key-vault-resource-id>"
```

Empty Private DNS zone IDs are skipped by the spoke template. Resource IDs are environment-specific but are not secrets. When `DEPLOY_SPOKE_NETWORK` is `true`, Terraform runs the repository-local spoke address allocator and passes the selected prefixes to the compiled spoke ARM template. Override the address pool or integrate your own VNet vending process if address allocation is centrally governed.

## Platform Foundry Outputs File

The central Microsoft Foundry account is deployed by `platform-foundation` into the platform/foundation spoke, not into the connectivity hub VNet. Onboarding needs those outputs to create one project per APPID.

For GitHub Actions onboarding, publish them to `manifests/_shared/platform-foundry.json`. For local Terraform usage, map those same values to the `CENTRAL_FOUNDRY_*` variables shown above.

Required values include:

- Central Foundry subscription, resource group, account name, and account resource ID.
- Central Foundry endpoint.
- Shared capability-host Storage Account, Cosmos DB, and AI Search names and resource IDs.
- Central Foundry account principal ID for shared platform metadata completeness.
- Optional shared Key Vault name and resource ID.

The APPID-derived Foundry project, the project-level capability-host connections, the capability host, and the RBAC required for those resources are implemented in `modules/central-foundry-project`. The root onboarding configuration passes platform outputs into that module and then publishes the resulting project metadata to the downstream GitHub repository.

The central Foundry account identity RBAC for shared capability-host dependencies is owned by `platform-foundation`. Onboarding only grants access for the project managed identity created for each APPID.

Onboarding also grants the GitHub deployment UAMI Azure AI User, Cognitive Services User, Cognitive Services OpenAI User, Azure AI Project Manager, and Role Based Access Control Administrator on the APPID-derived Foundry project so downstream automation can deploy and manage project-scoped assets.

## GitHub Actions Onboarding

The **Onboard AI Landing Zone** workflow can be triggered manually with a manifest folder such as `manifests/1001`, or automatically when one manifest folder changes on `main`. The folder name must match `app-id` in `meta-data-onboarding.json`.

The workflow:

1. Validates `meta-data-onboarding.json` and `main-parameters.json`.
2. Skips onboarding if the target `az-ailz-<appid>` repository already exists.
3. Builds `networking-example-remove/modules/spoke/main.bicep` into `networking-example-remove/templates/spoke-network.json`.
4. Generates `onboarding/onboard.auto.tfvars.json` from the manifest, `manifests/_shared/hub-network.json`, and `manifests/_shared/platform-foundry.json`.
5. Runs `terraform apply`.
6. Seeds the downstream repository with the bootstrapped IaC, examples, workflow, and sanitized workload parameters.

The generated variables include the hub VNet and Private DNS data, optional subnet flags from `main-parameters.json`, central Foundry account metadata, and shared capability-host dependency IDs.

## Usage

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

Alternatively, trigger the **Onboard AI Landing Zone** workflow in `.github/workflows/onboard.yml` with a manifest folder. The workflow compiles the spoke Bicep module, generates `onboarding/onboard.auto.tfvars.json` from the selected manifest, `manifests/_shared/hub-network.json`, and `manifests/_shared/platform-foundry.json`, and then runs the same Terraform configuration.

## Spoke Network Template

Terraform deploys `../networking-example-remove/templates/spoke-network.json`, the compiled ARM template generated from `../networking-example-remove/modules/spoke/main.bicep`. The onboarding workflow rebuilds this file before `terraform apply`, so the spoke network deployment uses the current Bicep module source.

This repository-local network deployment is intended as a demo/example implementation. In a production platform, integrate this step with the user's existing VNet vending or IPAM process so subscription vending, address allocation, hub peering, DNS links, route tables, security policy, and approvals remain governed by the central networking platform. Keep the downstream contract stable by publishing the vendored VNet/subnet IDs to the same GitHub Actions variables consumed by the bootstrapped workload repository.

The demo template always creates the private endpoints subnet. It creates the AI Foundry Agent Service delegated subnet when `DEPLOY_AI_FOUNDRY_AGENT_SUBNET` is `true`, and the Container Apps delegated subnet when `DEPLOY_CONTAINER_APPS_SUBNET` is `true`.

If the Bicep module changes and you want to refresh the compiled template locally, run this from the repository root:

```powershell
az bicep build --file .\networking-example-remove\modules\spoke\main.bicep --outfile .\networking-example-remove\templates\spoke-network.json
```

Review the generated diff before committing it. When the `networking-example-remove` module is replaced in the future, keep the Terraform contract stable by updating the corresponding variable mapping if needed.

## Outputs

Run `terraform output` to inspect provisioning details, including repository identifiers, spoke VNet IDs, subnet IDs, peering names, the number of linked Private DNS zones, and the central Microsoft Foundry project metadata.

The downstream GitHub repository receives Actions variables for Azure identity and deployment context, spoke network IDs, Private DNS zone IDs, central Foundry account/project metadata, and the shared capability-host dependency bundle. The onboarding workflow also writes `AZURE_TENANT_ID` and `RESOURCE_GROUP_NAME` after Terraform completes.
