<#
.SYNOPSIS
    Drains unsent spool files from the input-tracker spool directory.
    Reads each *.jsonl file (excluding *.sent), posts batches line-by-line
    to the vaultwares-api, and renames successfully sent files to .sent.

.DESCRIPTION
    Designed to run as a daily scheduled task. Each line in a spool file is
    a single JSON batch object. The script posts each batch to
    POST /api/telemetry/input/batches. If all batches in a file succeed,
    the file is renamed to *.jsonl.sent. Partial failures leave the file
    in place for the next run.
#>
[CmdletBinding()]
param(
    [string]$SpoolDir = (Join-Path $PSScriptRoot "..\input-spool"),
    [string]$LogDir   = (Join-Path $PSScriptRoot "..\input-state")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$apiUrl = [Environment]::GetEnvironmentVariable("VW_API_URL", "User")
if (-not $apiUrl) { $apiUrl = [Environment]::GetEnvironmentVariable("VW_PIPELINES_URL", "User") }
if (-not $apiUrl) { $apiUrl = "https://api.vaultwares.ca" }

$apiKey = [Environment]::GetEnvironmentVariable("VW_TELEMETRY_API_KEY", "User")
if (-not $apiKey) { $apiKey = [Environment]::GetEnvironmentVariable("VW_PIPELINES_API_KEY", "User") }

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$logPath = Join-Path $LogDir ("spool-drain-{0}.log" -f (Get-Date -Format "yyyyMMdd"))

function Write-DrainLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"), $Message
    Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host $line
}

$spoolPath = Resolve-Path $SpoolDir -ErrorAction SilentlyContinue
if (-not $spoolPath) {
    Write-DrainLog "Spool directory not found: $SpoolDir — nothing to drain."
    exit 0
}

$files = @(Get-ChildItem -Path $spoolPath.Path -Filter "*.jsonl" -File | Where-Object { $_.Extension -eq ".jsonl" } | Sort-Object Name)
if ($files.Count -eq 0) {
    Write-DrainLog "No unsent spool files found."
    exit 0
}

Write-DrainLog "Found $($files.Count) unsent spool file(s). API: $apiUrl"

$totalBatches = 0
$totalSent    = 0
$totalErrors  = 0

foreach ($file in $files) {
    $lines = @(Get-Content -Path $file.FullName -Encoding UTF8 | Where-Object { $_.Trim() })
    $fileBatches = $lines.Count
    $fileSent    = 0
    $fileErrors  = 0
    Write-DrainLog "Processing $($file.Name): $fileBatches batch(es), $([math]::Round($file.Length / 1KB, 1)) KB"

    foreach ($line in $lines) {
        $body = $line.Trim()
        if (-not $body) { continue }
        $totalBatches++
        try {
            $headers = @{
                "Content-Type" = "application/json"
                "User-Agent"   = "agent-ledger-spool-drain/1"
            }
            if ($apiKey) { $headers["x-api-key"] = $apiKey }

            $response = Invoke-RestMethod -Uri "$apiUrl/api/telemetry/input/batches" `
                -Method Post -Body $body -Headers $headers -ContentType "application/json" `
                -TimeoutSec 10 -ErrorAction Stop
            $fileSent++
            $totalSent++
        }
        catch {
            $fileErrors++
            $totalErrors++
            $status = $_.Exception.Response.StatusCode.value__
            Write-DrainLog "  ERROR batch in $($file.Name): status=$status  msg=$($_.Exception.Message)"
            break
        }
    }

    if ($fileErrors -eq 0 -and $fileSent -gt 0) {
        $sentPath = "$($file.FullName).sent"
        Move-Item -Path $file.FullName -Destination $sentPath -Force
        Write-DrainLog "  Sent $fileSent/$fileBatches batch(es). Renamed to $($file.Name).sent"
    }
    elseif ($fileErrors -gt 0) {
        Write-DrainLog "  Partial: $fileSent sent, $fileErrors errors. File left for retry."
    }
    else {
        Write-DrainLog "  No batches to send (empty file). Renaming to .sent"
        Move-Item -Path $file.FullName -Destination "$($file.FullName).sent" -Force
    }
}

Write-DrainLog "Done. Batches: $totalBatches total, $totalSent sent, $totalErrors errors."
exit $(if ($totalErrors -gt 0) { 1 } else { 0 })
