targetScope = 'resourceGroup'

import * as const from '../constants/constants.bicep'

@description('Principal ID of the developer to assign RBAC roles on optional workload resources. Leave empty to skip.')
param developerPrincipalId string = ''

@description('Principal type of the developer (User, Group, or ServicePrincipal).')
param developerPrincipalType string = 'User'

@description('Assign developer roles on the standalone Cosmos DB account.')
param assignCosmosDbRoles bool = false

@description('Assign developer roles on the standalone AI Search service.')
param assignAiSearchRoles bool = false

@description('Assign developer roles on the standalone Storage account.')
param assignStorageRoles bool = false

@description('Assign developer roles on the Key Vault.')
param assignKeyVaultRoles bool = false

@description('Assign developer roles on the Container Registry.')
param assignAcrRoles bool = false

@description('Assign developer roles on the App Configuration store.')
param assignAppConfigRoles bool = false

@description('Name of the standalone Cosmos DB account.')
param cosmosDbAccountName string = ''

@description('Name of the standalone AI Search service.')
param searchServiceName string = ''

@description('Name of the standalone Storage account.')
param storageAccountName string = ''

@description('Name of the Key Vault.')
param keyVaultName string = ''

@description('Name of the Azure Container Registry.')
param acrName string = ''

@description('Name of the App Configuration store.')
param appConfigName string = ''

var _roles = const.roles
var _assignDeveloperRoles = !empty(developerPrincipalId)

module assignDeveloperKvRoles './rbac/key-vault-role-assignment.bicep' = if (_assignDeveloperRoles && assignKeyVaultRoles) {
	name: 'role-developer-kv'
	params: {
		keyVaultName: keyVaultName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.KeyVaultContributor.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.KeyVaultSecretsOfficer.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
		]
	}
}

module assignDeveloperSearchRoles './rbac/search-role-assignment.bicep' = if (_assignDeveloperRoles && assignAiSearchRoles) {
	name: 'role-developer-search'
	params: {
		searchServiceName: searchServiceName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.SearchServiceContributor.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.SearchIndexDataContributor.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.SearchIndexDataReader.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
		]
	}
}

module assignDeveloperStorageRoles './rbac/storage-role-assignment.bicep' = if (_assignDeveloperRoles && assignStorageRoles) {
	name: 'role-developer-storage'
	params: {
		storageAccountName: storageAccountName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.StorageBlobDataContributor.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
		]
	}
}

module assignDeveloperAcrRoles './rbac/acr-role-assignment.bicep' = if (_assignDeveloperRoles && assignAcrRoles) {
	name: 'role-developer-acr'
	params: {
		acrName: acrName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.AcrPush.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.AcrPull.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
		]
	}
}

module assignDeveloperAppConfigRoles './rbac/app-config-role-assignment.bicep' = if (_assignDeveloperRoles && assignAppConfigRoles) {
	name: 'role-developer-appconfig'
	params: {
		appConfigName: appConfigName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.AppConfigurationDataOwner.guid)
				principalId: developerPrincipalId
				principalType: developerPrincipalType
			}
		]
	}
}

module assignDeveloperCosmosRoles './rbac/cosmos-role-assignment.bicep' = if (_assignDeveloperRoles && assignCosmosDbRoles) {
	name: 'role-developer-cosmos'
	params: {
		cosmosDbAccountName: cosmosDbAccountName
		principalId: developerPrincipalId
		roleDefinitionGuid: _roles.CosmosDBBuiltInDataContributor.guid
	}
}
