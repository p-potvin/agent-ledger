# Kind utilities for multi-kind ledger entries.
# Dot-source this file: . "$PSScriptRoot\kind-utils.ps1"

$script:VW_KIND_ENUM = @('plan','commands','code-change','verification','handoff','documentation','general')

# Kind aliases: variations that map to a canonical kind in the enum
$script:VW_KIND_ALIASES = @{
    'docs'              = 'documentation'
    'doc'               = 'documentation'
    'vaultwares-docs'   = 'documentation'
    'documentation'     = 'documentation'
    'docs-change'       = 'documentation'
    'doc-change'        = 'documentation'
}

function Get-KindList {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @('general') }
    $parts = ($Value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($parts.Count -eq 0) { return @('general') }
    return @($parts)
}

function Get-KindListForAggregation {
    param([AllowNull()][string]$Value)
    $parts = Get-KindList $Value
    return @($parts | ForEach-Object {
        $k = $_
        if ($script:VW_KIND_ALIASES.ContainsKey($k)) { $k = $script:VW_KIND_ALIASES[$k] }
        if ($k -in $script:VW_KIND_ENUM) { $k } else { 'general' }
    } | Sort-Object -Unique)
}

function Resolve-KindAlias {
    param([string]$Kind)
    if ($script:VW_KIND_ALIASES.ContainsKey($Kind)) { return $script:VW_KIND_ALIASES[$Kind] }
    return $Kind
}
