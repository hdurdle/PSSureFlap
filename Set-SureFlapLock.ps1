#Requires -Version 7.0

<#
.SYNOPSIS
    Locks or unlocks a flap. Changes state - dry-run by default; pass -Execute to apply.

.DESCRIPTION
    Sets the flap's lock mode the way the app's lock buttons do
    (PUT /api/device/{flap}/control with { locking = n }):

        Unlocked  0  pets go both ways
        KeepIn    1  pets can come in but not go out
        KeepOut   2  pets can go out but not come in
        Locked    3  locked both ways

    This applies to every pet. To keep one pet in, use Set-SureFlapPetPermission.ps1.

    Looks the flap up first and shows its current mode and what would change.
    Changes nothing until -Execute is passed. To undo, run it again with the
    previous -Mode shown in the preview. The hub passes the change on to the flap,
    so the flap's reported mode can lag a few seconds behind; -Execute waits up to
    -TimeoutSeconds for it to match.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER FlapID
    Device ID of the flap. List them with:
    .\Get-SureFlapDevice.ps1 | Where-Object product_id -in 3, 6 | Select-Object id, name

.PARAMETER Mode
    Unlocked, KeepIn, KeepOut or Locked. The API's own values 0-3 also work.

.PARAMETER TimeoutSeconds
    How long -Execute waits for the flap to report the new mode. 0 skips the
    wait. Default 30.

.PARAMETER Execute
    Actually apply the change. Without it the script only previews.

.EXAMPLE
    .\Set-SureFlapLock.ps1 -FlapID 123456 -Mode Locked
    Shows the current lock mode and what would change.

.EXAMPLE
    .\Set-SureFlapLock.ps1 -FlapID 123456 -Mode Unlocked -Execute
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$FlapID,
    [Parameter(Mandatory)]
    [ValidateSet('Unlocked', 'KeepIn', 'KeepOut', 'Locked', '0', '1', '2', '3')][string]$Mode,
    [ValidateRange(0, 300)][int]$TimeoutSeconds = 30,
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

# 4 is reported while a curfew is locking the flap; it can't be set directly.
$modeNames = @{ 0 = 'Unlocked'; 1 = 'KeepIn'; 2 = 'KeepOut'; 3 = 'Locked'; 4 = 'Curfew' }
$modeValue = if ($Mode -match '^\d$') { [int]$Mode } else { ($modeNames.GetEnumerator() | Where-Object Value -eq $Mode).Key }

function Get-Flap {
    $device = (Invoke-SureFlapApi -Path "/api/device?with[]=status&with[]=control") |
        Where-Object { $_.id -eq $FlapID }
    if (-not $device) { throw "No device with ID $FlapID on this account." }
    $device
}

$flap = Get-Flap
if ($flap.product_id -notin $SureFlapFlapProducts) {
    $product = $SureFlapProducts[[int]$flap.product_id] ?? "product $($flap.product_id)"
    throw "Device $FlapID ($($flap.name)) is a $product, not a flap."
}

$currentValue = [int]$flap.status.locking.mode
$current = $modeNames[$currentValue] ?? "mode $currentValue"
$target = "$($flap.name) (flap $FlapID)"

Write-Host "Set lock mode of $target"
Write-Host "  current: $current"
Write-Host "  new:     $($modeNames[$modeValue])"
if (@($flap.control.curfew).Count -gt 0) {
    Write-Host '  note:    this flap has a curfew set, which will lock it again at its next start time.' -ForegroundColor Yellow
}

if ($currentValue -eq $modeValue) {
    Write-Host 'Already set; nothing to do.' -ForegroundColor Green
    return
}

if (-not $Execute) {
    Write-Host 'DRY-RUN. Re-run with -Execute to apply.' -ForegroundColor Magenta
    return
}

if (-not $PSCmdlet.ShouldProcess($target, "Set lock mode to $($modeNames[$modeValue])")) { return }

$res = Invoke-SureFlapApi -Method Put -Path "/api/device/$FlapID/control" -Body @{ locking = $modeValue }
Write-Host "$([datetime]::Now.ToString('s'))  Set lock mode  $target -> $($modeNames[$modeValue])" -ForegroundColor Green

if ($TimeoutSeconds -gt 0) {
    $deadline = [datetime]::Now.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds 3
        $reported = [int](Get-Flap).status.locking.mode
    } until ($reported -eq $modeValue -or [datetime]::Now -ge $deadline)
    if ($reported -eq $modeValue) {
        Write-Host "  flap reports $($modeNames[$reported])." -ForegroundColor Green
    } else {
        Write-Warning "Flap still reports $($modeNames[$reported] ?? "mode $reported") after $TimeoutSeconds s. The hub may apply it later; check with Get-SureFlapDevice.ps1."
    }
}
$res
