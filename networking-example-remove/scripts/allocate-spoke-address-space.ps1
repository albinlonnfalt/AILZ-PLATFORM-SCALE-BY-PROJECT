<#
.SYNOPSIS
Allocates the first available spoke address space that does not overlap the hub-connected network.

.DESCRIPTION
This script is designed for Terraform's external data source. It reads a JSON object from stdin,
queries the hub VNet and all VNets directly peered to the hub, and returns Terraform-compatible
JSON with the chosen VNet and subnet prefixes.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Failure {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message
    )

    Write-Error "Spoke address allocation failed: $Message"
    exit 1
}

function Invoke-AzRestJson {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Url
    )

    $json = az rest --method get --url $Url --output json 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Azure REST GET failed for $Url"
    }

    if ([string]::IsNullOrWhiteSpace($json)) {
        return $null
    }

    return $json | ConvertFrom-Json -Depth 100
}

function ConvertTo-Ipv4Integer {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Address
    )

    $bytes = [System.Net.IPAddress]::Parse($Address).GetAddressBytes()
    if ($bytes.Length -ne 4) {
        throw "Only IPv4 addresses are supported: $Address"
    }

    return (([uint64] $bytes[0] -shl 24) -bor ([uint64] $bytes[1] -shl 16) -bor ([uint64] $bytes[2] -shl 8) -bor [uint64] $bytes[3])
}

function ConvertFrom-Ipv4Integer {
    param(
        [Parameter(Mandatory = $true)]
        [uint64] $Value
    )

    return ('{0}.{1}.{2}.{3}' -f (($Value -shr 24) -band 255), (($Value -shr 16) -band 255), (($Value -shr 8) -band 255), ($Value -band 255))
}

function ConvertTo-CidrRange {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prefix
    )

    $parts = $Prefix.Split('/')
    if ($parts.Count -ne 2) {
        throw "Invalid CIDR prefix: $Prefix"
    }

    $prefixLength = [int] $parts[1]
    if ($prefixLength -lt 0 -or $prefixLength -gt 32) {
        throw "Invalid IPv4 prefix length in $Prefix"
    }

    $blockSize = [uint64] [math]::Pow(2, 32 - $prefixLength)
    $start = ConvertTo-Ipv4Integer -Address $parts[0]
    $networkStart = $start - ($start % $blockSize)

    return [pscustomobject]@{
        Prefix = $Prefix
        Start  = $networkStart
        End    = $networkStart + $blockSize - 1
    }
}

function Test-CidrOverlap {
    param(
        [Parameter(Mandatory = $true)]
        [uint64] $FirstStart,

        [Parameter(Mandatory = $true)]
        [uint64] $FirstEnd,

        [Parameter(Mandatory = $true)]
        [uint64] $SecondStart,

        [Parameter(Mandatory = $true)]
        [uint64] $SecondEnd
    )

    return ($FirstStart -le $SecondEnd -and $SecondStart -le $FirstEnd)
}

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) {
        Write-Failure 'Expected Terraform external data source JSON on stdin.'
    }

    $query = $stdin | ConvertFrom-Json -Depth 20

    $hubSubscriptionId = [string] $query.hubSubscriptionId
    $hubResourceGroupName = [string] $query.hubResourceGroupName
    $hubVnetName = [string] $query.hubVnetName
    $hubVnetId = [string] $query.hubVnetId
    $targetSubscriptionId = [string] $query.targetSubscriptionId
    $targetResourceGroupName = [string] $query.targetResourceGroupName
    $targetVnetName = [string] $query.targetVnetName
    $allocationPoolPrefix = if ([string]::IsNullOrWhiteSpace([string] $query.allocationPoolPrefix)) { '10.0.0.0/8' } else { [string] $query.allocationPoolPrefix }
    $spokePrefixLength = if ([string]::IsNullOrWhiteSpace([string] $query.spokePrefixLength)) { 16 } else { [int] $query.spokePrefixLength }

    if ([string]::IsNullOrWhiteSpace($hubSubscriptionId)) {
        Write-Failure 'hubSubscriptionId is required.'
    }
    if ([string]::IsNullOrWhiteSpace($hubResourceGroupName)) {
        Write-Failure 'hubResourceGroupName is required.'
    }
    if ([string]::IsNullOrWhiteSpace($hubVnetName)) {
        Write-Failure 'hubVnetName is required.'
    }
    if ([string]::IsNullOrWhiteSpace($targetSubscriptionId)) {
        Write-Failure 'targetSubscriptionId is required.'
    }
    if ([string]::IsNullOrWhiteSpace($targetResourceGroupName)) {
        Write-Failure 'targetResourceGroupName is required.'
    }
    if ([string]::IsNullOrWhiteSpace($targetVnetName)) {
        Write-Failure 'targetVnetName is required.'
    }
    if ($spokePrefixLength -lt 16 -or $spokePrefixLength -gt 24) {
        Write-Failure 'spokePrefixLength must be between 16 and 24 so the standard spoke subnet layout fits.'
    }

    if ([string]::IsNullOrWhiteSpace($hubVnetId)) {
        $hubVnetId = "/subscriptions/$hubSubscriptionId/resourceGroups/$hubResourceGroupName/providers/Microsoft.Network/virtualNetworks/$hubVnetName"
    }

    $targetVnetId = "/subscriptions/$targetSubscriptionId/resourceGroups/$targetResourceGroupName/providers/Microsoft.Network/virtualNetworks/$targetVnetName"
    $networkApiVersion = '2024-05-01'

    $hubVnet = Invoke-AzRestJson -Url "https://management.azure.com$hubVnetId`?api-version=$networkApiVersion"
    if ($null -eq $hubVnet) {
        Write-Failure "Hub VNet was not found: $hubVnetId"
    }

    $usedPrefixes = [System.Collections.Generic.List[string]]::new()
    foreach ($prefix in @($hubVnet.properties.addressSpace.addressPrefixes)) {
        if (-not [string]::IsNullOrWhiteSpace([string] $prefix)) {
            $usedPrefixes.Add([string] $prefix)
        }
    }

    $peerings = Invoke-AzRestJson -Url "https://management.azure.com$hubVnetId/virtualNetworkPeerings?api-version=$networkApiVersion"
    $targetIsHubPeered = $false

    foreach ($peering in @($peerings.value)) {
        $remoteVnetId = [string] $peering.properties.remoteVirtualNetwork.id
        if ([string]::IsNullOrWhiteSpace($remoteVnetId)) {
            continue
        }

        if ($remoteVnetId.Equals($targetVnetId, [System.StringComparison]::OrdinalIgnoreCase)) {
            $targetIsHubPeered = $true
        }

        $remotePrefixes = @()
        try {
            $remoteVnet = Invoke-AzRestJson -Url "https://management.azure.com$remoteVnetId`?api-version=$networkApiVersion"
            $remotePrefixes = @($remoteVnet.properties.addressSpace.addressPrefixes)
        }
        catch {
            $remotePrefixes = @($peering.properties.remoteAddressSpace.addressPrefixes)
        }

        foreach ($prefix in $remotePrefixes) {
            if (-not [string]::IsNullOrWhiteSpace([string] $prefix)) {
                $usedPrefixes.Add([string] $prefix)
            }
        }
    }

    if ($targetIsHubPeered) {
        $targetVnet = Invoke-AzRestJson -Url "https://management.azure.com$targetVnetId`?api-version=$networkApiVersion"
        $targetPrefix = [string] @($targetVnet.properties.addressSpace.addressPrefixes)[0]
        if (-not [string]::IsNullOrWhiteSpace($targetPrefix)) {
            $selectedPrefix = $targetPrefix
        }
    }

    if ([string]::IsNullOrWhiteSpace($selectedPrefix)) {
        $poolRange = ConvertTo-CidrRange -Prefix $allocationPoolPrefix
        $candidateBlockSize = [uint64] [math]::Pow(2, 32 - $spokePrefixLength)
        $candidateStart = $poolRange.Start
        $remainder = $candidateStart % $candidateBlockSize
        if ($remainder -ne 0) {
            $candidateStart += ($candidateBlockSize - $remainder)
        }

        $usedRanges = foreach ($prefix in ($usedPrefixes | Select-Object -Unique)) {
            ConvertTo-CidrRange -Prefix $prefix
        }

        while (($candidateStart + $candidateBlockSize - 1) -le $poolRange.End) {
            $candidateEnd = $candidateStart + $candidateBlockSize - 1
            $overlaps = $false

            foreach ($range in $usedRanges) {
                if (Test-CidrOverlap -FirstStart $candidateStart -FirstEnd $candidateEnd -SecondStart $range.Start -SecondEnd $range.End) {
                    $overlaps = $true
                    break
                }
            }

            if (-not $overlaps) {
                $selectedPrefix = "$(ConvertFrom-Ipv4Integer -Value $candidateStart)/$spokePrefixLength"
                break
            }

            $candidateStart += $candidateBlockSize
        }
    }

    if ([string]::IsNullOrWhiteSpace($selectedPrefix)) {
        Write-Failure "No available /$spokePrefixLength spoke address space was found in $allocationPoolPrefix. Used prefixes: $($usedPrefixes -join ', ')"
    }

    $selectedRange = ConvertTo-CidrRange -Prefix $selectedPrefix
    $selectedBase = $selectedRange.Start
    $selectedSecondOctet = ($selectedBase -shr 16) -band 255
    $selectedFirstOctet = ($selectedBase -shr 24) -band 255
    $basePrefix = "$selectedFirstOctet.$selectedSecondOctet"
    $usedPrefixesJson = ConvertTo-Json -Compress -InputObject @($usedPrefixes | Select-Object -Unique)

    [ordered]@{
        vnetAddressPrefix              = $selectedPrefix
        privateEndpointsSubnetPrefix   = "$basePrefix.0.0/24"
        aiFoundryAgentSubnetPrefix     = "$basePrefix.1.0/24"
        containerAppsSubnetPrefix      = "$basePrefix.6.0/23"
        targetVnetId                   = $targetVnetId
        targetIsHubPeered              = [string] $targetIsHubPeered
        usedPrefixesJson               = $usedPrefixesJson
    } | ConvertTo-Json -Compress
}
catch {
    Write-Failure $_.Exception.Message
}
