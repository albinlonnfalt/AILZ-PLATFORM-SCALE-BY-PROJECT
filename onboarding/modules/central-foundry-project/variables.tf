variable "appid" {
  description = "The application ID used to derive the Foundry project name."
  type        = string
}

variable "location" {
  description = "Azure region for the central Microsoft Foundry project metadata."
  type        = string
}

variable "spoke_tags" {
  description = "Additional tags applied to the central Microsoft Foundry project."
  type        = map(string)
  default     = {}
}

variable "uami_principal_id" {
  description = "Principal ID of the user-assigned managed identity used by GitHub Actions."
  type        = string
}

variable "central_foundry_subscription_id" {
  description = "Subscription ID that contains the central Microsoft Foundry account."
  type        = string

  validation {
    condition     = trimspace(var.central_foundry_subscription_id) != ""
    error_message = "central_foundry_subscription_id must be set explicitly. onboard_subscription_id is not used as a fallback."
  }
}

variable "central_foundry_resource_group_name" {
  description = "Resource group name that contains the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "central_foundry_account_name" {
  description = "Name of the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "central_foundry_account_id" {
  description = "Resource ID of the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "central_foundry_account_endpoint" {
  description = "Endpoint URI for the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "central_foundry_project_name_prefix" {
  description = "Prefix used for APPID-derived project names in the central Microsoft Foundry account."
  type        = string
  default     = "ailz"
}

variable "central_foundry_create_project_capability_host" {
  description = "Create a project-level capability host that uses the central shared capability-host dependencies."
  type        = bool
  default     = true
}

variable "central_foundry_capability_host_storage_account_name" {
  description = "Name of the central shared Storage Account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "central_foundry_capability_host_storage_account_id" {
  description = "Resource ID of the central shared Storage Account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "central_foundry_capability_host_cosmos_db_name" {
  description = "Name of the central shared Cosmos DB account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "central_foundry_capability_host_cosmos_db_id" {
  description = "Resource ID of the central shared Cosmos DB account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "central_foundry_capability_host_search_service_name" {
  description = "Name of the central shared AI Search service used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "central_foundry_capability_host_search_service_id" {
  description = "Resource ID of the central shared AI Search service used by Foundry project capability hosts."
  type        = string
  default     = ""
}
