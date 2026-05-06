[CmdletBinding()]
param(
    [string]$Project,
    [ValidateSet('plan', 'commands', 'code-change', 'verification', 'handoff', 'general')]
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
    [string]$WorkspaceRoot
)

$ErrorActionPreference = 'Stop'

function Limit-Tokenish {
    param([string]$Text, [int]$Limit = 1024)
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

$ledgerRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Split-Path $ledgerRoot -Parent
}
$eventsRoot = Join-Path $ledgerRoot 'events'
New-Item -ItemType Directory -Path $eventsRoot -Force | Out-Null

$git = Get-GitInfo
if (-not $Project) {
    if ($git -and $git.repo) {
        $Project = $git.repo
    }
    else {
        $Project = 'General Tasks'
    }
}

if (-not $Actor) {
    $Actor = 'AI Agent'
}

$dedupedToolsUsed = Get-DedupedList $ToolsUsed
$dedupedMcpServersAccessed = Get-DedupedList $McpServersAccessed

$limitedSummary = Limit-Tokenish $Summary 1024
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
& (Join-Path $PSScriptRoot 'render-agent-ledger.ps1') | Out-Null

Write-Output "Recorded ledger event: $eventPath"
