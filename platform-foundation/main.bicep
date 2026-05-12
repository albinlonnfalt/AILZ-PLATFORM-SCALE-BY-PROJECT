targetScope = 'resourceGroup'

type PrivateDnsZoneIds = {
	cognitiveServices: string
	openAi: string
	aiServices: string
	blob: string
	cosmos: string
	search: string
	keyVault: string
}

type SpokePrivateDnsZoneIds = {
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

@description('Friendly base name used to derive central Foundry and shared capability-host resource names.')
param baseName string = 'ailz-platform-v3'

@description('Azure region for central platform Foundry resources.')
param location string = resourceGroup().location

@description('Tags applied to all created resources.')
param tags object = {}

@description('Base name used to derive the platform/foundation spoke network resource names.')
param platformSpokeBaseName string = baseName

@description('Spoke VNet address prefixes for the platform/foundation spoke network.')
param spokeVnetAddressPrefixes array = [
	'10.1.0.0/16'
]

@description('Address prefix for the platform/foundation spoke private endpoints subnet.')
param privateEndpointsSubnetPrefix string = '10.1.0.0/24'

@description('Deploy a subnet delegated to Microsoft.App/environments for AI Foundry Agent Service or similar workloads.')
param deployAiFoundryAgentSubnet bool = true

@description('Pass the AI Foundry Agent Service subnet to the central Foundry account for account-level network injection. Recommended for Sweden Central and enabled by default.')
param enableAgentNetworkInjection bool = true

@description('Address prefix for the platform/foundation spoke AI Foundry Agent Service subnet.')
param aiFoundryAgentSubnetPrefix string = '10.1.1.0/24'

@description('Deploy a subnet delegated to Microsoft.App/environments for Azure Container Apps Environment.')
param deployContainerAppsSubnet bool = false

@description('Address prefix for the platform/foundation spoke Container Apps subnet. Use at least /23 for Container Apps Environment.')
param containerAppsSubnetPrefix string = '10.1.6.0/23'

@description('Resource ID of the hub VNet to peer with.')
param hubVnetId string

@description('Name of the hub VNet to peer with.')
param hubVnetName string

@description('Resource group name that contains the hub VNet.')
param hubResourceGroupName string

@description('Subscription ID that contains the hub VNet.')
param hubSubscriptionId string = subscription().subscriptionId

@description('Resource group name that contains hub-owned Private DNS zones. Defaults to the hub resource group.')
param hubPrivateDnsResourceGroupName string = hubResourceGroupName

@description('Connectivity-hub-owned Private DNS zone IDs linked to the platform/foundation spoke VNet.')
param spokePrivateDnsZoneIds SpokePrivateDnsZoneIds = {
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

@description('Allow forwarded traffic across the hub/spoke peerings.')
param spokeAllowForwardedTraffic bool = false

@description('Use the hub remote gateway on the spoke-to-hub peering. Requires the hub peering to allow gateway transit.')
param spokeUseRemoteGateways bool = false

@description('Allow the hub VNet to advertise its gateway to this spoke.')
param hubAllowGatewayTransit bool = false

@description('Set to true only if VM autoregistration is desired in linked Private DNS zones. Private endpoint zones should normally use false.')
param spokePrivateDnsRegistrationEnabled bool = false

@description('Optional override for the central AI Foundry account name.')
param aiFoundryAccountName string = ''

@description('Cognitive Services SKU for the central AI Foundry account.')
param aiFoundrySku string = 'S0'

@description('Allows project management on the central AI Foundry account.')
param allowProjectManagement bool = true

@description('Disables local auth and requires Microsoft Entra authentication.')
param disableLocalAuth bool = true

@description('Optional model deployments to create on the central AI Foundry account.')
param aiModelDeployments array = []

@description('Optional Storage Account name override for shared capability-host dependencies. When empty, a name is generated.')
param capabilityHostStorageAccountName string = ''

@description('Optional Cosmos DB account name override for shared capability-host dependencies. When empty, a name is generated.')
param capabilityHostCosmosDbName string = ''

@description('Optional AI Search service name override for shared capability-host dependencies. When empty, a name is generated.')
param capabilityHostSearchServiceName string = ''

@description('Optional Key Vault name override for shared capability-host dependencies. When empty, a name is generated.')
param capabilityHostKeyVaultName string = ''

@description('Deploy a shared Key Vault in the central capability-host dependency set.')
param deployCapabilityHostKeyVault bool = true

@description('Optional override for the Foundry account Storage Blob Data Contributor role assignment name. Use when reusing an existing role assignment.')
param foundryAccountStorageBlobDataContributorRoleAssignmentName string = ''

@description('Optional Log Analytics workspace name override. When empty, a name is generated.')
param logAnalyticsWorkspaceName string = ''

@description('Optional Application Insights name override. When empty, a name is generated.')
param applicationInsightsName string = ''

@description('Number of days to retain Log Analytics data.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 30

@description('When true, wire DNS zone groups into private endpoints by using privateDnsZoneIds. Set to false when Azure Policy or another platform process handles DNS registration.')
param manageDnsZoneGroups bool = true

@description('Connectivity-hub-owned Private DNS zone IDs used for central platform-spoke private endpoint DNS zone groups.')
param privateDnsZoneIds PrivateDnsZoneIds = {
	cognitiveServices: ''
	openAi: ''
	aiServices: ''
	blob: ''
	cosmos: ''
	search: ''
	keyVault: ''
}

var resourceSuffix = substring(uniqueString(subscription().subscriptionId, resourceGroup().id, baseName, 'central-foundry'), 0, 5)
var accountName = empty(aiFoundryAccountName) ? 'ai${replace(baseName, '-', '')}${resourceSuffix}' : aiFoundryAccountName
var cleanBase = replace(baseName, '-', '')
var storageAccountName = empty(capabilityHostStorageAccountName) ? take('staf${cleanBase}${resourceSuffix}', 24) : capabilityHostStorageAccountName
var platformSpokeVnetId = spokeNetwork.outputs.spokeVnetId
var privateEndpointSubnetId = spokeNetwork.outputs.privateEndpointsSubnetId
var aiFoundryAgentSubnetId = enableAgentNetworkInjection ? spokeNetwork.outputs.aiFoundryAgentSubnetId : ''
var storageBlobDataContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var storageAccountResourceId = resourceId('Microsoft.Storage/storageAccounts', storageAccountName)
var foundryStorageBlobDataContributorRoleAssignmentName = empty(foundryAccountStorageBlobDataContributorRoleAssignmentName) ? guid(storageAccountResourceId, accountName, storageBlobDataContributorRoleDefinitionId) : foundryAccountStorageBlobDataContributorRoleAssignmentName

module spokeNetwork '../networking-example-remove/modules/spoke/main.bicep' = {
	params: {
		baseName: platformSpokeBaseName
		location: location
		tags: union(tags, {
			'ailz-scope': 'platform-foundation'
			'ailz-network-placement': 'platform-spoke'
			role: 'platform-spoke-network'
		})
		spokeVnetAddressPrefixes: spokeVnetAddressPrefixes
		privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix
		deployAiFoundryAgentSubnet: deployAiFoundryAgentSubnet
		aiFoundryAgentSubnetPrefix: aiFoundryAgentSubnetPrefix
		deployContainerAppsSubnet: deployContainerAppsSubnet
		containerAppsSubnetPrefix: containerAppsSubnetPrefix
		hubSubscriptionId: hubSubscriptionId
		hubResourceGroupName: hubResourceGroupName
		hubPrivateDnsResourceGroupName: hubPrivateDnsResourceGroupName
		hubVnetName: hubVnetName
		hubVnetId: hubVnetId
		privateDnsZoneIds: spokePrivateDnsZoneIds
		allowForwardedTraffic: spokeAllowForwardedTraffic
		useRemoteGateways: spokeUseRemoteGateways
		allowGatewayTransit: hubAllowGatewayTransit
		privateDnsRegistrationEnabled: spokePrivateDnsRegistrationEnabled
	}
}

module account './modules/ai-foundry/account.bicep' = {
	params: {
		name: accountName
		location: location
		tags: union(tags, {
			'ailz-scope': 'platform-foundation'
			'ailz-network-placement': 'platform-spoke'
		})
		sku: aiFoundrySku
		allowProjectManagement: allowProjectManagement
		disableLocalAuth: disableLocalAuth
		agentSubnetResourceId: aiFoundryAgentSubnetId
		aiModelDeployments: aiModelDeployments
	}
}

module capabilityHostDependencies './modules/ai-foundry/capability-host-dependencies.bicep' = {
	params: {
		baseName: baseName
		uniqueSuffix: resourceSuffix
		location: location
		tags: union(tags, {
			'ailz-scope': 'platform-foundation'
			'ailz-network-placement': 'platform-spoke'
		})
		storageAccountName: capabilityHostStorageAccountName
		cosmosDbAccountName: capabilityHostCosmosDbName
		aiSearchName: capabilityHostSearchServiceName
		keyVaultName: capabilityHostKeyVaultName
		deployKeyVault: deployCapabilityHostKeyVault
		privateEndpointSubnetResourceId: privateEndpointSubnetId
		manageDnsZoneGroups: manageDnsZoneGroups
		blobDnsZoneId: privateDnsZoneIds.blob
		cosmosDnsZoneId: privateDnsZoneIds.cosmos
		searchDnsZoneId: privateDnsZoneIds.search
		keyVaultDnsZoneId: privateDnsZoneIds.keyVault
	}
}

module monitoring './modules/monitoring/monitoring.bicep' = {
	params: {
		baseName: baseName
		uniqueSuffix: resourceSuffix
		location: location
		tags: union(tags, {
			'ailz-scope': 'platform-foundation'
			'ailz-network-placement': 'platform-spoke'
			role: 'platform-monitoring'
		})
		logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
		applicationInsightsName: applicationInsightsName
		logAnalyticsRetentionInDays: logAnalyticsRetentionInDays
	}
}

module applicationInsightsConnection './modules/ai-foundry/connection-application-insights.bicep' = {
	name: 'connection-appinsights-${resourceSuffix}'
	params: {
		aiFoundryName: account.outputs.name
		connectedResourceName: monitoring.outputs.applicationInsightsName
	}
}

resource capabilityHostStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
	name: storageAccountName
}

// Remove?
resource foundryAccountStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
	name: foundryStorageBlobDataContributorRoleAssignmentName
	scope: capabilityHostStorageAccount
	properties: {
		roleDefinitionId: storageBlobDataContributorRoleDefinitionId
		principalId: account.outputs.principalId
		principalType: 'ServicePrincipal'
	}
	dependsOn: [
		capabilityHostDependencies
	]
}

module accountPrivateEndpoint './modules/networking/private-endpoint.bicep' = {
	params: {
		name: 'pep-${account.outputs.name}'
		location: location
		tags: union(tags, {
			'ailz-scope': 'platform-foundation'
			'ailz-network-placement': 'platform-spoke'
		})
		subnetResourceId: privateEndpointSubnetId
		privateLinkServiceConnections: [
			{
				name: 'aiServicesConnection'
				properties: {
					privateLinkServiceId: account.outputs.resourceId
					groupIds: [
						'account'
					]
				}
			}
		]
		privateDnsZoneGroup: manageDnsZoneGroups && !empty(privateDnsZoneIds.cognitiveServices) && !empty(privateDnsZoneIds.openAi) && !empty(privateDnsZoneIds.aiServices) ? {
			name: 'aiServicesDnsZoneGroup'
			privateDnsZoneGroupConfigs: [
				{
					name: 'cognitiveServices'
					privateDnsZoneResourceId: privateDnsZoneIds.cognitiveServices
				}
				{
					name: 'openAi'
					privateDnsZoneResourceId: privateDnsZoneIds.openAi
				}
				{
					name: 'aiServices'
					privateDnsZoneResourceId: privateDnsZoneIds.aiServices
				}
			]
		} : {}
	}
}

output platformSpokeVnetId string = platformSpokeVnetId
output platformPrivateEndpointSubnetId string = privateEndpointSubnetId
output foundrySubscriptionId string = subscription().subscriptionId
output foundryResourceGroupName string = resourceGroup().name
output foundryAccountName string = account.outputs.name
output foundryAccountId string = account.outputs.resourceId
output foundryAccountPrincipalId string = account.outputs.principalId
output foundryAccountEndpoint string = 'https://${account.outputs.name}.services.ai.azure.com/'
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output applicationInsightsName string = monitoring.outputs.applicationInsightsName
output applicationInsightsId string = monitoring.outputs.applicationInsightsId
output applicationInsightsConnectionName string = applicationInsightsConnection.outputs.connectionName
output applicationInsightsConnectionId string = applicationInsightsConnection.outputs.connectionId
output capabilityHostStorageAccountName string = capabilityHostDependencies.outputs.storageAccountName
output capabilityHostStorageAccountId string = capabilityHostDependencies.outputs.storageAccountId
output capabilityHostCosmosDbName string = capabilityHostDependencies.outputs.cosmosDbName
output capabilityHostCosmosDbId string = capabilityHostDependencies.outputs.cosmosDbId
output capabilityHostSearchName string = capabilityHostDependencies.outputs.aiSearchName
output capabilityHostSearchId string = capabilityHostDependencies.outputs.aiSearchId
output capabilityHostKeyVaultName string = deployCapabilityHostKeyVault ? capabilityHostDependencies.outputs.keyVaultName : ''
output capabilityHostKeyVaultId string = deployCapabilityHostKeyVault ? capabilityHostDependencies.outputs.keyVaultId : ''
