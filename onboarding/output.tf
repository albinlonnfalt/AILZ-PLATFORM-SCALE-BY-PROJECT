locals {
  repo_default_branch = "main"

  repo_metadata = {
    id             = github_repository.ailz-repo.id
    name           = github_repository.ailz-repo.name
    full_name      = github_repository.ailz-repo.full_name
    html_url       = github_repository.ailz-repo.html_url
    http_clone_url = github_repository.ailz-repo.http_clone_url
    ssh_clone_url  = github_repository.ailz-repo.ssh_clone_url
    default_branch = local.repo_default_branch
  }

  workload_package = {
    source_relative_path = "workload"
    target_relative_path = "workload"
  }

  spoke_network_metadata = {
    spoke_vnet_address_prefix       = var.DEPLOY_SPOKE_NETWORK ? local.spoke_network_prefix : null
    private_endpoints_subnet_prefix = var.DEPLOY_SPOKE_NETWORK ? local.effective_private_endpoints_subnet_prefix : null
    ai_foundry_agent_subnet_prefix  = var.DEPLOY_SPOKE_NETWORK ? local.effective_ai_foundry_agent_subnet_prefix : null
    container_apps_subnet_prefix    = var.DEPLOY_SPOKE_NETWORK ? local.effective_container_apps_subnet_prefix : null
    spoke_vnet_id                   = try(local.spoke_network_outputs.spokeVnetId.value, null)
    spoke_vnet_name                 = try(local.spoke_network_outputs.spokeVnetName.value, null)
    private_endpoints_subnet_id     = try(local.spoke_network_outputs.privateEndpointsSubnetId.value, null)
    ai_foundry_agent_subnet_id      = try(local.spoke_network_outputs.aiFoundryAgentSubnetId.value, null)
    container_apps_subnet_id        = try(local.spoke_network_outputs.containerAppsSubnetId.value, null)
    spoke_to_hub_peering_name       = try(local.spoke_network_outputs.spokeToHubPeeringName.value, null)
    hub_to_spoke_peering_name       = try(local.spoke_network_outputs.hubToSpokePeeringName.value, null)
    linked_private_dns_zone_count   = try(local.spoke_network_outputs.linkedPrivateDnsZoneCount.value, null)
  }

  central_foundry_project_metadata = {
    account_subscription_id = module.central_foundry_project.metadata.account_subscription_id
    account_resource_group  = module.central_foundry_project.metadata.account_resource_group
    account_name            = module.central_foundry_project.metadata.account_name
    account_id              = module.central_foundry_project.metadata.account_id
    account_endpoint        = module.central_foundry_project.metadata.account_endpoint
    project_name            = module.central_foundry_project.metadata.project_name
    project_id              = module.central_foundry_project.metadata.project_id
    project_endpoint        = module.central_foundry_project.metadata.project_endpoint
    project_principal_id    = module.central_foundry_project.metadata.project_principal_id
    capability_host_enabled = module.central_foundry_project.metadata.capability_host_enabled
  }
}

output "github_repository" {
  description = "Metadata for the GitHub repository provisioned for this application."
  value       = local.repo_metadata
}

output "workload_package" {
  description = "Relative paths that identify how to copy the workload assets into the provisioned repository."
  value       = local.workload_package
}

output "repo_full_name" {
  description = "Full name (org/repo) of the provisioned repository."
  value       = local.repo_metadata.full_name
}

output "repo_default_branch" {
  description = "Default branch name for the provisioned repository."
  value       = local.repo_metadata.default_branch
}

output "spoke_network" {
  description = "Metadata for the spoke VNet deployed from the compiled ARM template snapshot."
  value       = local.spoke_network_metadata
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke VNet."
  value       = local.spoke_network_metadata.spoke_vnet_id
}

output "spoke_private_endpoints_subnet_id" {
  description = "Resource ID of the spoke private endpoints subnet."
  value       = local.spoke_network_metadata.private_endpoints_subnet_id
}

output "spoke_ai_foundry_agent_subnet_id" {
  description = "Resource ID of the spoke AI Foundry Agent Service subnet, when deployed."
  value       = local.spoke_network_metadata.ai_foundry_agent_subnet_id
}

output "spoke_container_apps_subnet_id" {
  description = "Resource ID of the spoke Container Apps subnet, when deployed."
  value       = local.spoke_network_metadata.container_apps_subnet_id
}

output "central_foundry_project" {
  description = "Metadata for the APPID-derived project created in the central Microsoft Foundry account."
  value       = local.central_foundry_project_metadata
}

output "central_foundry_project_name" {
  description = "Name of the APPID-derived project created in the central Microsoft Foundry account."
  value       = local.central_foundry_project_metadata.project_name
}

output "central_foundry_project_id" {
  description = "Resource ID of the APPID-derived project created in the central Microsoft Foundry account."
  value       = local.central_foundry_project_metadata.project_id
}

output "central_foundry_project_endpoint" {
  description = "Endpoint URI for the APPID-derived project in the central Microsoft Foundry account."
  value       = local.central_foundry_project_metadata.project_endpoint
}



