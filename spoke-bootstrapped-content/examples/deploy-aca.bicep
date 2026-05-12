targetScope = 'resourceGroup'

// Example: Deploy a Container App into an existing AI Landing Zone.
//
// This template assumes the shared Container Apps Environment has already been
// deployed by ../IaC/main.bicep. It creates the Container App and attaches the
// existing workload user-assigned managed identity created by the workload IaC.
// Resource access remains owned by the workload/platform RBAC flow.

import * as const from '../IaC/constants/constants.bicep'

param baseName string = 'ai-lz'
param appName string = ''
param location string = resourceGroup().location
param tags object = {}
param serviceName string = 'frontend'
param containerAppName string = ''
param userAssignedIdentityName string = ''
param userAssignedIdentityResourceId string = ''
param image string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param external bool = false
param targetPort int = 8080
param minReplicas int = 0
param maxReplicas int = 1
param cpu string = '0.5'
param memory string = '1.0Gi'

var _effectiveAppName = empty(appName) ? baseName : appName
var _containerAppName = empty(containerAppName) ? '${const.abbrs.containers.containerApp}${baseName}-${serviceName}' : containerAppName
var _defaultUserAssignedIdentityName = toLower(replace('uami-${baseName}-${_effectiveAppName}-workload', '_', '-'))
var _userAssignedIdentityResourceIdSegments = split(userAssignedIdentityResourceId, '/')
var _userAssignedIdentitySubscriptionId = empty(userAssignedIdentityResourceId) ? subscription().subscriptionId : _userAssignedIdentityResourceIdSegments[2]
var _userAssignedIdentityResourceGroupName = empty(userAssignedIdentityResourceId) ? resourceGroup().name : _userAssignedIdentityResourceIdSegments[4]
var _userAssignedIdentityName = empty(userAssignedIdentityResourceId) ? (empty(userAssignedIdentityName) ? _defaultUserAssignedIdentityName : userAssignedIdentityName) : last(_userAssignedIdentityResourceIdSegments)

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
	name: _userAssignedIdentityName
	scope: resourceGroup(_userAssignedIdentitySubscriptionId, _userAssignedIdentityResourceGroupName)
}

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
	name: '${const.abbrs.containers.containerAppsEnvironment}${baseName}'
}

module containerApp 'br/public:avm/res/app/container-app:0.18.1' = {
	params: {
		name: _containerAppName
		location: location
		environmentResourceId: containerEnv.id
		ingressExternal: external
		ingressTargetPort: targetPort
		ingressTransport: 'auto'
		ingressAllowInsecure: false
		dapr: {
			enabled: true
			appId: serviceName
			appPort: targetPort
			appProtocol: 'http'
		}
		managedIdentities: {
			userAssignedResourceIds: [empty(userAssignedIdentityResourceId) ? userAssignedIdentity.id : userAssignedIdentityResourceId]
		}
		scaleSettings: {
			minReplicas: minReplicas
			maxReplicas: maxReplicas
		}
		containers: [
			{
				name: serviceName
				image: image
				resources: {
					cpu: cpu
					memory: memory
				}
			}
		]
		tags: union(tags, {
			'azd-service-name': serviceName
		})
	}
}

// Permissions for this identity are assigned by ../IaC/main.bicep and the platform/onboarding RBAC flow.

output name string = _containerAppName
output resourceId string = containerApp.outputs.resourceId
output userAssignedIdentityResourceId string = empty(userAssignedIdentityResourceId) ? userAssignedIdentity.id : userAssignedIdentityResourceId
output userAssignedIdentityClientId string = userAssignedIdentity.properties.clientId
output userAssignedIdentityPrincipalId string = userAssignedIdentity.properties.principalId

