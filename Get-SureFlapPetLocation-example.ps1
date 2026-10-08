#Requires -Version 7.0

<#
.SYNOPSIS
    Shows where each pet is, using your own map of what each flap connects.

.DESCRIPTION
    Combines each pet's last flap movement with the $flaps table below to name
    the room or zone the pet is in, since when, and for how long. Read-only.

    This is the committed example with made-up flaps. Copy it to
    Get-SureFlapPetLocation.ps1 (gitignored, so your flap IDs stay local) and replace the
    rows in $flaps with your own.

    One row per flap: ( device_id, "inbound location", "outbound location", "flap name" ).
    Inbound is where a pet ends up after coming in through the flap. Keep the
    final $null row: it covers pets set inside/outside by hand in the app.
    Find your flap IDs with:
        .\Get-SureFlapDevice.ps1 | Where-Object product_id -in 3, 6 | Select-Object id, name

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.EXAMPLE
    .\Get-SureFlapPetLocation.ps1

.EXAMPLE
    .\Get-SureFlapPetLocation.ps1 | Where-Object Location -eq 'garden'
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Your flaps: ( device_id, inbound, outbound, name ) ---------------------------
$flaps =
    ( 100001, 'house', 'garden', 'backdoor' ),
    ( 100002, 'garage', 'garden', 'garage' ),
    ( 100003, 'house', 'garage', 'utility' ),
    ( $null, '[inside]', '[outside]', '' ) |
    ForEach-Object { [pscustomobject]@{ Id = $_[0]; In = $_[1]; Out = $_[2]; Name = $_[3] } }
# ----------------------------------------------------------------------------------

foreach ($pet in & "$PSScriptRoot/Get-SureFlapPet.ps1" | Where-Object { $_.name }) {
    # Pets that have never been through a flap or set inside/outside have no position.
    $position = $pet.PSObject.Properties['position']?.Value
    if (-not $position) {
        [pscustomobject]@{ Name = $pet.name; Location = '[unknown]'; Since = $null; Duration = $null }
        continue
    }

    # where: 1 = came in through the flap, 2 = went out through it.
    # No device_id when the position was set by hand in the app; that matches the $null row.
    $deviceID = $position.PSObject.Properties['device_id']?.Value
    $since = [datetime]$position.since
    $flap = $flaps | Where-Object { $_.Id -eq $deviceID } | Select-Object -First 1
    $location = if (-not $flap) { "[flap $deviceID not in `$flaps]" }
                elseif ($position.where -eq 1) { $flap.In }
                else { $flap.Out }

    [pscustomobject]@{
        Name     = $pet.name
        Location = $location
        Since    = '{0:dd}-{0:MMM} {0:t}' -f $since
        Duration = '{0:%d}d {0:hh}h {0:mm}m' -f (New-TimeSpan -Start $since)
    }
}
