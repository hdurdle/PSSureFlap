#Requires -Version 7.0

<#
.SYNOPSIS
    Returns a snapshot of the whole account: devices, households, pets, photos, tags and user.

.DESCRIPTION
    The same start-up object the app loads (GET /api/me/start). The quickest way
    to see everything at once. Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.EXAMPLE
    .\Get-SureFlapStart.ps1

.EXAMPLE
    .\Get-SureFlapStart.ps1 | ConvertTo-Json -Depth 10 | Set-Content sureflap-backup.json
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

Invoke-SureFlapApi -Path '/api/me/start?with=language'
