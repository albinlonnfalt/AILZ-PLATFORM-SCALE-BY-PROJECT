targetScope = 'resourceGroup'

@description('Name of the Azure AI Search service to scope the role assignments to.')
param searchServiceName string

@description('Array of role assignments. Each element must have roleDefinitionId, principalId, and optionally principalType.')
param roleAssignments array

resource searchService 'Microsoft.Search/searchServices@2023-11-01' existing = {
	name: searchServiceName
}

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
	for ra in roleAssignments: {
		name: guid(searchService.id, ra.principalId, ra.roleDefinitionId)
		scope: searchService
		properties: {
			roleDefinitionId: ra.roleDefinitionId
			principalId: ra.principalId
			principalType: ra.?principalType ?? 'ServicePrincipal'
		}
	}
]
