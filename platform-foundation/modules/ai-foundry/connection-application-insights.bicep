targetScope = 'resourceGroup'

metadata name = 'ai-foundry-connection-app-insights'
metadata description = 'Create an Application Insights connection in an Azure AI Foundry account.'

@description('Name of the Azure AI Foundry account.')
param aiFoundryName string

@description('Name of the Application Insights resource to connect.')
param connectedResourceName string

@description('Optional name to assign to the Application Insights connection.')
param appInsightsConnectionName string = '${aiFoundryName}-appinsights-connection'

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
	name: aiFoundryName
}

resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
	name: connectedResourceName
}

resource connection 'Microsoft.CognitiveServices/accounts/connections@2025-06-01' = {
	name: appInsightsConnectionName
	parent: aiFoundry
	properties: {
		category: 'AppInsights'
		target: existingAppInsights.id
		authType: 'ApiKey'
		isSharedToAll: true
		credentials: {
			key: existingAppInsights.properties.ConnectionString
		}
		metadata: {
			ApiType: 'Azure'
			ResourceId: existingAppInsights.id
		}
	}
}

output connectionName string = connection.name
output connectionId string = connection.id
