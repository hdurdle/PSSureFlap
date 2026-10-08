#Requires -Version 7.0

<#
.SYNOPSIS
    Lists the SureFlap hubs and flaps on the account.

.DESCRIPTION
    Returns each device with its status: battery, signal, online, firmware
    (GET /api/device). product_id: 1 hub, 2 repeater, 3 pet door, 4 feeder,
    6 cat flap, 7 Feeder Lite, 8 Felaqua ($SureFlapProducts in .SureFlapApi.ps1).
    Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.PARAMETER Detailed
    Also return each device's children, assigned tags (with their permission
    profile) and control settings.

.EXAMPLE
    .\Get-SureFlapDevice.ps1 | Where-Object product_id -in 3, 6 | Select-Object id, name

.EXAMPLE
    .\Get-SureFlapDevice.ps1 -Detailed
#>
[CmdletBinding()]
param(
    [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

$with = if ($Detailed) { 'with[]=children&with[]=tags&with[]=status&with[]=control' } else { 'with[]=status' }
Invoke-SureFlapApi -Path "/api/device?$with"
