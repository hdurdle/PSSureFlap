#Requires -Version 7.0

<#
.SYNOPSIS
    Marks a pet as inside or outside. Changes state - dry-run by default; pass -Execute to apply.

.DESCRIPTION
    Sets the pet's position the way the app's inside/outside button does
    (POST /api/pet/{id}/position), stamped with the current time in UTC. The
    flaps overwrite it the next time the pet goes through one.

    Looks the pet up first and shows its current position and what would
    change. Changes nothing until -Execute is passed. To undo, run it again
    with the other -Where value.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER PetID
    SureFlap pet ID (the id column from Get-SureFlapPet.ps1).

.PARAMETER Where
    Inside or Outside. The API's own values 1 (inside) and 2 (outside) also work.

.PARAMETER Execute
    Actually apply the change. Without it the script only previews.

.EXAMPLE
    .\Set-SureFlapPetPosition.ps1 -PetID 12345 -Where Outside
    Shows the pet's current position and what would change.

.EXAMPLE
    .\Set-SureFlapPetPosition.ps1 -PetID 12345 -Where Inside -Execute
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$PetID,
    [Parameter(Mandatory)][ValidateSet('Inside', 'Outside', '1', '2')][string]$Where,
    [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

$whereNames = @{ 1 = 'Inside'; 2 = 'Outside' }
$whereValue = if ($Where -in 'Inside', '1') { 1 } else { 2 }

# Find the pet first, so a wrong ID fails here rather than at the POST.
$pet = foreach ($household in (Invoke-SureFlapApi -Path "/api/household")) {
    (Invoke-SureFlapApi -Path "/api/household/$($household.id)/pet?with[]=position") |
        Where-Object { $_.id -eq $PetID }
}
if (-not $pet) { throw "No pet with ID $PetID in any household on this account." }

$current = if ($pet.PSObject.Properties['position'] -and $pet.position) {
    '{0} since {1:yyyy-MM-dd HH:mm}' -f $whereNames[[int]$pet.position.where], $pet.position.since
} else { 'unknown' }
$target = "$($pet.name) (pet $PetID)"

Write-Host "Set position of $target"
Write-Host "  current: $current"
Write-Host "  new:     $($whereNames[$whereValue])"

if (-not $Execute) {
    Write-Host 'DRY-RUN. Re-run with -Execute to apply.' -ForegroundColor Magenta
    return
}

if (-not $PSCmdlet.ShouldProcess($target, "Set position to $($whereNames[$whereValue])")) { return }

$body = @{
    where = $whereValue
    since = [datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')
}
$res = Invoke-SureFlapApi -Method Post -Path "/api/pet/$PetID/position" -Body $body
Write-Host "$([datetime]::Now.ToString('s'))  Set position  $target -> $($whereNames[$whereValue])" -ForegroundColor Green
$res
