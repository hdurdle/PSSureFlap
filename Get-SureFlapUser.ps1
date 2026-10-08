#Requires -Version 7.0

<#
.SYNOPSIS
    Returns your SureFlap user, another user, or the users in a household.

.DESCRIPTION
    With no parameters, returns the account you are logged in as (GET /api/me).
    -HouseholdID lists that household's users and their permissions;
    -UserID returns one user. Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER HouseholdID
    List the users in this household.

.PARAMETER UserID
    Return this user.

.EXAMPLE
    .\Get-SureFlapUser.ps1

.EXAMPLE
    .\Get-SureFlapUser.ps1 -HouseholdID 12345

.EXAMPLE
    .\Get-SureFlapUser.ps1 -UserID 67890
#>
[CmdletBinding(DefaultParameterSetName = 'Me')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Household', Position = 0)]
    [ValidateRange(1, [int]::MaxValue)][int]$HouseholdID,

    [Parameter(Mandatory, ParameterSetName = 'User')]
    [ValidateRange(1, [int]::MaxValue)][int]$UserID
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

switch ($PSCmdlet.ParameterSetName) {
    'Household' { Invoke-SureFlapApi -Path "/api/household/$HouseholdID/user" }
    'User'      { Invoke-SureFlapApi -Path "/api/user/$UserID" }
    'Me'        { Invoke-SureFlapApi -Path '/api/me' }
}
