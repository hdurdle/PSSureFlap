#Requires -Version 7.0

<#
.SYNOPSIS
    Returns recent events (pet movements, device alerts) for one or every household.

.DESCRIPTION
    Returns one page of the household timeline, newest first, 25 events per page
    (GET /api/timeline/household/{id}). Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER HouseholdID
    Household to read. Defaults to every household from Get-SureFlapHousehold.ps1.

.PARAMETER ExcludeHouseholdID
    When -HouseholdID isn't given, leave this household out.

.PARAMETER Page
    Page number; 1 (the default) is the most recent 25 events.

.EXAMPLE
    .\Get-SureFlapTimeline.ps1 | Select-Object created_at, type

.EXAMPLE
    .\Get-SureFlapTimeline.ps1 -HouseholdID 12345 -Page 2
#>
[CmdletBinding()]
param(
    [ValidateRange(1, [int]::MaxValue)][int]$HouseholdID,
    [int]$ExcludeHouseholdID,
    [ValidateRange(1, [int]::MaxValue)][int]$Page = 1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

$householdIDs = if ($HouseholdID) { $HouseholdID } else { & "$PSScriptRoot/Get-SureFlapHousehold.ps1" -ExcludeHouseholdID $ExcludeHouseholdID | ForEach-Object { $_.id } }

foreach ($id in $householdIDs) {
    Invoke-SureFlapApi -Path "/api/timeline/household/$($id)?page=$Page"
}
