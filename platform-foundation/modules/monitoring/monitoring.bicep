targetScope = 'resourceGroup'

@description('Base name used to derive monitoring resource names.')
param baseName string

@description('Optional unique suffix used for monitoring resource names.')
param uniqueSuffix string = substring(uniqueString(subscription().subscriptionId, resourceGroup().id, baseName, 'monitoring'), 0, 5)

@description('Azure region for monitoring resources.')
param location string = resourceGroup().location

@description('Tags applied to monitoring resources.')
param tags object = {}

@description('Optional Log Analytics workspace name override. When empty, a name is generated.')
param logAnalyticsWorkspaceName string = ''

@description('Optional Application Insights name override. When empty, a name is generated.')
param applicationInsightsName string = ''

@description('Number of days to retain Log Analytics data.')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionInDays int = 30

var workspaceName = empty(logAnalyticsWorkspaceName) ? take('law-${baseName}-${uniqueSuffix}', 63) : logAnalyticsWorkspaceName
var appInsightsName = empty(applicationInsightsName) ? take('appi-${baseName}-${uniqueSuffix}', 260) : applicationInsightsName

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
	name: workspaceName
	location: location
	tags: tags
	identity: {
		type: 'SystemAssigned'
	}
	properties: {
		sku: {
			name: 'PerGB2018'
		}
		retentionInDays: logAnalyticsRetentionInDays
		features: {
			disableLocalAuth: false
		}
	}
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
	name: appInsightsName
	location: location
	kind: 'web'
	tags: tags
	properties: {
		Application_Type: 'web'
		WorkspaceResourceId: logAnalytics.id
		DisableIpMasking: false
		publicNetworkAccessForIngestion: 'Enabled'
		publicNetworkAccessForQuery: 'Enabled'
	}
}

output logAnalyticsWorkspaceName string = logAnalytics.name
output logAnalyticsWorkspaceId string = logAnalytics.id
output applicationInsightsName string = appInsights.name
output applicationInsightsId string = appInsights.id
