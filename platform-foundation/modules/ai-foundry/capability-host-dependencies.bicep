targetScope = 'resourceGroup'

@description('Base name used to derive resource names.')
param baseName string

@description('Optional unique suffix used for globally unique dependency names.')
param uniqueSuffix string = substring(uniqueString(subscription().subscriptionId, resourceGroup().id, baseName, 'foundry-capability-host'), 0, 5)

@description('Azure region for dependency resources.')
param location string = resourceGroup().location

@description('Tags applied to dependency resources.')
param tags object = {}

@description('Optional Storage Account name override. When empty, a name is generated.')
param storageAccountName string = ''

@description('Optional Cosmos DB account name override. When empty, a name is generated.')
param cosmosDbAccountName string = ''

@description('Optional AI Search service name override. When empty, a name is generated.')
param aiSearchName string = ''

@description('Optional Key Vault name override. When empty, a name is generated.')
param keyVaultName string = ''

@description('Deploy an associated Key Vault for the Foundry capability-host dependency set.')
param deployKeyVault bool = false

@description('Resource ID of the subnet for private endpoints. Leave empty to skip private endpoints.')
param privateEndpointSubnetResourceId string = ''

@description('When true, wire DNS zone groups into private endpoints.')
param manageDnsZoneGroups bool = true

@description('DNS zone ID for Storage blob private endpoints.')
param blobDnsZoneId string = ''

@description('DNS zone ID for Cosmos DB private endpoints.')
param cosmosDnsZoneId string = ''

@description('DNS zone ID for AI Search private endpoints.')
param searchDnsZoneId string = ''

@description('DNS zone ID for Key Vault private endpoints.')
param keyVaultDnsZoneId string = ''

var cleanBase = replace(baseName, '-', '')
var storageName = empty(storageAccountName) ? take('staf${cleanBase}${uniqueSuffix}', 24) : storageAccountName
var cosmosName = empty(cosmosDbAccountName) ? take('cosmos-af-${baseName}-${uniqueSuffix}', 44) : cosmosDbAccountName
var searchName = empty(aiSearchName) ? take('srch-af-${baseName}-${uniqueSuffix}', 60) : aiSearchName
var vaultName = empty(keyVaultName) ? take('kv-af-${baseName}-${uniqueSuffix}', 24) : keyVaultName
var createPrivateEndpoints = !empty(privateEndpointSubnetResourceId)

module storageAccount 'br/public:avm/res/storage/storage-account:0.26.2' = {
	params: {
		name: storageName
		location: location
		tags: tags
		skuName: 'Standard_LRS'
		kind: 'StorageV2'
		accessTier: 'Hot'
		publicNetworkAccess: createPrivateEndpoints ? 'Disabled' : 'Enabled'
		allowSharedKeyAccess: false
		allowBlobPublicAccess: false
		supportsHttpsTrafficOnly: true
		minimumTlsVersion: 'TLS1_2'
		networkAcls: {
			defaultAction: createPrivateEndpoints ? 'Deny' : 'Allow'
			bypass: 'AzureServices'
		}
		blobServices: {
			deleteRetentionPolicyEnabled: true
			deleteRetentionPolicyDays: 7
			containerDeleteRetentionPolicyEnabled: true
			containerDeleteRetentionPolicyDays: 7
		}
		privateEndpoints: createPrivateEndpoints ? [
			{
				service: 'blob'
				subnetResourceId: privateEndpointSubnetResourceId
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(blobDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{
							privateDnsZoneResourceId: blobDnsZoneId
						}
					]
				} : null
			}
		] : []
	}
}

module cosmosDb 'br/public:avm/res/document-db/database-account:0.15.1' = {
	params: {
		name: cosmosName
		location: location
		tags: tags
		defaultConsistencyLevel: 'Session'
		failoverLocations: [
			{
				locationName: location
				failoverPriority: 0
				isZoneRedundant: false
			}
		]
		disableLocalAuthentication: true
		networkRestrictions: {
			publicNetworkAccess: createPrivateEndpoints ? 'Disabled' : 'Enabled'
			networkAclBypass: 'AzureServices'
		}
		privateEndpoints: createPrivateEndpoints ? [
			{
				service: 'Sql'
				subnetResourceId: privateEndpointSubnetResourceId
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(cosmosDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{
							privateDnsZoneResourceId: cosmosDnsZoneId
						}
					]
				} : null
			}
		] : []
	}
}

module aiSearch 'br/public:avm/res/search/search-service:0.11.1' = {
	params: {
		name: searchName
		location: location
		tags: tags
		sku: 'standard'
		replicaCount: 1
		partitionCount: 1
		publicNetworkAccess: createPrivateEndpoints ? 'Disabled' : 'Enabled'
		disableLocalAuth: createPrivateEndpoints
		managedIdentities: {
			systemAssigned: true
		}
		privateEndpoints: createPrivateEndpoints ? [
			{
				subnetResourceId: privateEndpointSubnetResourceId
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(searchDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{
							privateDnsZoneResourceId: searchDnsZoneId
						}
					]
				} : null
			}
		] : []
	}
}

module keyVault 'br/public:avm/res/key-vault/vault:0.13.0' = if (deployKeyVault) {
	params: {
		name: vaultName
		location: location
		tags: tags
		sku: 'standard'
		enableRbacAuthorization: true
		enableSoftDelete: true
		publicNetworkAccess: createPrivateEndpoints ? 'Disabled' : 'Enabled'
		networkAcls: {
			defaultAction: createPrivateEndpoints ? 'Deny' : 'Allow'
			bypass: 'AzureServices'
		}
		privateEndpoints: createPrivateEndpoints ? [
			{
				subnetResourceId: privateEndpointSubnetResourceId
				privateDnsZoneGroup: manageDnsZoneGroups && !empty(keyVaultDnsZoneId) ? {
					privateDnsZoneGroupConfigs: [
						{
							privateDnsZoneResourceId: keyVaultDnsZoneId
						}
					]
				} : null
			}
		] : []
	}
}

output storageAccountName string = storageAccount.outputs.name
output storageAccountId string = storageAccount.outputs.resourceId
output storageAccountSubscriptionId string = subscription().subscriptionId
output storageAccountResourceGroupName string = resourceGroup().name

output cosmosDbName string = cosmosDb.outputs.name
output cosmosDbId string = cosmosDb.outputs.resourceId
output cosmosDbSubscriptionId string = subscription().subscriptionId
output cosmosDbResourceGroupName string = resourceGroup().name

output aiSearchName string = aiSearch.outputs.name
output aiSearchId string = aiSearch.outputs.resourceId
output aiSearchSubscriptionId string = subscription().subscriptionId
output aiSearchResourceGroupName string = resourceGroup().name
output aiSearchPrincipalId string = aiSearch.outputs.?systemAssignedMIPrincipalId ?? ''

output keyVaultName string = deployKeyVault ? keyVault!.outputs.name : ''
output keyVaultId string = deployKeyVault ? keyVault!.outputs.resourceId : ''
output keyVaultSubscriptionId string = deployKeyVault ? subscription().subscriptionId : ''
output keyVaultResourceGroupName string = deployKeyVault ? resourceGroup().name : ''
