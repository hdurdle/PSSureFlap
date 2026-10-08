#Requires -Version 7.0

<#
.SYNOPSIS
    Lists the pets in one or every SureFlap household.

.DESCRIPTION
    Returns each pet with its photo, microchip tag and last known position
    (GET /api/household/{id}/pet). Pets that have never used a flap have no
    position property. Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER HouseholdID
    Household to list. Defaults to every household from Get-SureFlapHousehold.ps1.

.PARAMETER ExcludeHouseholdID
    When -HouseholdID isn't given, leave this household out.

.EXAMPLE
    .\Get-SureFlapPet.ps1 | Select-Object id, name, tag_id

.EXAMPLE
    .\Get-SureFlapPet.ps1 -HouseholdID 12345
#>
[CmdletBinding()]
param(
    [ValidateRange(1, [int]::MaxValue)][int]$HouseholdID,
    [int]$ExcludeHouseholdID
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

$householdIDs = if ($HouseholdID) { $HouseholdID } else { & "$PSScriptRoot/Get-SureFlapHousehold.ps1" -ExcludeHouseholdID $ExcludeHouseholdID | ForEach-Object { $_.id } }

foreach ($id in $householdIDs) {
    Invoke-SureFlapApi -Path "/api/household/$id/pet?with[]=photo&with[]=tag&with[]=position"
}
