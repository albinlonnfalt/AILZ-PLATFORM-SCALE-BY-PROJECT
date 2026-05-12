targetScope = 'resourceGroup'

@description('Name of the Azure AI Foundry account that contains the project.')
param accountName string

@description('Name of the Azure AI Foundry project to scope role assignments to.')
param projectName string

@description('Array of role assignments. Each element must have roleDefinitionId, principalId, and optionally principalType.')
param roleAssignments array

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
	name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-07-01-preview' existing = {
	parent: account
	name: projectName
}

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
	for ra in roleAssignments: {
		name: guid(project.id, ra.principalId, ra.roleDefinitionId)
		scope: project
		properties: {
			roleDefinitionId: ra.roleDefinitionId
			principalId: ra.principalId
			principalType: ra.?principalType ?? 'ServicePrincipal'
		}
	}
]
