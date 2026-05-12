targetScope = 'resourceGroup'

@description('Name of the AI Foundry / AI Services account.')
param name string

@description('Azure region for the AI Foundry account.')
param location string = resourceGroup().location

@description('Tags applied to the AI Foundry account.')
param tags object = {}

@description('Cognitive Services SKU for the AI Foundry account.')
param sku string = 'S0'

@description('Allows project management on the AI Foundry account.')
param allowProjectManagement bool = true

@description('Disables local auth and requires Microsoft Entra authentication.')
param disableLocalAuth bool = true

@description('Resource ID of the AI Foundry Agent Service subnet. Leave empty to use Microsoft-managed networking.')
param agentSubnetResourceId string = ''

@description('Optional model deployments to create on the AI Foundry account.')
param aiModelDeployments array = []

var privateNetworkingEnabled = !empty(agentSubnetResourceId)

module account 'br/public:avm/res/cognitive-services/account:0.13.2' = {
	params: {
		name: name
		location: location
		tags: tags
		sku: sku
		kind: 'AIServices'
		allowProjectManagement: allowProjectManagement
		managedIdentities: {
			systemAssigned: true
		}
		deployments: aiModelDeployments
		customSubDomainName: name
		disableLocalAuth: disableLocalAuth
		publicNetworkAccess: 'Disabled'
		networkAcls: {
			defaultAction: 'Allow'
			bypass: 'AzureServices'
		}
		networkInjections: privateNetworkingEnabled ? {
			scenario: 'agent'
			subnetResourceId: agentSubnetResourceId
			useMicrosoftManagedNetwork: false
		} : null
		privateEndpoints: []
	}
}

output name string = account.outputs.name
output resourceId string = account.outputs.resourceId
output location string = location
output principalId string = account.outputs.?systemAssignedMIPrincipalId ?? ''
