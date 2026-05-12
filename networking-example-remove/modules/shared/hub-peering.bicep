targetScope = 'resourceGroup'

@description('Name of the existing hub virtual network.')
param hubVnetName string

@description('Resource ID of the remote spoke virtual network.')
param spokeVnetId string

@description('Name of the remote spoke virtual network.')
param spokeVnetName string

@description('Allow forwarded traffic from the spoke to enter the hub VNet.')
param allowForwardedTraffic bool = false

@description('Allow the hub VNet to advertise its gateway to this spoke.')
param allowGatewayTransit bool = false

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
}

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: '${hubVnetName}-to-${spokeVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spokeVnetId
    }
  }
}

output hubToSpokePeeringName string = hubToSpokePeering.name
