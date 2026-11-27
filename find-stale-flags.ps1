# find-stale-flags.ps1
# Read-only: finds flags with no overrides (fully on or fully off for everyone).
# Saves the candidates to stale-candidates.json. Deletes nothing.

$ErrorActionPreference = "Stop"

# 1. Get every flag from the Flagsmith CLI as JSON
$raw = (flagsmith flag list --json) -join "`n"
$flags = ConvertFrom-Json -InputObject $raw
if ($flags -isnot [array]) { $flags = @($flags) }

# 2. A flag with no segment or identity overrides is fully rolled out
$candidates = @()
foreach ($flag in $flags) {
    $hasOverrides = ($flag.segment_overrides -gt 0) -or ($flag.identity_overrides -gt 0)
    if (-not $hasOverrides) {
        $state = if ($flag.enabled) { "fully on" } else { "fully off" }
        $candidates += [PSCustomObject]@{
            feature         = $flag.feature
            state           = $state
            code_references = $flag.code_references
        }
    }
}

# 3. Print a summary
Write-Host ""
Write-Host "Flags found:        $($flags.Count)"
Write-Host "Removal candidates: $($candidates.Count)"
Write-Host ""

if ($candidates.Count -gt 0) {
    $candidates | Format-Table -AutoSize
}

# 4. Save candidates for the approval step (step 3)
$candidates | ConvertTo-Json | Set-Content -Path "stale-candidates.json" -Encoding UTF8
Write-Host "Saved to stale-candidates.json"