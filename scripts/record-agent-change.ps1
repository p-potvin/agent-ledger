[CmdletBinding()]
param(
    [string]$Project,
    [string]$Kind = 'general',
    [Parameter(Mandatory = $true)]
    [string]$Summary,
    [string[]]$Commands = @(),
    [string[]]$Files = @(),
    [string]$PlanPath,
    [string]$Actor = $env:AGENT_NAME,
    [string]$AgentRole = 'main',
    [string]$Model = 'unknown',
    [string]$Thinking = 'unknown',
    [string]$Mode = 'unknown',
    [string]$Permissions = 'unknown',
    [string]$Network = 'unknown',
    [string[]]$ToolsUsed = @(),
    [string[]]$McpServersAccessed = @(),
    [hashtable]$Flags = @{},
    [object]$Metrics = $null,
    [string]$WorkspaceRoot,
    # AI agents sometimes hallucinate parameters — accept and ignore them
    [switch]$Public,
    [Parameter(ValueFromRemainingArguments)]
    [object[]]$_Overflow
)

$ErrorActionPreference = 'Stop'

function Limit-Tokenish {
    param([string]$Text, [int]$Limit = 256)
    $parts = ($Text -split '\s+') | Where-Object { $_ }
    if ($parts.Count -le $Limit) {
        return $Text.Trim()
    }

    return (($parts | Select-Object -First $Limit) -join ' ').Trim()
}

function Get-Sha256 {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

function Get-Slug {
    param([string]$Text)
    $slug = ($Text.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return 'general'
    }
    if ($slug.Length -gt 48) {
        return $slug.Substring(0, 48).Trim('-')
    }
    return $slug
}

function Get-GitInfo {
    try {
        $top = (& git rev-parse --show-toplevel 2>$null)
        if (-not $top) { return $null }

        $branch = (& git -C $top branch --show-current 2>$null)
        $head = (& git -C $top rev-parse --short HEAD 2>$null)
        $status = (& git -C $top status --short 2>$null)

        return [ordered]@{
            repo = Split-Path $top -Leaf
            root = $top
            branch = $branch
            head = $head
            hasChanges = [bool]$status
        }
    }
    catch {
        return $null
    }
}

function ConvertTo-SnakeCaseKey {
    param([AllowNull()][string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return '' }

    $k = $Key.Trim()
    # Insert underscores on camelCase/PascalCase boundaries.
    $k = ($k -creplace '([a-z0-9])([A-Z])', '$1_$2')
    # Normalize separators to underscores.
    $k = ($k -replace '[^a-zA-Z0-9_]+', '_')
    # Collapse repeats.
    while ($k -match '__') { $k = ($k -replace '__', '_') }
    $k = $k.Trim('_')
    return $k.ToLowerInvariant()
}

function Normalize-ObjectKeysToSnakeCase {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }

    if ($Value -is [hashtable]) {
        $out = [ordered]@{}
        foreach ($k in $Value.Keys) {
            $nk = ConvertTo-SnakeCaseKey ([string]$k)
            if (-not [string]::IsNullOrWhiteSpace($nk)) {
                $out[$nk] = $Value[$k]
            }
        }
        return $out
    }

    # PSCustomObject / ordered dictionaries (including ConvertFrom-Json results)
    if ($Value.PSObject -and $Value.PSObject.Properties -and $Value.PSObject.Properties.Count -gt 0) {
        $out = [ordered]@{}
        foreach ($p in $Value.PSObject.Properties) {
            $nk = ConvertTo-SnakeCaseKey ([string]$p.Name)
            if (-not [string]::IsNullOrWhiteSpace($nk)) {
                $out[$nk] = $p.Value
            }
        }
        return $out
    }

    return $Value
}

function Get-DedupedList {
    param([string[]]$Items)
    $seen = @{}
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Items) {
        $clean = "$item".Trim()
        if ([string]::IsNullOrWhiteSpace($clean)) { continue }
        $key = $clean.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $result.Add($clean)
        }
    }
    return @($result)
}

function Publish-AgentLedgerEventToApi {
    param([object]$Event)

    if ($env:VW_AGENT_LEDGER_API_SYNC -eq '0') { return }

    $apiBase = $env:VW_API_URL
    if (-not $apiBase) { $apiBase = $env:VW_PIPELINES_URL }
    if (-not $apiBase) { $apiBase = 'http://100.67.25.118:9001' }
    if ($apiBase -like 'https://100.67.25.118*') {
        $apiBase = $apiBase -replace 'https://', 'http://'
    }
    $apiBase = $apiBase.TrimEnd('/')

    $apiKey = $env:VW_TELEMETRY_API_KEY
    if (-not $apiKey) { $apiKey = $env:VW_PIPELINES_API_KEY }

    $headers = @{ Accept = 'application/json' }
    if ($apiKey) { $headers['x-api-key'] = $apiKey }

    try {
        $body = $Event | ConvertTo-Json -Depth 20 -Compress
        Invoke-RestMethod `
            -Method Post `
            -Uri "$apiBase/api/ledger/agent/events" `
            -Headers $headers `
            -ContentType 'application/json' `
            -Body $body `
            -TimeoutSec 8 `
            -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Recorded local ledger event, but API sync failed: $($_.Exception.Message)"
    }
}

$ledgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Split-Path $ledgerRoot -Parent
}

. (Join-Path $PSScriptRoot 'resolve-project-alias.ps1')
$aliasMapPath = Join-Path $ledgerRoot 'project-aliases.json'

$git = Get-GitInfo
if (-not $Project) {
    if ($git -and $git.repo) {
        $Project = $git.repo
    }
    else {
        $Project = 'General Tasks'
    }
}

$Project = Resolve-ProjectAlias -Project $Project -AliasMapPath $aliasMapPath

if ($Project -eq 'health-ledger') {
    $eventsRoot = Join-Path $WorkspaceRoot 'health-ledger\events'
} else {
    $eventsRoot = Join-Path $ledgerRoot 'events'
}
New-Item -ItemType Directory -Path $eventsRoot -Force | Out-Null

# Multi-kind normalization: split, dedupe, sort for stable hash; keep unknown values verbatim
$rawParts = ($Kind -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($rawParts.Count -eq 0) { $rawParts = @('general') }
$normalizedKind = ($rawParts | Sort-Object -Unique) -join ','
$Kind = $normalizedKind

$allowed = @('plan','commands','code-change','verification','handoff','general')
$unknown = $rawParts | Where-Object { $_ -notin $allowed }
if ($unknown.Count -gt 0) {
    Write-Warning "Unknown kind(s) accepted but will aggregate under 'general': $($unknown -join ', ')"
}

if (-not $Actor) {
    $Actor = 'AI Agent'
}

$dedupedToolsUsed = Get-DedupedList $ToolsUsed
$dedupedMcpServersAccessed = Get-DedupedList $McpServersAccessed
$normalizedFlags = Normalize-ObjectKeysToSnakeCase $Flags
$normalizedMetrics = Normalize-ObjectKeysToSnakeCase $Metrics

$limitedSummary = Limit-Tokenish $Summary 256
$now = Get-Date
$createdAt = $now.ToUniversalTime().ToString('o')
$createdAtLocal = $now.ToString('yyyy-MM-dd HH:mm')
$timezone = [System.TimeZoneInfo]::Local.Id

$branchForHeader = if ($git -and $git.branch) { $git.branch } else { 'n/a' }
$toolsForHeader = if ($dedupedToolsUsed.Count -gt 0) { $dedupedToolsUsed -join ', ' } else { 'none' }
$mcpForHeader = if ($dedupedMcpServersAccessed.Count -gt 0) { $dedupedMcpServersAccessed -join ', ' } else { 'none' }
$agentHeader = @(
    "Agent: $Actor (role: $AgentRole)"
    "Model: $Model"
    "Thinking: $Thinking"
    "Mode: $Mode"
    "Permissions: $Permissions (network: $Network)"
    "CWD: $((Get-Location).Path)  Branch: $branchForHeader"
    "Tools used (this reply): $toolsForHeader"
    "MCP servers accessed (this reply): $mcpForHeader"
    "Time: $createdAtLocal (TZ: $timezone)"
) -join [Environment]::NewLine

$fingerprintSource = [ordered]@{
    project = $Project
    kind = $Kind
    summary = $limitedSummary
    commands = $Commands
    files = $Files
    planPath = $PlanPath
    flags = $normalizedFlags
    metrics = $normalizedMetrics
} | ConvertTo-Json -Depth 8 -Compress
$contentHash = Get-Sha256 $fingerprintSource

$existing = Get-ChildItem -Path $eventsRoot -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue |
    Select-String -Pattern $contentHash -SimpleMatch -List -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($existing) {
    & (Join-Path $PSScriptRoot 'render-agent-ledger.ps1') | Out-Null
    Write-Output "Duplicate ledger event already exists: $($existing.Path)"
    exit 0
}

$monthRoot = Join-Path $eventsRoot (Join-Path $now.ToString('yyyy') $now.ToString('MM'))
New-Item -ItemType Directory -Path $monthRoot -Force | Out-Null

$id = "$($now.ToString('yyyyMMdd-HHmmss-fff'))-$(Get-Slug $Project)-$($contentHash.Substring(0, 8))"
$eventPath = Join-Path $monthRoot "$id.json"

$event = [ordered]@{
    id = $id
    createdAt = $createdAt
    createdAtLocal = $createdAtLocal
    timezone = $timezone
    project = $Project
    kind = $Kind
    actor = $Actor
    agentHeader = $agentHeader
    runtime = [ordered]@{
        role = $AgentRole
        model = $Model
        thinking = $Thinking
        mode = $Mode
        permissions = $Permissions
        network = $Network
        toolsUsed = $dedupedToolsUsed
        mcpServersAccessed = $dedupedMcpServersAccessed
    }
    telemetry = [ordered]@{
        flags = $normalizedFlags
        metrics = $normalizedMetrics
    }
    workspaceRoot = $WorkspaceRoot
    cwd = (Get-Location).Path
    summary = $limitedSummary
    commands = $Commands
    files = $Files
    planPath = $PlanPath
    contentHash = $contentHash
    git = $git
}

$event | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $eventPath -Encoding utf8
Publish-AgentLedgerEventToApi -Event $event
& (Join-Path $PSScriptRoot 'render-agent-ledger.ps1') | Out-Null

Write-Output "Recorded ledger event: $eventPath"




