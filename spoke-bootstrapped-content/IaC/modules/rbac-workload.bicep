targetScope = 'resourceGroup'

import * as const from '../constants/constants.bicep'

@description('Principal ID of the workload user-assigned managed identity.')
param workloadPrincipalId string

@description('Assign workload roles on the standalone Cosmos DB account.')
param assignCosmosDbRoles bool = false

@description('Assign workload roles on the standalone AI Search service.')
param assignAiSearchRoles bool = false

@description('Assign workload roles on the standalone Storage account.')
param assignStorageRoles bool = false

@description('Assign workload roles on the Key Vault.')
param assignKeyVaultRoles bool = false

@description('Assign workload roles on the Container Registry.')
param assignAcrRoles bool = false

@description('Assign workload roles on the App Configuration store.')
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
var _assignWorkloadRoles = !empty(workloadPrincipalId)

module assignWorkloadKvRoles './rbac/key-vault-role-assignment.bicep' = if (_assignWorkloadRoles && assignKeyVaultRoles) {
	name: 'role-workload-kv'
	params: {
		keyVaultName: keyVaultName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.KeyVaultSecretsUser.guid)
				principalId: workloadPrincipalId
			}
		]
	}
}

module assignWorkloadSearchRoles './rbac/search-role-assignment.bicep' = if (_assignWorkloadRoles && assignAiSearchRoles) {
	name: 'role-workload-search'
	params: {
		searchServiceName: searchServiceName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.SearchIndexDataContributor.guid)
				principalId: workloadPrincipalId
			}
		]
	}
}

module assignWorkloadStorageRoles './rbac/storage-role-assignment.bicep' = if (_assignWorkloadRoles && assignStorageRoles) {
	name: 'role-workload-storage'
	params: {
		storageAccountName: storageAccountName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.StorageBlobDataContributor.guid)
				principalId: workloadPrincipalId
			}
		]
	}
}

module assignWorkloadAcrRoles './rbac/acr-role-assignment.bicep' = if (_assignWorkloadRoles && assignAcrRoles) {
	name: 'role-workload-acr'
	params: {
		acrName: acrName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.AcrPull.guid)
				principalId: workloadPrincipalId
			}
		]
	}
}

module assignWorkloadAppConfigRoles './rbac/app-config-role-assignment.bicep' = if (_assignWorkloadRoles && assignAppConfigRoles) {
	name: 'role-workload-appconfig'
	params: {
		appConfigName: appConfigName
		roleAssignments: [
			{
				roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', _roles.AppConfigurationDataReader.guid)
				principalId: workloadPrincipalId
			}
		]
	}
}

module assignWorkloadCosmosRoles './rbac/cosmos-role-assignment.bicep' = if (_assignWorkloadRoles && assignCosmosDbRoles) {
	name: 'role-workload-cosmos'
	params: {
		cosmosDbAccountName: cosmosDbAccountName
		principalId: workloadPrincipalId
		roleDefinitionGuid: _roles.CosmosDBBuiltInDataContributor.guid
	}
}
