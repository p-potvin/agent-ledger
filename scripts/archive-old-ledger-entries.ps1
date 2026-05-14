<#
.SYNOPSIS
    Archives agent-ledger event files older than 14 days to the history directory.
    
.DESCRIPTION
    This script maintains the "hot" ledger performance by moving older JSON events 
    to a project-root 'history/' directory. This keeps LLM context windows efficient
    while preserving historical data for deep searching.
    
    Scheduled to run daily.
#>

$ledgerRoot = "C:\Users\Administrator\Desktop\Github Repos\agent-ledger"
$eventsDir = Join-Path $ledgerRoot "events"
$historyDir = Join-Path $ledgerRoot "history"
$thresholdDays = 14
$cutoffDate = (Get-Date).AddDays(-$thresholdDays)

if (-not (Test-Path $historyDir)) {
    New-Item -Path $historyDir -ItemType Directory
}

# Find all JSON files in events/
$filesToArchive = Get-ChildItem -Path $eventsDir -Filter "*.json" -Recurse | Where-Object { $_.LastWriteTime -lt $cutoffDate }

if ($filesToArchive.Count -eq 0) {
    Write-Host "No events older than $thresholdDays days found. Skipping archive."
    exit 0
}

Write-Host "Archiving $($filesToArchive.Count) events..."

foreach ($file in $filesToArchive) {
    # Get relative path from events/ to preserve YYYY/MM structure
    $relativePath = $file.DirectoryName.Replace($eventsDir, "").TrimStart("\")
    $targetDir = Join-Path $historyDir $relativePath
    
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory
    }
    
    $targetPath = Join-Path $targetDir $file.Name
    Move-Item -Path $file.FullName -Destination $targetPath -Force
}

Write-Host "Archive complete."
