variable "ONBOARD_SUB_ID" {
  description = "The Azure Subscription ID for onboarding"
  type        = string
}

variable "LOCATION" {
  description = "Azure region for the onboarding resource group and spoke network."
  type        = string
  default     = "Sweden Central"
}

variable "APPID" {
  description = "The application ID"
  type        = string
  default     = "myapp"
}

variable "GITHUB_ORG" {
  description = "GitHub organization name"
  type        = string
  default     = "value" // Enter you org here!
}

variable "DEPLOY_SPOKE_NETWORK" {
  description = "Deploy the demo spoke VNet from the compiled ARM template generated from networking-example-remove/modules/spoke/main.bicep. Production integrations should replace or wrap this with the user's existing VNet vending process."
  type        = bool
  default     = true
}

variable "SPOKE_NETWORK_TEMPLATE_FILE" {
  description = "Path to the compiled demo spoke-network ARM template. Use only when the onboarding flow is responsible for VNet vending; otherwise integrate with the user's existing VNet vending outputs."
  type        = string
  default     = "../networking-example-remove/templates/spoke-network.json"
}

variable "SPOKE_BASE_NAME" {
  description = "Optional base name used to derive spoke network resource names. Defaults to az-ailz-<APPID>."
  type        = string
  default     = null
}

variable "SPOKE_ADDRESS_POOL_PREFIX" {
  description = "IPv4 CIDR pool used by the automatic spoke address allocator."
  type        = string
  default     = "10.0.0.0/8"
}

variable "SPOKE_PREFIX_LENGTH" {
  description = "Prefix length for each automatically allocated spoke VNet address space."
  type        = number
  default     = 16
}

variable "SPOKE_VNET_ADDRESS_PREFIXES" {
  description = "Legacy fallback address prefixes for the spoke virtual network. Normal spoke deployments use automatic allocation."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "SPOKE_PRIVATE_ENDPOINTS_SUBNET_PREFIX" {
  description = "Address prefix for the spoke private endpoints subnet."
  type        = string
  default     = "10.1.0.0/24"
}

variable "DEPLOY_AI_FOUNDRY_AGENT_SUBNET" {
  description = "Deploy the subnet delegated to Microsoft.App/environments for AI Foundry Agent Service or similar workloads."
  type        = bool
  default     = true
}

variable "SPOKE_AI_FOUNDRY_AGENT_SUBNET_PREFIX" {
  description = "Address prefix for the spoke AI Foundry Agent Service subnet."
  type        = string
  default     = "10.1.1.0/24"
}

variable "DEPLOY_CONTAINER_APPS_SUBNET" {
  description = "Deploy the subnet delegated to Microsoft.App/environments for Azure Container Apps Environment."
  type        = bool
  default     = false
}

variable "SPOKE_CONTAINER_APPS_SUBNET_PREFIX" {
  description = "Address prefix for the spoke Container Apps subnet. Use at least /23 for Container Apps Environment."
  type        = string
  default     = "10.1.6.0/23"
}

variable "SPOKE_TAGS" {
  description = "Additional tags applied to spoke network resources."
  type        = map(string)
  default     = {}
}

variable "HUB_SUBSCRIPTION_ID" {
  description = "Subscription ID that contains the hub VNet. Defaults to ONBOARD_SUB_ID when omitted."
  type        = string
  default     = null
}

variable "HUB_RESOURCE_GROUP_NAME" {
  description = "Resource group name that contains the hub VNet."
  type        = string
  default     = ""
}

variable "HUB_PRIVATE_DNS_RESOURCE_GROUP_NAME" {
  description = "Resource group name that contains hub-owned Private DNS zones. Defaults to HUB_RESOURCE_GROUP_NAME when omitted."
  type        = string
  default     = null
}

variable "HUB_VNET_NAME" {
  description = "Name of the hub VNet to peer with."
  type        = string
  default     = ""
}

variable "HUB_VNET_ID" {
  description = "Resource ID of the hub VNet to peer with."
  type        = string
  default     = ""
}

variable "HUB_PRIVATE_DNS_ZONE_IDS" {
  description = "Map of hub-owned Private DNS zone IDs keyed by cognitiveServices, openAi, aiServices, blob, file, cosmos, search, keyVault, acr, appConfig, and containerApps. Omit keys for zones that should not be linked."
  type        = map(string)
  default     = {}
}

variable "SPOKE_ALLOW_FORWARDED_TRAFFIC" {
  description = "Allow forwarded traffic across the hub/spoke peerings."
  type        = bool
  default     = false
}

variable "SPOKE_USE_REMOTE_GATEWAYS" {
  description = "Use the hub remote gateway on the spoke-to-hub peering. Requires the hub peering to allow gateway transit."
  type        = bool
  default     = false
}

variable "HUB_ALLOW_GATEWAY_TRANSIT" {
  description = "Allow the hub VNet to advertise its gateway to this spoke."
  type        = bool
  default     = false
}

variable "SPOKE_PRIVATE_DNS_REGISTRATION_ENABLED" {
  description = "Set to true only if VM autoregistration is desired in linked Private DNS zones. Private endpoint zones should normally use false."
  type        = bool
  default     = false
}

variable "CENTRAL_FOUNDRY_SUBSCRIPTION_ID" {
  description = "Subscription ID that contains the central Microsoft Foundry account in the platform/foundation spoke."
  type        = string

  validation {
    condition     = trimspace(var.CENTRAL_FOUNDRY_SUBSCRIPTION_ID) != ""
    error_message = "CENTRAL_FOUNDRY_SUBSCRIPTION_ID must be set explicitly. ONBOARD_SUB_ID is not used as a fallback."
  }
}

variable "CENTRAL_FOUNDRY_RESOURCE_GROUP_NAME" {
  description = "Resource group name that contains the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_ACCOUNT_NAME" {
  description = "Name of the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_ACCOUNT_ID" {
  description = "Resource ID of the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_ACCOUNT_ENDPOINT" {
  description = "Endpoint URI for the central Microsoft Foundry account."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_PROJECT_NAME_PREFIX" {
  description = "Prefix used for APPID-derived project names in the central Microsoft Foundry account."
  type        = string
  default     = "ailz"
}

variable "CENTRAL_FOUNDRY_CREATE_PROJECT_CAPABILITY_HOST" {
  description = "Create a project-level capability host that uses the central shared capability-host dependencies."
  type        = bool
  default     = true
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_NAME" {
  description = "Name of the central shared Storage Account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_STORAGE_ACCOUNT_ID" {
  description = "Resource ID of the central shared Storage Account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_NAME" {
  description = "Name of the central shared Cosmos DB account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_COSMOS_DB_ID" {
  description = "Resource ID of the central shared Cosmos DB account used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_NAME" {
  description = "Name of the central shared AI Search service used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_SEARCH_SERVICE_ID" {
  description = "Resource ID of the central shared AI Search service used by Foundry project capability hosts."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_KEY_VAULT_NAME" {
  description = "Name of the central shared Key Vault deployed with the capability-host dependency set."
  type        = string
  default     = ""
}

variable "CENTRAL_FOUNDRY_CAPABILITY_HOST_KEY_VAULT_ID" {
  description = "Resource ID of the central shared Key Vault deployed with the capability-host dependency set."
  type        = string
  default     = ""
}


