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

@description('Name of the spoke virtual network. Used to create deterministic DNS link names.')
param spokeVnetName string

@description('Resource ID of the spoke virtual network to link to hub-owned Private DNS zones.')
param spokeVnetId string

@description('Hub Private DNS zone IDs. Empty values are skipped.')
param privateDnsZoneIds PrivateDnsZoneIds

@description('Set to true only for DNS zones where VM autoregistration is desired. Private endpoint zones should normally use false.')
param registrationEnabled bool = false

resource cognitiveServicesZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.cognitiveServices)) {
  name: last(split(privateDnsZoneIds.cognitiveServices, '/'))
}

resource openAiZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.openAi)) {
  name: last(split(privateDnsZoneIds.openAi, '/'))
}

resource aiServicesZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.aiServices)) {
  name: last(split(privateDnsZoneIds.aiServices, '/'))
}

resource blobZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.blob)) {
  name: last(split(privateDnsZoneIds.blob, '/'))
}

resource fileZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.file)) {
  name: last(split(privateDnsZoneIds.file, '/'))
}

resource cosmosZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.cosmos)) {
  name: last(split(privateDnsZoneIds.cosmos, '/'))
}

resource searchZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.search)) {
  name: last(split(privateDnsZoneIds.search, '/'))
}

resource keyVaultZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.keyVault)) {
  name: last(split(privateDnsZoneIds.keyVault, '/'))
}

resource acrZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.acr)) {
  name: last(split(privateDnsZoneIds.acr, '/'))
}

resource appConfigZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.appConfig)) {
  name: last(split(privateDnsZoneIds.appConfig, '/'))
}

resource containerAppsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (!empty(privateDnsZoneIds.containerApps)) {
  name: last(split(privateDnsZoneIds.containerApps, '/'))
}

resource cognitiveServicesLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.cognitiveServices)) {
  parent: cognitiveServicesZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource openAiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.openAi)) {
  parent: openAiZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource aiServicesLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.aiServices)) {
  parent: aiServicesZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource blobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.blob)) {
  parent: blobZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource fileLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.file)) {
  parent: fileZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource cosmosLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.cosmos)) {
  parent: cosmosZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource searchLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.search)) {
  parent: searchZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource keyVaultLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.keyVault)) {
  parent: keyVaultZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource acrLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.acr)) {
  parent: acrZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource appConfigLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.appConfig)) {
  parent: appConfigZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

resource containerAppsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (!empty(privateDnsZoneIds.containerApps)) {
  parent: containerAppsZone
  name: 'link-${spokeVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: spokeVnetId
    }
  }
}

output linkedPrivateDnsZoneCount int = length(filter([
  privateDnsZoneIds.cognitiveServices
  privateDnsZoneIds.openAi
  privateDnsZoneIds.aiServices
  privateDnsZoneIds.blob
  privateDnsZoneIds.file
  privateDnsZoneIds.cosmos
  privateDnsZoneIds.search
  privateDnsZoneIds.keyVault
  privateDnsZoneIds.acr
  privateDnsZoneIds.appConfig
  privateDnsZoneIds.containerApps
], zoneId => !empty(zoneId)))
