#Requires -Version 7.0

<#
.SYNOPSIS
    Sets whether a pet may go out through a flap. Changes state - dry-run by default; pass -Execute to apply.

.DESCRIPTION
    Sets the profile for the pet's microchip tag on one flap
    (PUT /api/device/{flap}/tag/{tag}): AllowOut (profile 2, the normal setting)
    or KeepIn (profile 3, the pet can come in but not go out). If the tag is not
    yet on that flap, this adds it.

    Looks up the pet's tag and the flap's current setting first and shows what
    would change. Changes nothing until -Execute is passed. To undo, run it
    again with the previous -Permission shown in the preview.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER FlapID
    Device ID of the flap. List them with:
    .\Get-SureFlapDevice.ps1 | Where-Object product_id -in 3, 6 | Select-Object id, name

.PARAMETER PetID
    SureFlap pet ID (the id column from Get-SureFlapPet.ps1). The script looks
    up the pet's tag ID, which is what the API needs.

.PARAMETER Permission
    AllowOut or KeepIn. The API's own values 2 (allow out) and 3 (keep in) also
    work. -profile is accepted as an alias.

.PARAMETER Execute
    Actually apply the change. Without it the script only previews.

.EXAMPLE
    .\Set-SureFlapPetPermission.ps1 -FlapID 123456 -PetID 12345 -Permission KeepIn
    Shows the current setting and what would change.

.EXAMPLE
    .\Set-SureFlapPetPermission.ps1 -FlapID 123456 -PetID 12345 -Permission AllowOut -Execute
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$FlapID,
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$PetID,
    [Parameter(Mandatory)][Alias('profile')]
    [ValidateSet('AllowOut', 'KeepIn', '2', '3')][string]$Permission,
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

$profileNames = @{ 2 = 'AllowOut'; 3 = 'KeepIn' }
$profileValue = if ($Permission -in 'AllowOut', '2') { 2 } else { 3 }

$flap = (Invoke-SureFlapApi -Path "/api/device?with[]=tags") |
    Where-Object { $_.id -eq $FlapID }
if (-not $flap) { throw "No device with ID $FlapID on this account." }
if ($flap.product_id -notin $SureFlapFlapProducts) {
    $product = $SureFlapProducts[[int]$flap.product_id] ?? "product $($flap.product_id)"
    throw "Device $FlapID ($($flap.name)) is a $product, not a flap."
}

$pet = (Invoke-SureFlapApi -Path "/api/household/$($flap.household_id)/pet") |
    Where-Object { $_.id -eq $PetID }
if (-not $pet) { throw "No pet with ID $PetID in the household that flap $FlapID belongs to." }
if (-not $pet.tag_id) { throw "Pet $PetID ($($pet.name)) has no microchip tag." }
$tagID = $pet.tag_id

$flapTag = @($flap.tags) | Where-Object { $_ -and $_.id -eq $tagID }
$current = if ($flapTag) { $profileNames[[int]$flapTag.profile] ?? "profile $($flapTag.profile)" } else { 'not on this flap yet' }
$target = "$($pet.name) (pet $PetID, tag $tagID) on $($flap.name) (flap $FlapID)"

Write-Host "Set permission for $target"
Write-Host "  current: $current"
Write-Host "  new:     $($profileNames[$profileValue])"

if ($flapTag -and [int]$flapTag.profile -eq $profileValue) {
    Write-Host 'Already set; nothing to do.' -ForegroundColor Green
    return
}

if (-not $Execute) {
    Write-Host 'DRY-RUN. Re-run with -Execute to apply.' -ForegroundColor Magenta
    return
}

if (-not $PSCmdlet.ShouldProcess($target, "Set permission to $($profileNames[$profileValue])")) { return }

$body = @{ profile = $profileValue }
$res = Invoke-SureFlapApi -Method Put -Path "/api/device/$FlapID/tag/$tagID" -Body $body
Write-Host "$([datetime]::Now.ToString('s'))  Set permission  $target -> $($profileNames[$profileValue])" -ForegroundColor Green
$res
