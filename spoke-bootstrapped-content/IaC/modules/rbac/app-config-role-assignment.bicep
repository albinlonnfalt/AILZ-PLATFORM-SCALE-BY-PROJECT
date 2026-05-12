targetScope = 'resourceGroup'

@description('Name of the App Configuration store to scope the role assignments to.')
param appConfigName string

@description('Array of role assignments. Each element must have roleDefinitionId, principalId, and optionally principalType.')
param roleAssignments array

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = {
	name: appConfigName
}

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
	for ra in roleAssignments: {
		name: guid(appConfig.id, ra.principalId, ra.roleDefinitionId)
		scope: appConfig
		properties: {
			roleDefinitionId: ra.roleDefinitionId
			principalId: ra.principalId
			principalType: ra.?principalType ?? 'ServicePrincipal'
		}
	}
]
