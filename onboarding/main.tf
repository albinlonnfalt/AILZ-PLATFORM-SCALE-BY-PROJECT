terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}


provider "azurerm" {
  features {}
  subscription_id = var.ONBOARD_SUB_ID
}

provider "azapi" {
  subscription_id = var.ONBOARD_SUB_ID
}

provider "azurerm" {
  alias = "central_foundry"
  features {}
  subscription_id = var.CENTRAL_FOUNDRY_SUBSCRIPTION_ID
}

provider "azapi" {
  alias           = "central_foundry"
  subscription_id = var.CENTRAL_FOUNDRY_SUBSCRIPTION_ID
}

provider "github" {
  owner = var.GITHUB_ORG
}

//--
// Subscription and Resource Group
//--

// Since I can not create new subscriptions, I will simple create a resource group in the existing subscription for now. This is not recommended, scaling on subscription is better, but this is a workaround for now.
// This should be your current subscription vending
resource "azurerm_resource_group" "ailz_rg" {
  name     = local.resource_group_name
  location = var.LOCATION
}

locals {
  spoke_private_dns_zone_ids = merge({
    cognitiveServices = ""
    openAi            = ""
    aiServices        = ""
    blob              = ""
    file              = ""
    cosmos            = ""
    search            = ""
    keyVault          = ""
    acr               = ""
    appConfig         = ""
    containerApps     = ""
  }, var.HUB_PRIVATE_DNS_ZONE_IDS)

  resource_group_name  = "rg-az-ailz-${var.APPID}"
  spoke_base_name      = coalesce(var.SPOKE_BASE_NAME, "az-ailz-${var.APPID}")
  spoke_vnet_name      = "vnet-${local.spoke_base_name}-spoke"
  hub_subscription_id  = coalesce(var.HUB_SUBSCRIPTION_ID, var.ONBOARD_SUB_ID)
  spoke_address_space  = var.DEPLOY_SPOKE_NETWORK ? data.external.spoke_address_allocation[0].result : {}
  spoke_network_prefix = try(local.spoke_address_space.vnetAddressPrefix, var.SPOKE_VNET_ADDRESS_PREFIXES[0])

  effective_spoke_vnet_address_prefixes     = [local.spoke_network_prefix]
  effective_private_endpoints_subnet_prefix = try(local.spoke_address_space.privateEndpointsSubnetPrefix, var.SPOKE_PRIVATE_ENDPOINTS_SUBNET_PREFIX)
  effective_ai_foundry_agent_subnet_prefix  = try(local.spoke_address_space.aiFoundryAgentSubnetPrefix, var.SPOKE_AI_FOUNDRY_AGENT_SUBNET_PREFIX)
  effective_container_apps_subnet_prefix    = try(local.spoke_address_space.containerAppsSubnetPrefix, var.SPOKE_CONTAINER_APPS_SUBNET_PREFIX)
  spoke_network_outputs                     = var.DEPLOY_SPOKE_NETWORK ? azapi_resource.spoke_network[0].output.properties.outputs : {}
}

data "external" "spoke_address_allocation" {
  count = var.DEPLOY_SPOKE_NETWORK ? 1 : 0

  // Demo spoke address allocation. In a real platform, integrate this with the user's existing VNet vending/IPAM process
  // and pass the vendored VNet/subnet prefixes into this module rather than relying on repository-local allocation logic.
  program = ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "${path.module}/../networking-example-remove/scripts/allocate-spoke-address-space.ps1"]

  query = {
    hubSubscriptionId       = local.hub_subscription_id
    hubResourceGroupName    = var.HUB_RESOURCE_GROUP_NAME
    hubVnetName             = var.HUB_VNET_NAME
    hubVnetId               = var.HUB_VNET_ID
    targetSubscriptionId    = var.ONBOARD_SUB_ID
    targetResourceGroupName = local.resource_group_name
    targetVnetName          = local.spoke_vnet_name
    allocationPoolPrefix    = var.SPOKE_ADDRESS_POOL_PREFIX
    spokePrefixLength       = tostring(var.SPOKE_PREFIX_LENGTH)
  }
}

//--
// UAMI
//--

// Creating a user-assigned managed identity for infrastructure deployments from GitHub Actions.

resource "azurerm_user_assigned_identity" "ai-lz-uami" {
  name                = "uami-az-ailz-${var.APPID}-infra-deploy"
  location            = azurerm_resource_group.ailz_rg.location
  resource_group_name = azurerm_resource_group.ailz_rg.name
}

// Role assignment to the managed identity.

resource "azurerm_role_assignment" "ai-lz-uami-role-assignment" {
  scope                            = "/subscriptions/${var.ONBOARD_SUB_ID}"
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_user_assigned_identity.ai-lz-uami.principal_id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_user_assigned_identity.ai-lz-uami
  ]
}

resource "azurerm_role_assignment" "ai-lz-uami-rbac-administrator" {
  scope                            = "/subscriptions/${var.ONBOARD_SUB_ID}"
  role_definition_name             = "Role Based Access Control Administrator"
  principal_id                     = azurerm_user_assigned_identity.ai-lz-uami.principal_id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_user_assigned_identity.ai-lz-uami
  ]
}

//--
// Central Microsoft Foundry Project
//--

module "central_foundry_project" {
  source = "./modules/central-foundry-project"

  providers = {
    azurerm = azurerm.central_foundry
    azapi   = azapi.central_foundry
  }

  appid    = var.APPID
  location = var.LOCATION

  spoke_tags        = var.SPOKE_TAGS
  uami_principal_id = azurerm_user_assigned_identity.ai-lz-uami.principal_id

  central_foundry_subscription_id                = var.CENTRAL_FOUNDRY_SUBSCRIPTION_ID
  central_foundry_resource_group_name            = var.CENTRAL_FOUNDRY_RESOURCE_GROUP_NAME
  central_foundry_account_name                   = var.CENTRAL_FOUNDRY_ACCOUNT_NAME
  central_foundry_account_id                     = var.CENTRAL_FOUNDRY_ACCOUNT_ID
  central_foundry_account_endpoint               = var.CENTRAL_FOUNDRY_ACCOUNT_ENDPOINT
  central_foundry_project_name_prefix            = var.CENTRAL_FOUNDRY_PROJECT_NAME_PREFIX
  central_foundry_create_project_capability_host = var.CENTRAL_FOUNDRY_CREATE_PROJECT_CAPABILITY_HOST

  central_foundry_capability_host_storage_account_name = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_NAME
  central_foundry_capability_host_storage_account_id   = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_ID
  central_foundry_capability_host_cosmos_db_name       = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_NAME
  central_foundry_capability_host_cosmos_db_id         = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_ID
  central_foundry_capability_host_search_service_name  = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_NAME
  central_foundry_capability_host_search_service_id    = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_ID
}

//
// Github
//

// Create a GitHub Repository

resource "github_repository" "ailz-repo" {
  name        = "az-ailz-${var.APPID}"
  description = "Repository for Azure AI Landing Zone - ${var.APPID}"
  auto_init   = true
  visibility  = "private"
}


// Create a federated identity credential for GitHub Actions

resource "azurerm_federated_identity_credential" "fc_ai-lz-uami_github" {
  name                = "fc-az-ailz-${var.APPID}-main"
  resource_group_name = azurerm_resource_group.ailz_rg.name
  parent_id           = azurerm_user_assigned_identity.ai-lz-uami.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.GITHUB_ORG}/az-ailz-${var.APPID}:ref:refs/heads/main"
}

// Add variables to GitHub Actions
//TODO: Add more variables as needed

resource "github_actions_variable" "clientid" {
  repository    = github_repository.ailz-repo.name
  variable_name = "CLIENTID"
  value         = azurerm_user_assigned_identity.ai-lz-uami.client_id
}

resource "github_actions_variable" "appname" {
  repository    = github_repository.ailz-repo.name
  variable_name = "NAME"
  value         = var.APPID
}

resource "github_actions_variable" "foundry_project_id" {
  repository    = github_repository.ailz-repo.name
  variable_name = "FOUNDRY_PROJECT_ID"
  value         = module.central_foundry_project.project_id
}

resource "github_actions_variable" "azuresubscriptionid" {
  repository    = github_repository.ailz-repo.name
  variable_name = "AZURE_SUBSCRIPTION_ID"
  value         = var.ONBOARD_SUB_ID
}

resource "github_actions_variable" "spoke_vnet_id" {
  repository    = github_repository.ailz-repo.name
  variable_name = "SPOKE_VNET_ID"
  value         = try(local.spoke_network_outputs.spokeVnetId.value, "")
}

resource "github_actions_variable" "spoke_private_endpoints_subnet_id" {
  repository    = github_repository.ailz-repo.name
  variable_name = "SPOKE_PRIVATE_ENDPOINTS_SUBNET_ID"
  value         = try(local.spoke_network_outputs.privateEndpointsSubnetId.value, "")
}

resource "github_actions_variable" "spoke_ai_foundry_agent_subnet_id" {
  count = var.DEPLOY_AI_FOUNDRY_AGENT_SUBNET ? 1 : 0

  repository    = github_repository.ailz-repo.name
  variable_name = "SPOKE_AI_FOUNDRY_AGENT_SUBNET_ID"
  value         = try(local.spoke_network_outputs.aiFoundryAgentSubnetId.value, "")
}

resource "github_actions_variable" "spoke_container_apps_subnet_id" {
  count = var.DEPLOY_CONTAINER_APPS_SUBNET ? 1 : 0

  repository    = github_repository.ailz-repo.name
  variable_name = "SPOKE_CONTAINER_APPS_SUBNET_ID"
  value         = try(local.spoke_network_outputs.containerAppsSubnetId.value, "")
}

resource "github_actions_variable" "private_dns_zone_ids_json" {
  repository    = github_repository.ailz-repo.name
  variable_name = "PRIVATE_DNS_ZONE_IDS_JSON"
  value         = jsonencode(local.spoke_private_dns_zone_ids)
}

resource "github_actions_variable" "central_foundry_account_name" {
  repository    = github_repository.ailz-repo.name
  variable_name = "CENTRAL_FOUNDRY_ACCOUNT_NAME"
  value         = var.CENTRAL_FOUNDRY_ACCOUNT_NAME
}

resource "github_actions_variable" "central_foundry_account_id" {
  repository    = github_repository.ailz-repo.name
  variable_name = "CENTRAL_FOUNDRY_ACCOUNT_ID"
  value         = module.central_foundry_project.account_id
}

resource "github_actions_variable" "azure_ai_project_name" {
  repository    = github_repository.ailz-repo.name
  variable_name = "AZURE_AI_PROJECT_NAME"
  value         = module.central_foundry_project.project_name
}

resource "github_actions_variable" "azure_ai_project_resource_id" {
  repository    = github_repository.ailz-repo.name
  variable_name = "AZURE_AI_PROJECT_RESOURCE_ID"
  value         = module.central_foundry_project.project_id
}

resource "github_actions_variable" "azure_ai_project_endpoint" {
  repository    = github_repository.ailz-repo.name
  variable_name = "AZURE_AI_PROJECT_ENDPOINT"
  value         = module.central_foundry_project.project_endpoint
}

resource "github_actions_variable" "central_foundry_capability_host_json" {
  repository    = github_repository.ailz-repo.name
  variable_name = "CENTRAL_FOUNDRY_CAPABILITY_HOST_JSON"
  value = jsonencode({
    storageAccountName = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_NAME
    storageAccountId   = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_ID
    cosmosDbName       = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_NAME
    cosmosDbId         = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_ID
    searchServiceName  = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_NAME
    searchServiceId    = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_ID
    keyVaultName       = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_KEY_VAULT_NAME
    keyVaultId         = var.CENTRAL_FOUNDRY_CAPABILITY_HOST_KEY_VAULT_ID
  })
}

//
// Assign permissions to the GitHub repo
//

// TODO: Assign the appropriate permissions for the GitHub repository to the team or users that need access.

// --
// Network
// --

// Demo spoke network deployment from the ARM template compiled from networking-example-remove/modules/spoke/main.bicep.
// Production platforms should integrate this step with the user's existing VNet vending process so subscription vending,
// IPAM, network policy, peering, DNS, routing, and approval controls remain owned by the central networking platform.
// Keep the downstream GitHub variable contract stable by publishing the vendored VNet and subnet IDs to the same variables.
// The onboarding workflow builds the Bicep module before terraform apply so Terraform uses the current module source.

resource "azapi_resource" "spoke_network" {
  count     = var.DEPLOY_SPOKE_NETWORK ? 1 : 0
  type      = "Microsoft.Resources/deployments@2022-09-01"
  name      = "spoke-network-${var.APPID}"
  parent_id = azurerm_resource_group.ailz_rg.id

  body = {
    properties = {
      mode     = "Incremental"
      template = jsondecode(file("${path.module}/${var.SPOKE_NETWORK_TEMPLATE_FILE}"))
      parameters = {
        baseName = {
          value = local.spoke_base_name
        }
        location = {
          value = azurerm_resource_group.ailz_rg.location
        }
        tags = {
          value = merge({
            workload = "ai-landing-zone"
            appid    = var.APPID
            role     = "spoke-network"
          }, var.SPOKE_TAGS)
        }
        spokeVnetAddressPrefixes = {
          value = local.effective_spoke_vnet_address_prefixes
        }
        privateEndpointsSubnetPrefix = {
          value = local.effective_private_endpoints_subnet_prefix
        }
        deployAiFoundryAgentSubnet = {
          value = var.DEPLOY_AI_FOUNDRY_AGENT_SUBNET
        }
        aiFoundryAgentSubnetPrefix = {
          value = local.effective_ai_foundry_agent_subnet_prefix
        }
        deployContainerAppsSubnet = {
          value = var.DEPLOY_CONTAINER_APPS_SUBNET
        }
        containerAppsSubnetPrefix = {
          value = local.effective_container_apps_subnet_prefix
        }
        hubSubscriptionId = {
          value = local.hub_subscription_id
        }
        hubResourceGroupName = {
          value = var.HUB_RESOURCE_GROUP_NAME
        }
        hubPrivateDnsResourceGroupName = {
          value = coalesce(var.HUB_PRIVATE_DNS_RESOURCE_GROUP_NAME, var.HUB_RESOURCE_GROUP_NAME)
        }
        hubVnetName = {
          value = var.HUB_VNET_NAME
        }
        hubVnetId = {
          value = var.HUB_VNET_ID
        }
        privateDnsZoneIds = {
          value = local.spoke_private_dns_zone_ids
        }
        allowForwardedTraffic = {
          value = var.SPOKE_ALLOW_FORWARDED_TRAFFIC
        }
        useRemoteGateways = {
          value = var.SPOKE_USE_REMOTE_GATEWAYS
        }
        allowGatewayTransit = {
          value = var.HUB_ALLOW_GATEWAY_TRANSIT
        }
        privateDnsRegistrationEnabled = {
          value = var.SPOKE_PRIVATE_DNS_REGISTRATION_ENABLED
        }
      }
    }
  }

  response_export_values    = ["properties.outputs"]
  schema_validation_enabled = false

  lifecycle {
    precondition {
      condition     = trimspace(var.HUB_RESOURCE_GROUP_NAME) != "" && trimspace(var.HUB_VNET_NAME) != "" && trimspace(var.HUB_VNET_ID) != ""
      error_message = "Set HUB_RESOURCE_GROUP_NAME, HUB_VNET_NAME, and HUB_VNET_ID when DEPLOY_SPOKE_NETWORK is true."
    }
  }
}
