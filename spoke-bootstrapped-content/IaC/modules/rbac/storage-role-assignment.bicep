targetScope = 'resourceGroup'

@description('Name of the Storage account to scope the role assignments to.')
param storageAccountName string

@description('Array of role assignments. Each element must have roleDefinitionId, principalId, and optionally principalType.')
param roleAssignments array

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
	name: storageAccountName
}

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
	for ra in roleAssignments: {
		name: guid(storageAccount.id, ra.principalId, ra.roleDefinitionId)
		scope: storageAccount
		properties: {
			roleDefinitionId: ra.roleDefinitionId
			principalId: ra.principalId
			principalType: ra.?principalType ?? 'ServicePrincipal'
		}
	}
]
