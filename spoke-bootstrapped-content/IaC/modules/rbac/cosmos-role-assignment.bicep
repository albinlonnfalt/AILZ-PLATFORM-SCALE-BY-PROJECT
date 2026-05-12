targetScope = 'resourceGroup'

@description('Name of the Cosmos DB account.')
param cosmosDbAccountName string

@description('Principal ID to assign the role to.')
param principalId string

@description('Cosmos DB built-in role definition GUID (e.g., 00000000-0000-0000-0000-000000000002 for Data Contributor).')
param roleDefinitionGuid string

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
	name: cosmosDbAccountName
}

resource assignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
	parent: cosmosDbAccount
	name: guid(cosmosDbAccount.id, principalId, roleDefinitionGuid)
	properties: {
		roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${roleDefinitionGuid}'
		principalId: principalId
		scope: cosmosDbAccount.id
	}
}
