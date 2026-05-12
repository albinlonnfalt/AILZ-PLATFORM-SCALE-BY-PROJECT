targetScope = 'resourceGroup'

type PrivateDnsZoneIds = {
  cognitiveServices: string
  openAi: string
  aiServices: string
  blob: string
  file: string
  cosmos: string
  search: string
  keyVault: string
  acr: string
  appConfig: string
  containerApps: string
}

@description('Base name used to derive spoke resource names.')
param baseName string

@description('Azure region for spoke network resources.')
param location string = resourceGroup().location

@description('Tags applied to all created resources.')
param tags object = {}

@description('Spoke VNet address prefixes.')
param spokeVnetAddressPrefixes array = [
  '10.1.0.0/16'
]

@description('Address prefix for the private endpoints subnet.')
param privateEndpointsSubnetPrefix string = '10.1.0.0/24'

@description('Deploy a subnet delegated to Microsoft.App/environments for AI Foundry Agent Service or similar workloads.')
param deployAiFoundryAgentSubnet bool = true

@description('Address prefix for the AI Foundry Agent Service subnet.')
param aiFoundryAgentSubnetPrefix string = '10.1.1.0/24'

@description('Deploy a subnet delegated to Microsoft.App/environments for Azure Container Apps Environment.')
param deployContainerAppsSubnet bool = false

@description('Address prefix for the Container Apps subnet. Use at least /23 for Container Apps Environment.')
param containerAppsSubnetPrefix string = '10.1.6.0/23'

@description('Resource ID of the hub VNet to peer with.')
param hubVnetId string

@description('Name of the hub VNet to peer with.')
param hubVnetName string

@description('Resource group name that contains the hub VNet.')
param hubResourceGroupName string

@description('Subscription ID that contains the hub VNet.')
param hubSubscriptionId string = subscription().subscriptionId

@description('Resource group name that contains hub-owned Private DNS zones. Defaults to the hub resource group.')
param hubPrivateDnsResourceGroupName string = hubResourceGroupName

@description('Hub Private DNS zone IDs returned by the hub module. Empty values are skipped.')
param privateDnsZoneIds PrivateDnsZoneIds = {
  cognitiveServices: ''
  openAi: ''
  aiServices: ''
  blob: ''
  file: ''
  cosmos: ''
  search: ''
  keyVault: ''
  acr: ''
  appConfig: ''
  containerApps: ''
}

@description('Allow forwarded traffic across the hub/spoke peerings.')
param allowForwardedTraffic bool = false

@description('Use the hub remote gateway on the spoke-to-hub peering. Requires the hub peering to allow gateway transit.')
param useRemoteGateways bool = false

@description('Allow the hub VNet to advertise its gateway to this spoke.')
param allowGatewayTransit bool = false

@description('Set to true only if VM autoregistration is desired in the linked Private DNS zones. Private endpoint zones should normally use false.')
param privateDnsRegistrationEnabled bool = false

var spokeVnetName = 'vnet-${baseName}-spoke'
var privateEndpointsSubnetName = 'snet-private-endpoints'
var aiFoundryAgentSubnetName = 'snet-ai-foundry-agent'
var containerAppsSubnetName = 'snet-container-apps'

var allowVnetHttpsRule = {
  name: 'AllowVnetInBoundHttps'
  properties: {
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceAddressPrefix: 'VirtualNetwork'
    sourcePortRange: '*'
    destinationAddressPrefix: 'VirtualNetwork'
    destinationPortRange: '443'
  }
}

var denyAllInboundRule = {
  name: 'DenyAllInbound'
  properties: {
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}

resource privateEndpointsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${baseName}-spoke-pe'
  location: location
  tags: tags
  properties: {
    securityRules: [
      allowVnetHttpsRule
      denyAllInboundRule
    ]
  }
}

resource aiFoundryAgentNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (deployAiFoundryAgentSubnet) {
  name: 'nsg-${baseName}-spoke-agent'
  location: location
  tags: tags
  properties: {
    securityRules: [
      allowVnetHttpsRule
      denyAllInboundRule
    ]
  }
}

resource containerAppsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (deployContainerAppsSubnet) {
  name: 'nsg-${baseName}-spoke-cae'
  location: location
  tags: tags
  properties: {
    securityRules: [
      allowVnetHttpsRule
      denyAllInboundRule
    ]
  }
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spokeVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: spokeVnetAddressPrefixes
    }
    subnets: concat(
      [
        {
          name: privateEndpointsSubnetName
          properties: {
            addressPrefix: privateEndpointsSubnetPrefix
            privateEndpointNetworkPolicies: 'Enabled'
            networkSecurityGroup: {
              id: privateEndpointsNsg.id
            }
          }
        }
      ],
      deployAiFoundryAgentSubnet
        ? [
            {
              name: aiFoundryAgentSubnetName
              properties: {
                addressPrefix: aiFoundryAgentSubnetPrefix
                networkSecurityGroup: {
                  id: aiFoundryAgentNsg.id
                }
                delegations: [
                  {
                    name: 'delegation-Microsoft.App-environments'
                    properties: {
                      serviceName: 'Microsoft.App/environments'
                    }
                  }
                ]
              }
            }
          ]
        : [],
      deployContainerAppsSubnet
        ? [
            {
              name: containerAppsSubnetName
              properties: {
                addressPrefix: containerAppsSubnetPrefix
                networkSecurityGroup: {
                  id: containerAppsNsg.id
                }
                delegations: [
                  {
                    name: 'delegation-Microsoft.App-environments'
                    properties: {
                      serviceName: 'Microsoft.App/environments'
                    }
                  }
                ]
              }
            }
          ]
        : []
    )
  }
}

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spokeVnet
  name: '${spokeVnetName}-to-${hubVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: hubVnetId
    }
  }
}

module hubPeering '../shared/hub-peering.bicep' = {
  scope: resourceGroup(hubSubscriptionId, hubResourceGroupName)
  params: {
    hubVnetName: hubVnetName
    spokeVnetId: spokeVnet.id
    spokeVnetName: spokeVnet.name
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
  }
}

module privateDnsLinks '../shared/private-dns-zone-links.bicep' = {
  scope: resourceGroup(hubSubscriptionId, hubPrivateDnsResourceGroupName)
  params: {
    spokeVnetName: spokeVnet.name
    spokeVnetId: spokeVnet.id
    privateDnsZoneIds: privateDnsZoneIds
    registrationEnabled: privateDnsRegistrationEnabled
  }
}

output spokeVnetId string = spokeVnet.id
output spokeVnetName string = spokeVnet.name
output privateEndpointsSubnetId string = '${spokeVnet.id}/subnets/${privateEndpointsSubnetName}'
output aiFoundryAgentSubnetId string = deployAiFoundryAgentSubnet ? '${spokeVnet.id}/subnets/${aiFoundryAgentSubnetName}' : ''
output containerAppsSubnetId string = deployContainerAppsSubnet ? '${spokeVnet.id}/subnets/${containerAppsSubnetName}' : ''
output spokeToHubPeeringName string = spokeToHubPeering.name
output hubToSpokePeeringName string = hubPeering.outputs.hubToSpokePeeringName
output linkedPrivateDnsZoneCount int = privateDnsLinks.outputs.linkedPrivateDnsZoneCount
