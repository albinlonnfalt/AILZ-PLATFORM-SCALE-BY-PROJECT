targetScope = 'resourceGroup'

@description('Name of the Key Vault to scope the role assignments to.')
param keyVaultName string

@description('Array of role assignments. Each element must have roleDefinitionId, principalId, and optionally principalType.')
param roleAssignments array

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
	name: keyVaultName
}

resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
	for ra in roleAssignments: {
		name: guid(keyVault.id, ra.principalId, ra.roleDefinitionId)
		scope: keyVault
		properties: {
			roleDefinitionId: ra.roleDefinitionId
			principalId: ra.principalId
			principalType: ra.?principalType ?? 'ServicePrincipal'
		}
	}
]
