#Requires -Version 7.0

<#
.SYNOPSIS
    Shows battery voltage, signal and online state for each battery-powered device.

.DESCRIPTION
    Reads every device that reports a battery (flaps, feeders, Felaqua; not the
    hub) from Get-SureFlapDevice.ps1 and returns one row per device.

    BatteryLow is true below 4.8 V, i.e. 1.2 V per cell on the four cells these
    devices take; new alkaline cells read about 6 V. An offline device keeps its
    last reading, so Stale is true when Online is false: check LastUpdate for
    how old the reading is. Read-only.

    Logs in with the SureFlapEmail / SureFlapPassword environment variables
    (see .SureFlapApi.ps1).

.EXAMPLE
    .\Get-SureFlapBattery.ps1

.EXAMPLE
    .\Get-SureFlapBattery.ps1 | Where-Object { $_.BatteryLow -or $_.Stale }
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/.SureFlapApi.ps1"

$lowVolts = 4.8

# Strict mode throws on a missing property, and the API leaves properties out rather than sending null.
function Get-OptionalValue($Object, [string]$Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { $Object.$Name }
}

foreach ($device in & "$PSScriptRoot/Get-SureFlapDevice.ps1") {
    $status = Get-OptionalValue $device 'status'
    $volts = Get-OptionalValue $status 'battery'
    if ($null -eq $volts) { continue }
    $online = [bool](Get-OptionalValue $status 'online')
    [pscustomobject]@{
        Name         = $device.name
        Product      = $SureFlapProducts[[int]$device.product_id] ?? "product $($device.product_id)"
        DeviceID     = $device.id
        Online       = $online
        BatteryVolts = [math]::Round([double]$volts, 2)
        BatteryLow   = [double]$volts -lt $lowVolts
        Stale        = -not $online
        LastUpdate   = Get-OptionalValue $device 'updated_at'
        SignalRssi   = Get-OptionalValue (Get-OptionalValue $status 'signal') 'device_rssi'
    }
}
