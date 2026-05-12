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

@description('Base name used to derive resource names.')
param baseName string

@description('Azure region for all hub resources.')
param location string = resourceGroup().location

@description('Tags applied to all created resources.')
param tags object = {}

@description('Hub VNet address prefixes.')
param hubVnetAddressPrefixes array = [
  '10.0.0.0/16'
]

@description('Address prefix for Azure Bastion. Must be at least /26 and named AzureBastionSubnet.')
param bastionSubnetPrefix string = '10.0.0.0/26'

@description('Address prefix for the management subnet that hosts the jump VM.')
param managementSubnetPrefix string = '10.0.1.0/24'

@description('Deploy a hub private endpoint subnet for future hub-hosted private endpoints.')
param deployPrivateEndpointSubnet bool = true

@description('Address prefix for the optional hub private endpoint subnet.')
param privateEndpointSubnetPrefix string = '10.0.2.0/24'

@description('Admin username for the Windows jump VM.')
param adminUsername string = 'azureadmin'

@secure()
@description('Admin password for the Windows jump VM.')
param adminPassword string

@description('Optional explicit jump VM name. Leave empty to derive one from baseName.')
param vmName string = ''

@description('Size for the Windows jump VM.')
param vmSize string = 'Standard_B2s'

@description('Azure Bastion SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param bastionSku string = 'Basic'

@description('Deploy DNS zones for AI Foundry associated resources: Storage, Cosmos DB, AI Search, Key Vault.')
param includeAssociatedResources bool = true

@description('Deploy the private DNS zone for Azure Container Registry.')
param deployAcr bool = false

@description('Deploy the private DNS zone for Azure App Configuration.')
param deployAppConfig bool = false

@description('Deploy the private DNS zone for a standalone Cosmos DB account.')
param deployGenaiCosmos bool = false

@description('Deploy the private DNS zone for a standalone AI Search service.')
param deployGenaiSearch bool = false

@description('Deploy the private DNS zone for a standalone Storage account.')
param deployGenaiStorage bool = false

@description('Deploy the private DNS zone for a standalone Key Vault.')
param deployGenaiKeyVault bool = false

@description('Deploy the regional private DNS zone for Azure Container Apps Environment.')
param deployContainerApps bool = false

var hubVnetName = 'vnet-${baseName}-hub'
var managementSubnetName = 'snet-management'
var privateEndpointSubnetName = 'snet-private-endpoints'
var effectiveVmName = empty(vmName) ? 'vm-${baseName}-jump' : vmName
var computerNameSeed = '${replace(baseName, '-', '')}${substring(uniqueString(resourceGroup().id, baseName), 0, 4)}000000000000000'
var computerName = substring(computerNameSeed, 0, 15)
var needBlobZone = includeAssociatedResources || deployGenaiStorage
var needCosmosZone = includeAssociatedResources || deployGenaiCosmos
var needSearchZone = includeAssociatedResources || deployGenaiSearch
var needKeyVaultZone = includeAssociatedResources || deployGenaiKeyVault

var allowRdpFromBastionRule = {
  name: 'AllowRdpFromAzureBastion'
  properties: {
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceAddressPrefix: bastionSubnetPrefix
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '3389'
  }
}

var denyInternetInboundRule = {
  name: 'DenyInternetInbound'
  properties: {
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: 'Internet'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}

resource managementNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${baseName}-hub-management'
  location: location
  tags: tags
  properties: {
    securityRules: [
      allowRdpFromBastionRule
      denyInternetInboundRule
    ]
  }
}

resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (deployPrivateEndpointSubnet) {
  name: 'nsg-${baseName}-hub-pe'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
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
      {
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
    ]
  }
}

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${baseName}-hub-natgw'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'ng-${baseName}-hub'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hubVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: hubVnetAddressPrefixes
    }
    subnets: concat(
      [
        {
          name: 'AzureBastionSubnet'
          properties: {
            addressPrefix: bastionSubnetPrefix
          }
        }
        {
          name: managementSubnetName
          properties: {
            addressPrefix: managementSubnetPrefix
            networkSecurityGroup: {
              id: managementNsg.id
            }
            natGateway: {
              id: natGateway.id
            }
          }
        }
      ],
      deployPrivateEndpointSubnet
        ? [
            {
              name: privateEndpointSubnetName
              properties: {
                addressPrefix: privateEndpointSubnetPrefix
                networkSecurityGroup: {
                  id: privateEndpointNsg.id
                }
                privateEndpointNetworkPolicies: 'Enabled'
              }
            }
          ]
        : []
    )
  }
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${baseName}-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-${baseName}'
  location: location
  tags: tags
  sku: {
    name: bastionSku
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

resource jumpNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${effectiveVmName}-nic-01'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig01'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hubVnet.id}/subnets/${managementSubnetName}'
          }
        }
      }
    ]
  }
}

resource jumpVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: effectiveVmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'windows-11'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: jumpNic.id
        }
      ]
    }
  }
  dependsOn: [
    bastionHost
  ]
}

resource cognitiveServicesZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'
  tags: tags
}

resource openAiZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
  tags: tags
}

resource aiServicesZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.services.ai.azure.com'
  location: 'global'
  tags: tags
}

resource blobZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (needBlobZone) {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource fileZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (includeAssociatedResources) {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource cosmosZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (needCosmosZone) {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: tags
}

resource searchZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (needSearchZone) {
  name: 'privatelink.search.windows.net'
  location: 'global'
  tags: tags
}

resource keyVaultZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (needKeyVaultZone) {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource acrZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployAcr) {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

resource appConfigZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployAppConfig) {
  name: 'privatelink.azconfig.io'
  location: 'global'
  tags: tags
}

resource containerAppsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployContainerApps) {
  name: 'privatelink.${location}.azurecontainerapps.io'
  location: 'global'
  tags: tags
}

resource cognitiveServicesHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cognitiveServicesZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource openAiHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: openAiZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource aiServicesHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: aiServicesZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource blobHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (needBlobZone) {
  parent: blobZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource fileHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (includeAssociatedResources) {
  parent: fileZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource cosmosHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (needCosmosZone) {
  parent: cosmosZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource searchHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (needSearchZone) {
  parent: searchZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource keyVaultHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (needKeyVaultZone) {
  parent: keyVaultZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource acrHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployAcr) {
  parent: acrZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource appConfigHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployAppConfig) {
  parent: appConfigZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource containerAppsHubLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (deployContainerApps) {
  parent: containerAppsZone
  name: 'link-${hubVnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

var privateDnsZoneIds PrivateDnsZoneIds = {
  cognitiveServices: cognitiveServicesZone.id
  openAi: openAiZone.id
  aiServices: aiServicesZone.id
  blob: needBlobZone ? blobZone.id : ''
  file: includeAssociatedResources ? fileZone.id : ''
  cosmos: needCosmosZone ? cosmosZone.id : ''
  search: needSearchZone ? searchZone.id : ''
  keyVault: needKeyVaultZone ? keyVaultZone.id : ''
  acr: deployAcr ? acrZone.id : ''
  appConfig: deployAppConfig ? appConfigZone.id : ''
  containerApps: deployContainerApps ? containerAppsZone.id : ''
}

output hubVnetId string = hubVnet.id
output hubVnetName string = hubVnet.name
output bastionSubnetId string = '${hubVnet.id}/subnets/AzureBastionSubnet'
output managementSubnetId string = '${hubVnet.id}/subnets/${managementSubnetName}'
output privateEndpointsSubnetId string = deployPrivateEndpointSubnet ? '${hubVnet.id}/subnets/${privateEndpointSubnetName}' : ''
output bastionHostName string = bastionHost.name
output jumpVmName string = jumpVm.name
output jumpVmPrincipalId string = jumpVm.identity.principalId
output privateDnsZoneIds PrivateDnsZoneIds = privateDnsZoneIds
output cognitiveServicesDnsZoneId string = privateDnsZoneIds.cognitiveServices
output openAiDnsZoneId string = privateDnsZoneIds.openAi
output aiServicesDnsZoneId string = privateDnsZoneIds.aiServices
output blobDnsZoneId string = privateDnsZoneIds.blob
output fileDnsZoneId string = privateDnsZoneIds.file
output cosmosDnsZoneId string = privateDnsZoneIds.cosmos
output searchDnsZoneId string = privateDnsZoneIds.search
output keyVaultDnsZoneId string = privateDnsZoneIds.keyVault
output acrDnsZoneId string = privateDnsZoneIds.acr
output appConfigDnsZoneId string = privateDnsZoneIds.appConfig
output containerAppsDnsZoneId string = privateDnsZoneIds.containerApps
