using './main.bicep'

param baseName = 'ailz-platform'
param location = 'swedencentral'
param tags = {
  workload: 'ai-landing-zone'
  scope: 'platform-foundation'
}

param platformSpokeBaseName = 'ailz-platform'
param spokeVnetAddressPrefixes = [
  '10.1.0.0/16'
]
param privateEndpointsSubnetPrefix = '10.1.0.0/24'
param deployAiFoundryAgentSubnet = true
param enableAgentNetworkInjection = true
param aiFoundryAgentSubnetPrefix = '10.1.1.0/24'
param deployContainerAppsSubnet = false
param containerAppsSubnetPrefix = '10.1.6.0/23'

param hubSubscriptionId = '<connectivity-subscription-id>'
param hubResourceGroupName = '<hub-rg>'
param hubPrivateDnsResourceGroupName = '<dns-rg>'
param hubVnetName = '<hub-vnet-name>'
param hubVnetId = '/subscriptions/<connectivity-subscription-id>/resourceGroups/<hub-rg>/providers/Microsoft.Network/virtualNetworks/<hub-vnet-name>'

param spokePrivateDnsZoneIds = {
  cognitiveServices: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  openAi: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
  aiServices: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com'
  blob: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
  file: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net'
  cosmos: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com'
  search: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net'
  keyVault: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
  acr: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
  appConfig: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.azconfig.io'
  containerApps: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.azurecontainerapps.io'
}
param spokeAllowForwardedTraffic = false
param spokeUseRemoteGateways = false
param hubAllowGatewayTransit = false
param spokePrivateDnsRegistrationEnabled = false

param manageDnsZoneGroups = true
param privateDnsZoneIds = {
  cognitiveServices: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
  openAi: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com'
  aiServices: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com'
  blob: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net'
  cosmos: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com'
  search: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net'
  keyVault: '/subscriptions/<connectivity-subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'
}

param deployCapabilityHostKeyVault = true
param logAnalyticsWorkspaceName = ''
param applicationInsightsName = ''
param logAnalyticsRetentionInDays = 30
param aiModelDeployments = []
