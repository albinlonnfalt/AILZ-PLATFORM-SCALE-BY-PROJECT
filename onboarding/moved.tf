moved {
  from = azapi_resource.central_foundry_project
  to   = module.central_foundry_project.azapi_resource.central_foundry_project
}

moved {
  from = azurerm_role_assignment.uami-central-foundry-ai-user
  to   = module.central_foundry_project.azurerm_role_assignment.uami-central-foundry-ai-user
}

moved {
  from = azurerm_role_assignment.uami-central-foundry-cognitive-services-user
  to   = module.central_foundry_project.azurerm_role_assignment.uami-central-foundry-cognitive-services-user
}

moved {
  from = azurerm_role_assignment.uami-central-foundry-openai-user
  to   = module.central_foundry_project.azurerm_role_assignment.uami-central-foundry-openai-user
}

moved {
  from = azurerm_role_assignment.uami-central-foundry-project-manager
  to   = module.central_foundry_project.azurerm_role_assignment.uami-central-foundry-project-manager
}

moved {
  from = azurerm_role_assignment.project-storage-blob-contributor
  to   = module.central_foundry_project.azurerm_role_assignment.project-storage-blob-contributor
}

moved {
  from = azurerm_role_assignment.project-search-index-data-contributor
  to   = module.central_foundry_project.azurerm_role_assignment.project-search-index-data-contributor
}

moved {
  from = azurerm_role_assignment.project-search-service-contributor
  to   = module.central_foundry_project.azurerm_role_assignment.project-search-service-contributor
}

moved {
  from = azurerm_role_assignment.project-cosmos-operator
  to   = module.central_foundry_project.azurerm_role_assignment.project-cosmos-operator
}

moved {
  from = azapi_resource.project-cosmos-data-contributor
  to   = module.central_foundry_project.azapi_resource.project-cosmos-data-contributor
}

moved {
  from = azapi_resource.central_foundry_project_cosmos_connection
  to   = module.central_foundry_project.azapi_resource.central_foundry_project_cosmos_connection
}

moved {
  from = azapi_resource.central_foundry_project_storage_connection
  to   = module.central_foundry_project.azapi_resource.central_foundry_project_storage_connection
}

moved {
  from = azapi_resource.central_foundry_project_search_connection
  to   = module.central_foundry_project.azapi_resource.central_foundry_project_search_connection
}

moved {
  from = azapi_resource.central_foundry_project_capability_host
  to   = module.central_foundry_project.azapi_resource.central_foundry_project_capability_host
}
