targetScope = 'resourceGroup'

import * as const from '../constants/constants.bicep'

// Optional workload/platform resources deployed into the workload spoke.
// Standalone GenAI PaaS resources are not connected to central Microsoft Foundry.

@description('Base name used for resource naming.')
param baseName string

@description('Application identifier used to derive globally unique workload identity names.')
param appName string

@description('Azure region for the deployment.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

// What to deploy

@description('Deploy a standalone Cosmos DB account with private endpoint.')
param deployCosmosDb bool = false

@description('Deploy a standalone AI Search service with private endpoint.')
param deployAiSearch bool = false

@description('Deploy a standalone Storage account with private endpoint.')
param deployStorage bool = false

@description('Deploy a standalone Key Vault with private endpoint.')
param deployKeyVault bool = false

@description('Deploy a standalone Container Registry with private endpoint.')
param deployAcr bool = false

@description('Deploy a standalone App Configuration store with private endpoint.')
param deployAppConfig bool = false

@description('Deploy the Container App Environment with private endpoint.')
param deployContainerApps bool = false

// Networking

@description('Resource ID of the subnet for private endpoints.')
param privateEndpointSubnetId string

@description('Resource ID of the Container Apps infrastructure subnet. Required when deployContainerApps is true.')
param containerAppsSubnetId string = ''

// DNS zone IDs (passed in from the private-dns-zones module)

@description('DNS zone ID for Cosmos DB private endpoint.')
param cosmosDnsZoneId string = ''

@description('DNS zone ID for AI Search private endpoint.')
param searchDnsZoneId string = ''

@description('DNS zone ID for Storage (blob) private endpoint.')
param blobDnsZoneId string = ''

@description('DNS zone ID for Key Vault private endpoint.')
param keyVaultDnsZoneId string = ''

@description('DNS zone ID for ACR private endpoint.')
param acrDnsZoneId string = ''

@description('DNS zone ID for App Configuration private endpoint.')
param appConfigDnsZoneId string = ''

@description('DNS zone ID for Container Apps private endpoint.')
param containerAppsDnsZoneId string = ''

@description('When true, wire DNS zone groups into private endpoints. When false, skip DNS zone groups (Azure Policy handles DNS registration).')
param manageDnsZoneGroups bool = true

// Monitoring

@description('Application Insights connection string used by the Container Apps Environment Dapr AI configuration.')
@secure()
param appInsightsConnectionString string = ''

// Naming

var cleanBase = replace(baseName, '-', '')
// Dedicated seed for standalone optional resources.
var uniqueSuffix = substring(uniqueString(subscription().subscriptionId, resourceGroup().id, baseName, 'optional-platform'), 0, 5)
var workloadIdentityName = toLower(replace('uami-${baseName}-${appName}-workload', '_', '-'))

resource workloadManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
	name: workloadIdentityName
	location: location
	tags: tags
}

// Cosmos DB

module cosmosDb 'br/public:avm/res/document-db/database-account:0.15.1' = if (deployCosmosDb) {
	name: 'cosmos-${uniqueSuffix}'
	params: {
		name: '${const.abbrs.databases.cosmosDBDatabase}${baseName}-${uniqueSuffix}'
		location: location
		tags: tags
		defaultConsistencyLevel: 'Session'
		failoverLocations: [{ locationName: location, failoverPriority: 0, isZoneRedundant: false }]
		capabilitiesToAdd: ['EnableServerless']
		managedIdentities: {
			userAssignedResourceIds: [workloadManagedIdentity.id]
		}
		networkRestrictions: {
			publicNetworkAccess: 'Disabled'
			networkAclBypass: 'AzureServices'
		}
		disableLocalAuthentication: true
		privateEndpoints: [
			{
				subnetResourceId: privateEndpointSubnetId
				service: 'Sql'
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(cosmosDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{ privateDnsZoneResourceId: cosmosDnsZoneId }
					]
				} : null
			}
		]
	}
}

// AI Search

module search 'br/public:avm/res/search/search-service:0.11.1' = if (deployAiSearch) {
	name: 'search-${uniqueSuffix}'
	params: {
		name: '${const.abbrs.ai.aiSearch}${baseName}-${uniqueSuffix}'
		location: location
		tags: tags
		sku: 'basic'
		publicNetworkAccess: 'Disabled'
		replicaCount: 1
		partitionCount: 1
		disableLocalAuth: true
		managedIdentities: {
			userAssignedResourceIds: [workloadManagedIdentity.id]
		}
		privateEndpoints: [
			{
				subnetResourceId: privateEndpointSubnetId
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(searchDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{ privateDnsZoneResourceId: searchDnsZoneId }
					]
				} : null
			}
		]
	}
}

// Storage Account

module storageAccount 'br/public:avm/res/storage/storage-account:0.26.2' = if (deployStorage) {
	name: 'storage-${uniqueSuffix}'
	params: {
		name: '${const.abbrs.storage.storageAccount}${cleanBase}${uniqueSuffix}'
		location: location
		tags: tags
		skuName: 'Standard_LRS'
		kind: 'StorageV2'
		publicNetworkAccess: 'Disabled'
		allowSharedKeyAccess: false
		managedIdentities: {
			userAssignedResourceIds: [workloadManagedIdentity.id]
		}
		supportsHttpsTrafficOnly: true
		allowBlobPublicAccess: false
		networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
		privateEndpoints: [
			{
				subnetResourceId: privateEndpointSubnetId
				service: 'blob'
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(blobDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{ privateDnsZoneResourceId: blobDnsZoneId }
					]
				} : null
			}
		]
	}
}

// Key Vault

module keyVault 'br/public:avm/res/key-vault/vault:0.13.0' = if (deployKeyVault) {
	name: 'keyvault-${uniqueSuffix}'
	params: {
		name: '${const.abbrs.security.keyVault}${baseName}-${uniqueSuffix}'
		location: location
		tags: tags
		sku: 'standard'
		enableRbacAuthorization: true
		enableSoftDelete: true
		publicNetworkAccess: 'Disabled'
		networkAcls: { defaultAction: 'Deny', bypass: 'AzureServices' }
		privateEndpoints: [
			{
				subnetResourceId: privateEndpointSubnetId
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(keyVaultDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{ privateDnsZoneResourceId: keyVaultDnsZoneId }
					]
				} : null
			}
		]
	}
}

// Container Registry needs Premium SKU for private endpoints.

module acr 'br/public:avm/res/container-registry/registry:0.12.0' = if (deployAcr) {
	name: 'acr-${uniqueSuffix}'
	params: {
		name: '${const.abbrs.containers.containerRegistry}${cleanBase}${uniqueSuffix}'
		location: location
		tags: tags
		acrSku: 'Premium'
		publicNetworkAccess: 'Disabled'
		acrAdminUserEnabled: false
		managedIdentities: {
			userAssignedResourceIds: [workloadManagedIdentity.id]
		}
		privateEndpoints: [
			{
				subnetResourceId: privateEndpointSubnetId
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(acrDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{ privateDnsZoneResourceId: acrDnsZoneId }
					]
				} : null
			}
		]
	}
}

// App Configuration

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-05-01' = if (deployAppConfig) {
	name: '${const.abbrs.configuration.appConfiguration}${baseName}-${uniqueSuffix}'
	location: location
	tags: tags
	identity: {
		type: 'UserAssigned'
		userAssignedIdentities: {
			'${workloadManagedIdentity.id}': {}
		}
	}
	sku: { name: 'Standard' }
	properties: {
		publicNetworkAccess: 'Disabled'
		disableLocalAuth: true
	}
}

resource appConfigPe 'Microsoft.Network/privateEndpoints@2024-05-01' = if (deployAppConfig) {
	name: '${const.abbrs.networking.privateEndpoint}${const.abbrs.configuration.appConfiguration}${baseName}-${uniqueSuffix}'
	location: location
	tags: tags
	properties: {
		subnet: { id: privateEndpointSubnetId }
		privateLinkServiceConnections: [
			{
				name: 'appconfig'
				properties: {
					privateLinkServiceId: appConfig.id
					groupIds: ['configurationStores']
				}
			}
		]
	}
}

resource appConfigPeDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (deployAppConfig && manageDnsZoneGroups && !empty(appConfigDnsZoneId)) {
	parent: appConfigPe
	name: 'default'
	properties: {
		privateDnsZoneConfigs: [
			{
				name: 'appconfig'
				properties: { privateDnsZoneId: appConfigDnsZoneId }
			}
		]
	}
}

// Container App Environment

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = if (deployContainerApps) {
	name: '${const.abbrs.containers.containerAppsEnvironment}${baseName}'
	location: location
	tags: tags
	properties: {
		appLogsConfiguration: {
			destination: null
		}
		daprAIConnectionString: appInsightsConnectionString
		vnetConfiguration: {
			infrastructureSubnetId: containerAppsSubnetId
			internal: true
		}
		zoneRedundant: false
	}
}

module containerEnvPe './networking/private-endpoint.bicep' = if (deployContainerApps) {
	name: 'pe-cae-deployment'
	params: {
		name: '${const.abbrs.networking.privateEndpoint}${const.abbrs.containers.containerAppsEnvironment}${baseName}'
		location: location
		tags: tags
		subnetResourceId: privateEndpointSubnetId
		privateLinkServiceConnections: [
			{
				name: 'caeConnection'
				properties: {
					privateLinkServiceId: containerEnv.id
					groupIds: ['managedEnvironments']
				}
			}
		]
		privateDnsZoneGroup: manageDnsZoneGroups && !empty(containerAppsDnsZoneId) ? {
			name: 'caeDnsZoneGroup'
			privateDnsZoneGroupConfigs: [
				{
					name: 'caeRecord'
					privateDnsZoneResourceId: containerAppsDnsZoneId
				}
			]
		} : {}
	}
}

// Outputs

output cosmosDbId string = deployCosmosDb ? cosmosDb!.outputs.resourceId : ''
output cosmosDbName string = deployCosmosDb ? cosmosDb!.outputs.name : ''
output searchServiceId string = deployAiSearch ? search!.outputs.resourceId : ''
output searchServiceName string = deployAiSearch ? search!.outputs.name : ''
output storageAccountId string = deployStorage ? storageAccount!.outputs.resourceId : ''
output storageAccountName string = deployStorage ? storageAccount!.outputs.name : ''
output keyVaultId string = deployKeyVault ? keyVault!.outputs.resourceId : ''
output keyVaultName string = deployKeyVault ? keyVault!.outputs.name : ''
output acrId string = deployAcr ? acr!.outputs.resourceId : ''
output acrName string = deployAcr ? acr!.outputs.name : ''
output acrLoginServer string = deployAcr ? acr!.outputs.loginServer : ''
output appConfigId string = deployAppConfig ? appConfig.id : ''
output appConfigName string = deployAppConfig ? appConfig.name : ''
output caeId string = deployContainerApps ? containerEnv.id : ''
output caeName string = deployContainerApps ? containerEnv.name : ''
output workloadManagedIdentityId string = workloadManagedIdentity.id
output workloadManagedIdentityClientId string = workloadManagedIdentity.properties.clientId
output workloadManagedIdentityPrincipalId string = workloadManagedIdentity.properties.principalId
