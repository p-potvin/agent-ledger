# Project-alias resolver.
# Dot-source this file: . "$PSScriptRoot\resolve-project-alias.ps1"
# Then call: Resolve-ProjectAlias -Project $name -AliasMapPath $path
#
# The map (project-aliases.json) lists each canonical project with its historical
# aliases. The resolver normalizes any alias to its canonical name so old ledger
# events (frozen audit trail) and freshly-recorded events bucket together in the
# work-impact dashboard. Lookup is case-insensitive. Cache is keyed by map path +
# last-write-time so editing the JSON invalidates the cache without restart.

if (-not (Get-Variable -Name '__ProjectAliasCache' -Scope Script -ErrorAction SilentlyContinue)) {
    $script:__ProjectAliasCache = @{}
}

function Get-ProjectAliasMap {
    param(
        [Parameter(Mandatory = $true)][string]$AliasMapPath
    )

    if (-not (Test-Path -LiteralPath $AliasMapPath)) {
        return $null
    }

    $fileInfo = Get-Item -LiteralPath $AliasMapPath
    $cacheKey = "$($fileInfo.FullName)|$($fileInfo.LastWriteTimeUtc.Ticks)"

    if ($script:__ProjectAliasCache.ContainsKey($cacheKey)) {
        return $script:__ProjectAliasCache[$cacheKey]
    }

    $raw = $null
    try {
        $raw = Get-Content -Raw -LiteralPath $AliasMapPath | ConvertFrom-Json
    }
    catch {
        Write-Warning "resolve-project-alias: could not parse '$AliasMapPath' ($($_.Exception.Message)). Returning empty map."
        return $null
    }

    if (-not $raw -or -not $raw.projects) {
        return $null
    }

    $aliasToCanonical = @{}
    $canonicalSet = @{}

    foreach ($entry in $raw.projects) {
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
                throw "resolve-project-alias: alias '$a' is claimed by both '$($aliasToCanonical[$aKey])' and '$canonical' in $AliasMapPath."
            }
            $aliasToCanonical[$aKey] = $canonical
        }
    }

    $map = [pscustomobject]@{
        aliasToCanonical = $aliasToCanonical
        canonicalSet = $canonicalSet
    }

    $script:__ProjectAliasCache[$cacheKey] = $map
    return $map
}

function Resolve-ProjectAlias {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Project,
        [Parameter(Mandatory = $true)][string]$AliasMapPath
    )

    if ([string]::IsNullOrWhiteSpace($Project)) { return $Project }

    $map = Get-ProjectAliasMap -AliasMapPath $AliasMapPath
    if (-not $map) { return $Project }

    $key = $Project.ToLowerInvariant()

    # Already canonical — return original casing.
    if ($map.canonicalSet.ContainsKey($key)) {
        return $map.canonicalSet[$key]
    }

    if ($map.aliasToCanonical.ContainsKey($key)) {
        return $map.aliasToCanonical[$key]
    }

    return $Project
}

function Get-ProjectAliases {
    # Returns the list of historical aliases for a given canonical name. Used by
    # the renderer to print "(formerly X)" suffixes. Empty list if none.
    param(
        [Parameter(Mandatory = $true)][string]$Canonical,
        [Parameter(Mandatory = $true)][string]$AliasMapPath
    )

    if ([string]::IsNullOrWhiteSpace($Canonical)) { return @() }
    if (-not (Test-Path -LiteralPath $AliasMapPath)) { return @() }

    try {
        $raw = Get-Content -Raw -LiteralPath $AliasMapPath | ConvertFrom-Json
    }
    catch {
        return @()
    }
    if (-not $raw -or -not $raw.projects) { return @() }

    foreach ($entry in $raw.projects) {
        if ([string]$entry.canonical -ieq $Canonical) {
            if ($entry.aliases) { return @($entry.aliases) }
            return @()
        }
    }
    return @()
}
