using '../modules/spoke/main.bicep'

param baseName = 'ailz-app1'
param location = 'swedencentral'
param tags = {
  workload: 'ai-landing-zone'
  role: 'spoke-network'
}

param spokeVnetAddressPrefixes = [
  '10.1.0.0/16'
]
param privateEndpointsSubnetPrefix = '10.1.0.0/24'
param deployAiFoundryAgentSubnet = true
param aiFoundryAgentSubnetPrefix = '10.1.1.0/24'
param deployContainerAppsSubnet = true
param containerAppsSubnetPrefix = '10.1.6.0/23'

param hubSubscriptionId = readEnvironmentVariable('HUB_SUBSCRIPTION_ID', '00000000-0000-0000-0000-000000000000')
param hubResourceGroupName = readEnvironmentVariable('HUB_RESOURCE_GROUP_NAME', 'rg-ailz-hub')
param hubPrivateDnsResourceGroupName = readEnvironmentVariable('HUB_PRIVATE_DNS_RESOURCE_GROUP_NAME', 'rg-ailz-hub')
param hubVnetName = readEnvironmentVariable('HUB_VNET_NAME', 'vnet-ailz-hub')
param hubVnetId = readEnvironmentVariable('HUB_VNET_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/virtualNetworks/vnet-ailz-hub')

param allowForwardedTraffic = false
param useRemoteGateways = false
param allowGatewayTransit = false
param privateDnsRegistrationEnabled = false

param privateDnsZoneIds = {
  cognitiveServices: readEnvironmentVariable('DNS_COGNITIVE_SERVICES_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com')
  openAi: readEnvironmentVariable('DNS_OPENAI_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com')
  aiServices: readEnvironmentVariable('DNS_AI_SERVICES_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com')
  blob: readEnvironmentVariable('DNS_BLOB_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net')
  file: readEnvironmentVariable('DNS_FILE_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net')
  cosmos: readEnvironmentVariable('DNS_COSMOS_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com')
  search: readEnvironmentVariable('DNS_SEARCH_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net')
  keyVault: readEnvironmentVariable('DNS_KEYVAULT_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net')
  acr: readEnvironmentVariable('DNS_ACR_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io')
  appConfig: readEnvironmentVariable('DNS_APPCONFIG_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.azconfig.io')
  containerApps: readEnvironmentVariable('DNS_CONTAINERAPPS_ID', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ailz-hub/providers/Microsoft.Network/privateDnsZones/privatelink.swedencentral.azurecontainerapps.io')
}
