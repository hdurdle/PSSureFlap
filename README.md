# PowerShell SureFlap API Examples
Consume the SureFlap REST API via PowerShell

The device in question: https://www.surepetcare.com/en-gb/pet-doors/microchip-pet-door-connect


### Getting Started
Set your SureFlap login in the environment before running the scripts:

```powershell
$env:SureFlapEmail = 'you@example.com'
$env:SureFlapPassword = '...'
```

The scripts need PowerShell 7 and run from any folder. If, like me, you just want a quick snapshot of the devices and where your cats are, run `Get-SureFlapStart.ps1`: it returns one object with everything in it.

It appears to be a pretty well constructed and fully featured REST API. I even managed to accidentally create new objects by POSTing when I meant to GET, and it responds to DELETE correctly too.

### Scripts

Every script has help: `Get-Help .\Get-SureFlapPet.ps1 -Full`.

| Script | Does |
|---|---|
| `Get-SureFlapStart.ps1` | Everything at once: devices, households, pets, photos, tags, user |
| `Get-SureFlapHousehold.ps1` | Households (`-ExcludeHouseholdID` to skip one) |
| `Get-SureFlapPet.ps1` | Pets with tag and position, for one or every household |
| `Get-SureFlapPetPosition.ps1` | One pet: Inside, Outside or Unknown, and since when (the API's "position") |
| `Get-SureFlapPetLocation.ps1` | Every pet, in your own room names (see below) |
| `Get-SureFlapDevice.ps1` | Hub and flaps; `-Detailed` adds tags and settings |
| `Get-SureFlapBattery.ps1` | Battery voltage, signal and online state per device; flags stale readings |
| `Get-SureFlapTimeline.ps1` | Recent events, 25 per `-Page` |
| `Get-SureFlapTag.ps1`, `Get-SureFlapUser.ps1`, `Get-SureFlapPhoto.ps1` | Single lookups |
| `Set-SureFlapPetPosition.ps1` | Mark a pet inside or outside |
| `Set-SureFlapPetPermission.ps1` | Let a pet out through a flap, or keep it in |
| `.SureFlapApi.ps1` | Shared helper the others dot-source (`Invoke-SureFlapApi`) |

`Get-` scripts return objects, so pipe them to `Select-Object`, `Where-Object` or `Format-Table`.

Scripts that change anything (`Set-`) only show what they would do. Add `-Execute` to apply the change; `-WhatIf` also works.

The login token is held in `$env:SureFlapToken` for the session and is not saved to disk. All API calls go through `Invoke-SureFlapApi` in `.SureFlapApi.ps1`, which logs in again if the token has expired and retries rate-limited and server errors. Logins use the same client device ID every time on a given computer and Windows user, so they don't add a new client to your account on every run.

#### Get-SureFlapPetLocation.ps1

If you have multiple cat flaps, you can define the flaps, and where they lead (which rooms/zones they connect).

Copy `Get-SureFlapPetLocation-example.ps1` to `Get-SureFlapPetLocation.ps1` and replace the example rows at the top with one row for each pet flap you have. `Get-SureFlapPetLocation.ps1` is gitignored, so your flap IDs stay out of the repo.

Format is:

`( device_id, 'location-inbound', 'location-outbound', 'name-of-petflap' )`

for example:
`( 123456, 'house', 'garden', 'backdoor' )`

Leave the final `$null` row: it covers pets you've set inside or outside by hand in the app.

You can list your flap IDs with: `.\Get-SureFlapDevice.ps1 | Where-Object product_id -in 3, 6 | Select-Object id, name`


### Thanks
Thanks to [alextoft](https://github.com/alextoft) and his [sureflap](https://github.com/alextoft/sureflap) project for the initial pointers. Further bits of the API were discovered by fiddling with the site itself at https://surepetcare.io.
