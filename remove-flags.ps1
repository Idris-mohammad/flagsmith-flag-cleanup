# remove-flags.ps1
# Archives approved flags. Dry run by default. Add -Apply to make changes.
# Re-checks every flag against live Flagsmith state before acting.
# Archives instead of deleting, so every change can be undone.

param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

# 1. Load the approved list from approve-flags.ps1
if (-not (Test-Path "approved-flags.json")) {
    Write-Host "approved-flags.json not found. Run approve-flags.ps1 first."
    exit 1
}
$raw = Get-Content -Path "approved-flags.json" -Raw
if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Trim() -eq "[]") {
    Write-Host "Nothing approved. No changes made."
    exit 0
}
$approved = ConvertFrom-Json -InputObject $raw
if ($approved -isnot [array]) { $approved = @($approved) }

# 2. Which features are active (not archived)?
$activeNames = @(flagsmith feature list | ForEach-Object { ($_.Trim() -split '\s+')[0] })

# 3. Get live state for every flag
$liveRaw = (flagsmith flag list --json) -join "`n"
$live = ConvertFrom-Json -InputObject $liveRaw
if ($live -isnot [array]) { $live = @($live) }

# 4. Re-check each approved flag. Approval alone is not enough.
$plan = @()
foreach ($a in $approved) {
    $flag      = $live | Where-Object { $_.feature -eq $a.feature } | Select-Object -First 1
    $liveState = "-"
    $overrides = "-"
    $codeRefs  = "-"

    if ($activeNames -notcontains $a.feature) {
        $action = "SKIP: already archived"
    }
    elseif (-not $flag) {
        $action = "SKIP: not in live flag list"
    }
    else {
        $liveState = if ($flag.enabled) { "fully on" } else { "fully off" }
        $overrides = [int]$flag.segment_overrides + [int]$flag.identity_overrides
        $codeRefs  = [int]$flag.code_references

        if ($liveState -ne $a.state) {
            $action = "SKIP: state changed since approval"
        }
        elseif ($overrides -gt 0) {
            $action = "SKIP: has overrides"
        }
        elseif ($codeRefs -gt 0) {
            $action = "SKIP: still used in code"
        }
        else {
            $action = "ARCHIVE"
        }
    }

    $plan += [PSCustomObject]@{
        feature   = $a.feature
        state     = $liveState
        overrides = $overrides
        code_refs = $codeRefs
        action    = $action
    }
}

# 5. Show the evidence table
Write-Host ""
$plan | Format-Table -AutoSize

$toArchive = @($plan | Where-Object { $_.action -eq "ARCHIVE" })
Write-Host "Will archive: $($toArchive.Count)    Skipped: $($plan.Count - $toArchive.Count)"

if (-not $Apply) {
    Write-Host ""
    Write-Host "DRY RUN: no changes made. Re-run with -Apply to archive."
    exit 0
}

# 6. Archive (reversible) and log each result
foreach ($item in $toArchive) {
    flagsmith feature update $item.feature --archive --yes
    if ($LASTEXITCODE -eq 0) { $result = "ARCHIVED" } else { $result = "FAILED (exit $LASTEXITCODE)" }
    $line = "$(Get-Date -Format s)  $($item.feature)  $result"
    Write-Host $line
    Add-Content -Path "removal-log.txt" -Value $line
}

Write-Host ""
Write-Host "To undo: flagsmith feature update <name> --unarchive --yes"