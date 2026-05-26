# Kind utilities for multi-kind ledger entries.
# Dot-source this file: . "$PSScriptRoot\kind-utils.ps1"

$script:VW_KIND_ENUM = @('plan','commands','code-change','verification','handoff','general')

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
        if ($_ -in $script:VW_KIND_ENUM) { $_ } else { 'general' }
    } | Sort-Object -Unique)
}
