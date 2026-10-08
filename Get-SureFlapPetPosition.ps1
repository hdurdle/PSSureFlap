#Requires -Version 7.0

<#
.SYNOPSIS
    Shows whether one pet is inside or outside, and since when.

.DESCRIPTION
    Reads the pet's last known position (GET /api/pet/{id}?with[]=position).
    Location is Unknown for a pet that has never used a flap. For every pet,
    with your own room names, use Get-SureFlapPetLocation.ps1. Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER PetID
    SureFlap pet ID (the id column from Get-SureFlapPet.ps1).

.EXAMPLE
    .\Get-SureFlapPetPosition.ps1 -PetID 12345

.EXAMPLE
    (.\Get-SureFlapPetPosition.ps1 12345).Location
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$PetID
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

# GET /api/pet/{id}/position returns 405, so read the position from the pet itself.
$pet = Invoke-SureFlapApi -Path "/api/pet/$($PetID)?with[]=position"

# Strict mode throws on a missing property, and the API leaves properties out rather than sending null.
function Get-OptionalValue($Object, [string]$Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { $Object.$Name }
}
$position = Get-OptionalValue $pet 'position'

[pscustomobject]@{
    Name     = $pet.name
    PetID    = $pet.id
    # where: 1 = inside, 2 = outside
    Location = switch ([int](Get-OptionalValue $position 'where')) { 1 { 'Inside' } 2 { 'Outside' } default { 'Unknown' } }
    Since    = Get-OptionalValue $position 'since'
    # No device_id when the position was set by hand in the app.
    DeviceID = Get-OptionalValue $position 'device_id'
}
