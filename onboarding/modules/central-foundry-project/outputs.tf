locals {
  metadata = {
    account_subscription_id = local.central_foundry_subscription_id
    account_resource_group  = var.central_foundry_resource_group_name
    account_name            = var.central_foundry_account_name
    account_id              = local.central_foundry_account_id
    account_endpoint        = var.central_foundry_account_endpoint
    project_name            = local.central_foundry_project_name
    project_id              = azapi_resource.central_foundry_project.id
    project_endpoint        = local.central_foundry_project_endpoint
    project_principal_id    = azapi_resource.central_foundry_project.output.identity.principalId
    capability_host_enabled = local.central_foundry_capability_host_enabled
    capability_host_name    = local.central_foundry_capability_host_name
  }
}

output "metadata" {
  description = "Metadata for the APPID-derived project created in the central Microsoft Foundry account."
  value       = local.metadata
}

output "account_id" {
  description = "Resource ID of the central Microsoft Foundry account."
  value       = local.metadata.account_id
}

output "project_name" {
  description = "Name of the APPID-derived project created in the central Microsoft Foundry account."
  value       = local.metadata.project_name
}

output "project_id" {
  description = "Resource ID of the APPID-derived project created in the central Microsoft Foundry account."
  value       = local.metadata.project_id
}

output "project_endpoint" {
  description = "Endpoint URI for the APPID-derived project in the central Microsoft Foundry account."
  value       = local.metadata.project_endpoint
}

output "project_principal_id" {
  description = "Principal ID of the APPID-derived central Microsoft Foundry project identity."
  value       = local.metadata.project_principal_id
}

output "capability_host_enabled" {
  description = "Whether the project-level capability host is enabled for this project."
  value       = local.metadata.capability_host_enabled
}

output "capability_host_name" {
  description = "Name of the project-level capability host."
  value       = local.metadata.capability_host_name
}
