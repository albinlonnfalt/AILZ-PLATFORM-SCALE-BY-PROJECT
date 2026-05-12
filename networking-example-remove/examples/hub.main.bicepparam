using '../modules/hub/main.bicep'

param baseName = 'hub'
param location = 'swedencentral'
param tags = {
  workload: 'hub-network'
  role: 'hub-network'
}

param hubVnetAddressPrefixes = [
  '10.0.0.0/16'
]
param bastionSubnetPrefix = '10.0.0.0/26'
param managementSubnetPrefix = '10.0.1.0/24'
param deployPrivateEndpointSubnet = false
param privateEndpointSubnetPrefix = '10.0.2.0/24'

param adminUsername = 'azureadmin'
param adminPassword = readEnvironmentVariable('HUB_JUMP_ADMIN_PASSWORD', 'Replace-With-Strong-Password-123!')
param vmSize = 'Standard_D2s_v5'
param bastionSku = 'Basic'

param includeAssociatedResources = true
param deployAcr = true
param deployAppConfig = true
param deployGenaiCosmos = true
param deployGenaiSearch = true
param deployGenaiStorage = true
param deployGenaiKeyVault = true
param deployContainerApps = true
