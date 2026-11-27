# approve-flags.ps1
# Asks yes/no for each removal candidate. Saves only approved flags. Deletes nothing.

$ErrorActionPreference = "Stop"

if (-not (Test-Path "stale-candidates.json")) {
    Write-Host "stale-candidates.json not found. Run find-stale-flags.ps1 first."
    exit 1
}

$raw = Get-Content -Path "stale-candidates.json" -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Host "No candidates to review."
    exit 0
}

$candidates = ConvertFrom-Json -InputObject $raw
if ($candidates -isnot [array]) { $candidates = @($candidates) }

$approved = @()
$index = 0
foreach ($c in $candidates) {
    $index++
    Write-Host ""
    Write-Host "[$index/$($candidates.Count)] $($c.feature)  ($($c.state), code references: $($c.code_references))"
    $answer = Read-Host "Approve removal? (y/n, Enter = no)"
    if ($answer -match '^[yY]') {
        $approved += $c
        Write-Host "  Approved"
    } else {
        Write-Host "  Skipped"
    }
}

Write-Host ""
Write-Host "Approved: $($approved.Count) of $($candidates.Count)"

if ($approved.Count -eq 0) {
    "[]" | Set-Content -Path "approved-flags.json" -Encoding UTF8
} else {
    ConvertTo-Json -InputObject @($approved) | Set-Content -Path "approved-flags.json" -Encoding UTF8
}
Write-Host "Saved to approved-flags.json"