targetScope = 'resourceGroup'

@description('Name of the private endpoint.')
param name string

@description('Azure region.')
param location string

@description('Tags applied to all resources.')
param tags object = {}

@description('Resource ID of the subnet to place the private endpoint in.')
param subnetResourceId string

@description('Private link service connections array.')
param privateLinkServiceConnections array

@description('Private DNS zone group configuration. Leave empty to skip DNS registration.')
param privateDnsZoneGroup object = {}

resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
	name: name
	location: location
	tags: tags
	properties: {
		subnet: {
			id: subnetResourceId
		}
		privateLinkServiceConnections: privateLinkServiceConnections
	}
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(privateDnsZoneGroup)) {
	parent: pe
	name: privateDnsZoneGroup.name
	properties: {
		privateDnsZoneConfigs: [
			for config in privateDnsZoneGroup.privateDnsZoneGroupConfigs: {
				name: config.name
				properties: {
					privateDnsZoneId: config.privateDnsZoneResourceId
				}
			}
		]
	}
}

output id string = pe.id
output name string = pe.name
