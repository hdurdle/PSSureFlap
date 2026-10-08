#Requires -Version 7.0

<#
.SYNOPSIS
    Lists the photos on the account.

.DESCRIPTION
    Returns each photo's metadata, including its download location (GET /api/photo).
    Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.EXAMPLE
    .\Get-SureFlapPhoto.ps1 | Select-Object id, title, location
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

Invoke-SureFlapApi -Path '/api/photo'
