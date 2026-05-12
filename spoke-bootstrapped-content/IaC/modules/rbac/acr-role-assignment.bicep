targetScope = 'resourceGroup'

@description('Name of the Azure Container Registry to scope the role assignments to.')
param acrName string

@description('Array of role assignments. Each element must have roleDefinitionId, principalId, and optionally principalType.')
param roleAssignments array

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
	name: acrName
}

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
	for ra in roleAssignments: {
		name: guid(registry.id, ra.principalId, ra.roleDefinitionId)
		scope: registry
		properties: {
			roleDefinitionId: ra.roleDefinitionId
			principalId: ra.principalId
			principalType: ra.?principalType ?? 'ServicePrincipal'
		}
	}
]
