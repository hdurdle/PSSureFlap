#Requires -Version 7.0

<#
.SYNOPSIS
    Lists the SureFlap households on the account.

.DESCRIPTION
    Returns each household with its users, timezone and children (GET /api/household).
    Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER ExcludeHouseholdID
    A household to leave out, e.g. one you've been invited to but don't manage.
    Get-SureFlapPet.ps1 and Get-SureFlapTimeline.ps1 take the same parameter.

.EXAMPLE
    .\Get-SureFlapHousehold.ps1 | Select-Object id, name

.EXAMPLE
    .\Get-SureFlapHousehold.ps1 -ExcludeHouseholdID 12345
#>
[CmdletBinding()]
param(
    [int]$ExcludeHouseholdID
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

Invoke-SureFlapApi -Path '/api/household?with[]=household&with[]=pet&with[]=users&with[]=timezone&with[]=children' |
    Where-Object { -not $ExcludeHouseholdID -or $_.id -ne $ExcludeHouseholdID }
