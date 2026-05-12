// ============================================================================
// Constants module — single source of truth for abbreviations, roles, and
// other look-up data shared across the landing-zone template.
//
// Usage in main.bicep / sub-modules:
//   import * as const from 'constants/constants.bicep'
//   param vnetName string = '${const.abbrs.networking.virtualNetwork}${baseName}'
// ============================================================================

// Azure resource naming abbreviations (CAF-aligned)
@export()
var abbrs = loadJsonContent('abbreviations.json')

// Azure built-in role definition GUIDs
@export()
var roles = loadJsonContent('roles.json')
