# Project-alias resolver.
# Dot-source this file: . "$PSScriptRoot\resolve-project-alias.ps1"
# Then call: Resolve-ProjectAlias -Project $name -AliasMapPath $path
#
# Note: -AliasMapPath is kept for backwards compatibility with existing scripts,
# but the data is now fetched from the VaultWares API at https://api.vaultwares.ca/
#
# The resolver normalizes any alias to its canonical name so old ledger
# events (frozen audit trail) and freshly-recorded events bucket together in the
# work-impact dashboard. Lookup is case-insensitive.

if (-not (Get-Variable -Name '__ProjectAliasCache' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:__ProjectAliasCache = $null
    $script:__ProjectAliasCacheTime = [DateTime]::MinValue
}

function Get-ProjectAliasMap {
    # Cache for 10 minutes to avoid spamming the API on heavy local script usage
    if ($script:__ProjectAliasCache -and ([DateTime]::UtcNow - $script:__ProjectAliasCacheTime).TotalMinutes -lt 10) {
        return $script:__ProjectAliasCache
    }

    $apiBase = $env:VW_API_URL
    if (-not $apiBase) { $apiBase = $env:VW_PIPELINES_URL }
    if (-not $apiBase) { $apiBase = "https://api.vaultwares.ca" }
    $apiUrl = "$($apiBase.TrimEnd('/'))/projects/aliases"
    $raw = $null
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -TimeoutSec 5
        $raw = $response
    }
    catch {
        Write-Warning "resolve-project-alias: could not fetch aliases from API ($($_.Exception.Message)). Returning empty map."
        return $null
    }

    if (-not $raw) {
        return $null
    }

    $aliasToCanonical = @{}
    $canonicalSet = @{}

    foreach ($entry in $raw) {
        $canonical = [string]$entry.canonical
        if ([string]::IsNullOrWhiteSpace($canonical)) { continue }
        $canonicalSet[$canonical.ToLowerInvariant()] = $canonical

        $aliases = @()
        if ($entry.aliases) { $aliases = @($entry.aliases) }

        foreach ($alias in $aliases) {
            $a = [string]$alias
            if ([string]::IsNullOrWhiteSpace($a)) { continue }
            $aKey = $a.ToLowerInvariant()
            if ($aliasToCanonical.ContainsKey($aKey) -and $aliasToCanonical[$aKey] -ne $canonical) {
                Write-Warning "resolve-project-alias: alias '$a' is claimed by both '$($aliasToCanonical[$aKey])' and '$canonical' from API."
                continue
            }
            $aliasToCanonical[$aKey] = $canonical
        }
    }

    $map = [pscustomobject]@{
        aliasToCanonical = $aliasToCanonical
        canonicalSet = $canonicalSet
        rawData = $raw
    }

    $script:__ProjectAliasCache = $map
    $script:__ProjectAliasCacheTime = [DateTime]::UtcNow
    return $map
}

function Resolve-ProjectAlias {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Project,
        [Parameter(Mandatory = $false)][string]$AliasMapPath # Ignored now, kept for compat
    )

    if ([string]::IsNullOrWhiteSpace($Project)) { return $Project }

    # Erase GitHub namespace prefixes (prom-king/, vaultwares/, p-potvin/, etc.)
    $cleaned = $Project -replace '^(?i)(prom-king|vaultwares|p-potvin)(/|\\)+', ''

    $map = Get-ProjectAliasMap
    if (-not $map) { return $cleaned }

    $key = $cleaned.ToLowerInvariant()

    # Already canonical — return original casing.
    if ($map.canonicalSet.ContainsKey($key)) {
        return $map.canonicalSet[$key]
    }

    if ($map.aliasToCanonical.ContainsKey($key)) {
        return $map.aliasToCanonical[$key]
    }

    return $cleaned
}

function Get-ProjectAliases {
    # Returns the list of historical aliases for a given canonical name. Used by
    # the renderer to print "(formerly X)" suffixes. Empty list if none.
    param(
        [Parameter(Mandatory = $true)][string]$Canonical,
        [Parameter(Mandatory = $false)][string]$AliasMapPath # Ignored now, kept for compat
    )

    if ([string]::IsNullOrWhiteSpace($Canonical)) { return @() }
    
    $map = Get-ProjectAliasMap
    if (-not $map -or -not $map.rawData) { return @() }

    foreach ($entry in $map.rawData) {
        if ([string]$entry.canonical -ieq $Canonical) {
            if ($entry.aliases) { return @($entry.aliases) }
            return @()
        }
    }
    return @()
}
