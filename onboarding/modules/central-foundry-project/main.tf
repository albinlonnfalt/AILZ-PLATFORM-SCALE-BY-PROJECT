locals {
  central_foundry_subscription_id         = var.central_foundry_subscription_id
  central_foundry_account_id              = trimspace(var.central_foundry_account_id) != "" ? var.central_foundry_account_id : "/subscriptions/${local.central_foundry_subscription_id}/resourceGroups/${var.central_foundry_resource_group_name}/providers/Microsoft.CognitiveServices/accounts/${var.central_foundry_account_name}"
  central_foundry_project_name            = lower(replace("${var.central_foundry_project_name_prefix}-${var.appid}", "_", "-"))
  central_foundry_project_endpoint        = trimspace(var.central_foundry_account_endpoint) != "" ? "${trimsuffix(var.central_foundry_account_endpoint, "/")}/api/projects/${local.central_foundry_project_name}" : "https://${var.central_foundry_account_name}.services.ai.azure.com/api/projects/${local.central_foundry_project_name}"
  central_foundry_capability_host_enabled = var.central_foundry_create_project_capability_host && trimspace(var.central_foundry_capability_host_storage_account_id) != "" && trimspace(var.central_foundry_capability_host_cosmos_db_id) != "" && trimspace(var.central_foundry_capability_host_search_service_id) != ""
  central_foundry_cosmos_connection_name  = "cosmos-${local.central_foundry_project_name}"
  central_foundry_storage_connection_name = "storage-${local.central_foundry_project_name}"
  central_foundry_search_connection_name  = "search-${local.central_foundry_project_name}"
  central_foundry_capability_host_name    = "chagent${replace(local.central_foundry_project_name, "-", "")}"
}

resource "azapi_resource" "central_foundry_project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-07-01-preview"
  name      = local.central_foundry_project_name
  parent_id = local.central_foundry_account_id
  location  = var.location

  body = {
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      displayName = "AI Landing Zone ${var.appid}"
      description = "Central Microsoft Foundry project for AI Landing Zone workload ${var.appid}."
    }
    tags = merge({
      workload = "ai-landing-zone"
      appid    = var.appid
      role     = "central-foundry-project"
    }, var.spoke_tags)
  }

  response_export_values    = ["identity.principalId", "properties"]
  schema_validation_enabled = false

  lifecycle {
    precondition {
      condition     = trimspace(var.central_foundry_account_name) != "" && trimspace(var.central_foundry_resource_group_name) != ""
      error_message = "Set CENTRAL_FOUNDRY_ACCOUNT_NAME and CENTRAL_FOUNDRY_RESOURCE_GROUP_NAME from manifests/_shared/platform-foundry.json."
    }
  }
}

resource "azurerm_role_assignment" "uami-central-foundry-ai-user" {
  scope                            = azapi_resource.central_foundry_project.id
  role_definition_name             = "Azure AI User"
  principal_id                     = var.uami_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uami-central-foundry-cognitive-services-user" {
  scope                            = azapi_resource.central_foundry_project.id
  role_definition_name             = "Cognitive Services User"
  principal_id                     = var.uami_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uami-central-foundry-openai-user" {
  scope                            = azapi_resource.central_foundry_project.id
  role_definition_name             = "Cognitive Services OpenAI User"
  principal_id                     = var.uami_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uami-central-foundry-project-manager" {
  scope                            = azapi_resource.central_foundry_project.id
  role_definition_name             = "Azure AI Project Manager"
  principal_id                     = var.uami_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "uami-central-foundry-project-rbac-administrator" {
  scope                            = azapi_resource.central_foundry_project.id
  role_definition_name             = "Role Based Access Control Administrator"
  principal_id                     = var.uami_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "project-storage-blob-contributor" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  scope                            = var.central_foundry_capability_host_storage_account_id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azapi_resource.central_foundry_project.output.identity.principalId
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "project-search-index-data-contributor" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  scope                            = var.central_foundry_capability_host_search_service_id
  role_definition_name             = "Search Index Data Contributor"
  principal_id                     = azapi_resource.central_foundry_project.output.identity.principalId
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "project-search-service-contributor" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  scope                            = var.central_foundry_capability_host_search_service_id
  role_definition_name             = "Search Service Contributor"
  principal_id                     = azapi_resource.central_foundry_project.output.identity.principalId
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "project-cosmos-operator" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  scope                            = var.central_foundry_capability_host_cosmos_db_id
  role_definition_id               = "/subscriptions/${local.central_foundry_subscription_id}/providers/Microsoft.Authorization/roleDefinitions/230815da-be43-4aae-9cb4-875f7bd000aa"
  principal_id                     = azapi_resource.central_foundry_project.output.identity.principalId
  skip_service_principal_aad_check = true
}

resource "azapi_resource" "project-cosmos-data-contributor" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15"
  name      = uuidv5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "${var.central_foundry_capability_host_cosmos_db_id}:${azapi_resource.central_foundry_project.id}:cosmos-data-contributor")
  parent_id = var.central_foundry_capability_host_cosmos_db_id

  body = {
    properties = {
      roleDefinitionId = "${var.central_foundry_capability_host_cosmos_db_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
      principalId      = azapi_resource.central_foundry_project.output.identity.principalId
      scope            = var.central_foundry_capability_host_cosmos_db_id
    }
  }

  schema_validation_enabled = false
}

resource "azapi_resource" "central_foundry_project_cosmos_connection" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-07-01-preview"
  name      = local.central_foundry_cosmos_connection_name
  parent_id = azapi_resource.central_foundry_project.id

  body = {
    properties = {
      category = "CosmosDB"
      target   = "https://${var.central_foundry_capability_host_cosmos_db_name}.documents.azure.com:443/"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.central_foundry_capability_host_cosmos_db_id
        location   = var.location
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.project-cosmos-operator,
    azapi_resource.project-cosmos-data-contributor
  ]

  schema_validation_enabled = false
}

resource "azapi_resource" "central_foundry_project_storage_connection" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-07-01-preview"
  name      = local.central_foundry_storage_connection_name
  parent_id = azapi_resource.central_foundry_project.id

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = "https://${var.central_foundry_capability_host_storage_account_name}.blob.core.windows.net/"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.central_foundry_capability_host_storage_account_id
        location   = var.location
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.project-storage-blob-contributor,
    azapi_resource.central_foundry_project_cosmos_connection
  ]

  schema_validation_enabled = false
}

resource "azapi_resource" "central_foundry_project_search_connection" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-07-01-preview"
  name      = local.central_foundry_search_connection_name
  parent_id = azapi_resource.central_foundry_project.id

  body = {
    properties = {
      category = "CognitiveSearch"
      target   = "https://${var.central_foundry_capability_host_search_service_name}.search.windows.net/"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.central_foundry_capability_host_search_service_id
        location   = var.location
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.project-search-index-data-contributor,
    azurerm_role_assignment.project-search-service-contributor,
    azapi_resource.central_foundry_project_storage_connection,
    azapi_resource.central_foundry_project_cosmos_connection
  ]

  schema_validation_enabled = false
}

resource "azapi_resource" "central_foundry_project_capability_host" {
  count = local.central_foundry_capability_host_enabled ? 1 : 0

  type      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-07-01-preview"
  name      = local.central_foundry_capability_host_name
  parent_id = azapi_resource.central_foundry_project.id

  body = {
    properties = {
      threadStorageConnections = [azapi_resource.central_foundry_project_cosmos_connection[0].name]
      vectorStoreConnections   = [azapi_resource.central_foundry_project_search_connection[0].name]
      storageConnections       = [azapi_resource.central_foundry_project_storage_connection[0].name]
    }
  }

  schema_validation_enabled = false
}
