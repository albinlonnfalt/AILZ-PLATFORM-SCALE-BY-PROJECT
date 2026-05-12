targetScope = 'resourceGroup'

import * as const from 'constants/constants.bicep'

type PrivateDnsZoneIds = {
	cognitiveServices: string
	openAi: string
	aiServices: string
	blob: string
	file: string
	cosmos: string
	search: string
	keyVault: string
	acr: string
	appConfig: string
	containerApps: string
}

// General

@description('Friendly base name used to derive optional workload resource names.')
param baseName string

@description('Application identifier used to derive workload identity names.')
param appName string = ''

@description('Azure region for the deployment.')
param location string = resourceGroup().location

@description('Tags applied to all created resources.')
param tags object = {}

// Existing spoke network

@description('Resource ID of the spoke VNet created by onboarding Terraform.')
param existingVnetId string

@description('Resource ID of the subnet used for private endpoints. This subnet is created by onboarding Terraform.')
param privateEndpointSubnetId string

@description('Resource ID of the Container Apps infrastructure subnet created by onboarding Terraform. Required when deployContainerApps is true.')
param containerAppsSubnetId string = ''

@description('Deploy the Container App Environment and container apps defined in containerAppsList.')
param deployContainerApps bool = true

// Optional platform resources
// Standalone workload resources are not connected to AI Foundry.
// Central Foundry capability-host dependencies are deployed by platform-foundation.

@description('Deploy a Container Registry with private endpoint.')
param deployAcr bool = true

@description('Deploy an App Configuration store with private endpoint.')
param deployAppConfig bool = true

@description('Deploy a standalone Cosmos DB account with private endpoint.')
param deployGenaiCosmos bool = true

@description('Deploy a standalone AI Search service with private endpoint.')
param deployGenaiSearch bool = true

@description('Deploy a standalone Storage account with private endpoint.')
param deployGenaiStorage bool = true

@description('Deploy a Key Vault with private endpoint.')
param deployGenaiKeyVault bool = true

// DNS management

@description('When true, wire DNS zone groups into private endpoints by using privateDnsZoneIds. Set to false when Azure Policy or another platform process handles DNS registration.')
param manageDnsZoneGroups bool = true

@description('Existing hub-owned Private DNS zone IDs keyed by cognitiveServices, openAi, aiServices, blob, file, cosmos, search, keyVault, acr, appConfig, and containerApps. Empty values skip DNS zone groups for that service.')
param privateDnsZoneIds PrivateDnsZoneIds = {
	cognitiveServices: ''
	openAi: ''
	aiServices: ''
	blob: ''
	file: ''
	cosmos: ''
	search: ''
	keyVault: ''
	acr: ''
	appConfig: ''
	containerApps: ''
}

@description('Principal ID of the deployer to assign RBAC roles on optional workload resources. Leave empty to skip.')
param deployerPrincipalId string = ''

@description('Principal type of the deployer (User, Group, or ServicePrincipal).')
param deployerPrincipalType string = 'User'

@description('Resource ID of the central Microsoft Foundry project. Leave empty to skip Foundry project RBAC for the workload identity.')
param foundryProjectId string = ''

// Optional platform resources — standalone workload services and app hosting

var _anyOptionalPlatformResources = deployGenaiCosmos || deployGenaiSearch || deployGenaiStorage || deployGenaiKeyVault || deployAcr || deployAppConfig || deployContainerApps
var _effectiveAppName = empty(appName) ? baseName : appName
var _hasFoundryProjectId = !empty(foundryProjectId)
var _foundryProjectIdSegments = split(foundryProjectId, '/')
var _foundryProjectSubscriptionId = _hasFoundryProjectId ? _foundryProjectIdSegments[2] : subscription().subscriptionId
var _foundryProjectResourceGroupName = _hasFoundryProjectId ? _foundryProjectIdSegments[4] : resourceGroup().name
var _foundryAccountName = _hasFoundryProjectId ? _foundryProjectIdSegments[8] : ''
var _foundryProjectName = _hasFoundryProjectId ? _foundryProjectIdSegments[10] : ''
var _roles = const.roles

module optionalPlatformResources './modules/optional-platform-resources.bicep' = if (_anyOptionalPlatformResources) {
	name: 'optional-platform-resources-deployment'
	params: {
		baseName: baseName
		appName: _effectiveAppName
		location: location
		tags: tags
		deployCosmosDb: deployGenaiCosmos
		deployAiSearch: deployGenaiSearch
		deployStorage: deployGenaiStorage
		deployKeyVault: deployGenaiKeyVault
		deployAcr: deployAcr
		deployAppConfig: deployAppConfig
		deployContainerApps: deployContainerApps
		privateEndpointSubnetId: privateEndpointSubnetId
		containerAppsSubnetId: deployContainerApps ? containerAppsSubnetId : ''
		manageDnsZoneGroups: manageDnsZoneGroups
		cosmosDnsZoneId: privateDnsZoneIds.cosmos
		searchDnsZoneId: privateDnsZoneIds.search
		blobDnsZoneId: privateDnsZoneIds.blob
		keyVaultDnsZoneId: privateDnsZoneIds.keyVault
		acrDnsZoneId: privateDnsZoneIds.acr
		appConfigDnsZoneId: privateDnsZoneIds.appConfig
		containerAppsDnsZoneId: privateDnsZoneIds.containerApps
		appInsightsConnectionString: deployContainerApps ? monitoring.outputs.appInsightsConnectionString : ''
	}
}

// Monitoring (Log Analytics + App Insights)

module monitoring './modules/monitoring/monitoring.bicep' = {
	name: 'monitoring-deployment'
	params: {
		baseName: baseName
		location: location
		tags: tags
	}
}
// ---- RBAC ----

module developerRbac './modules/rbac-developer.bicep' = if (!empty(deployerPrincipalId)) {
	name: 'rbac-developer'
	params: {
		developerPrincipalId: deployerPrincipalId
		developerPrincipalType: deployerPrincipalType
		assignCosmosDbRoles: deployGenaiCosmos
		assignAiSearchRoles: deployGenaiSearch
		assignStorageRoles: deployGenaiStorage
		assignKeyVaultRoles: deployGenaiKeyVault
		assignAcrRoles: deployAcr
		assignAppConfigRoles: deployAppConfig
		cosmosDbAccountName: deployGenaiCosmos ? optionalPlatformResources!.outputs.cosmosDbName : ''
		searchServiceName: deployGenaiSearch ? optionalPlatformResources!.outputs.searchServiceName : ''
		storageAccountName: deployGenaiStorage ? optionalPlatformResources!.outputs.storageAccountName : ''
		keyVaultName: deployGenaiKeyVault ? optionalPlatformResources!.outputs.keyVaultName : ''
		acrName: deployAcr ? optionalPlatformResources!.outputs.acrName : ''
		appConfigName: deployAppConfig ? optionalPlatformResources!.outputs.appConfigName : ''
	}
}

module workloadRbac './modules/rbac-workload.bicep' = if (_anyOptionalPlatformResources) {
	name: 'rbac-workload'
	params: {
		workloadPrincipalId: optionalPlatformResources!.outputs.workloadManagedIdentityPrincipalId
		assignCosmosDbRoles: deployGenaiCosmos
		assignAiSearchRoles: deployGenaiSearch
		assignStorageRoles: deployGenaiStorage
		assignKeyVaultRoles: deployGenaiKeyVault
		assignAcrRoles: deployAcr
		assignAppConfigRoles: deployAppConfig
		cosmosDbAccountName: deployGenaiCosmos ? optionalPlatformResources!.outputs.cosmosDbName : ''
		searchServiceName: deployGenaiSearch ? optionalPlatformResources!.outputs.searchServiceName : ''
		storageAccountName: deployGenaiStorage ? optionalPlatformResources!.outputs.storageAccountName : ''
		keyVaultName: deployGenaiKeyVault ? optionalPlatformResources!.outputs.keyVaultName : ''
		acrName: deployAcr ? optionalPlatformResources!.outputs.acrName : ''
		appConfigName: deployAppConfig ? optionalPlatformResources!.outputs.appConfigName : ''
	}
}

// Foundry project RBAC is orchestrated here because the project lives in a central resource group or subscription,
// while rbac-workload.bicep stays scoped to workload spoke resources.
module foundryProjectRbac './modules/rbac/foundry-project-role-assignment.bicep' = if (_anyOptionalPlatformResources && _hasFoundryProjectId) {
	name: 'rbac-foundry-project-workload'
	scope: resourceGroup(_foundryProjectSubscriptionId, _foundryProjectResourceGroupName)
	params: {
		accountName: _foundryAccountName
		projectName: _foundryProjectName
		roleAssignments: [
			{
				roleDefinitionId: '/subscriptions/${_foundryProjectSubscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${_roles.AzureAIUser.guid}'
				principalId: optionalPlatformResources!.outputs.workloadManagedIdentityPrincipalId
			}
		]
	}
}

// ---- Outputs ----

// Networking
output vnetId string = existingVnetId
output vnetName string = last(split(existingVnetId, '/'))
output privateEndpointsSubnetId string = privateEndpointSubnetId
output containerAppsSubnetId string = deployContainerApps ? containerAppsSubnetId : ''

// GenAI Resources
output cosmosAccountName string = deployGenaiCosmos ? optionalPlatformResources!.outputs.cosmosDbName : ''
output searchServiceName string = deployGenaiSearch ? optionalPlatformResources!.outputs.searchServiceName : ''
output storageAccountName string = deployGenaiStorage ? optionalPlatformResources!.outputs.storageAccountName : ''
output keyVaultName string = deployGenaiKeyVault ? optionalPlatformResources!.outputs.keyVaultName : ''
output acrName string = deployAcr ? optionalPlatformResources!.outputs.acrName : ''
output appConfigName string = deployAppConfig ? optionalPlatformResources!.outputs.appConfigName : ''
output workloadManagedIdentityId string = _anyOptionalPlatformResources ? optionalPlatformResources!.outputs.workloadManagedIdentityId : ''
output workloadManagedIdentityClientId string = _anyOptionalPlatformResources ? optionalPlatformResources!.outputs.workloadManagedIdentityClientId : ''
output workloadManagedIdentityPrincipalId string = _anyOptionalPlatformResources ? optionalPlatformResources!.outputs.workloadManagedIdentityPrincipalId : ''

// Monitoring
output appInsightsName string = monitoring.outputs.appInsightsName
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

// Container Apps
output caeName string = deployContainerApps ? optionalPlatformResources!.outputs.caeName : ''
output caeId string = deployContainerApps ? optionalPlatformResources!.outputs.caeId : ''
