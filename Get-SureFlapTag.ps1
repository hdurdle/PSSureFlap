#Requires -Version 7.0

<#
.SYNOPSIS
    Returns one microchip tag.

.DESCRIPTION
    Returns the tag's microchip number and the products it works with
    (GET /api/tag/{id}). Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER TagID
    SureFlap tag ID (the tag_id column from Get-SureFlapPet.ps1), not the
    microchip number.

.EXAMPLE
    .\Get-SureFlapTag.ps1 -TagID 12345
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(1, [int]::MaxValue)][int]$TagID
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

Invoke-SureFlapApi -Path "/api/tag/$TagID"
