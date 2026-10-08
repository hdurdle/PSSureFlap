#Requires -Version 7.0

<#
.SYNOPSIS
    Shared SureFlap API helper. Dot-source it; it does nothing when run on its own.

.DESCRIPTION
    Sets $endpoint, $SureFlapProducts and $SureFlapFlapProducts, and defines the
    functions every script in this folder uses:

        Connect-SureFlap    returns a bearer token, logging in first if there isn't one.
        Invoke-SureFlapApi  calls the API and returns its .data. On a 401 it logs in
                            again and retries once; it retries 429 (any method) and
                            5xx (GET only, so a write is never sent twice) up to four
                            attempts, honouring Retry-After.
        Get-SureFlapLoginDeviceId
                            the client ID sent at login. The same on every run for
                            this computer and Windows user, so logins don't register
                            a new client on the account each time.

    Logs in with $env:SureFlapEmail / $env:SureFlapPassword (see Set-PSEnvVars.ps1).
    The token is cached in $env:SureFlapToken for the session and never written to disk.

.EXAMPLE
    . "$PSScriptRoot/.SureFlapApi.ps1"
    Invoke-SureFlapApi -Path '/api/device?with[]=status'
#>

$endpoint = 'https://app.api.surehub.io'

# product_id values, as the surepy library names them. Only 1 and 6 have been seen on a live account here.
$SureFlapProducts = @{
    1 = 'Hub'; 2 = 'Repeater'; 3 = 'Pet door'; 4 = 'Feeder'; 5 = 'Programmer'
    6 = 'Cat flap'; 7 = 'Feeder Lite'; 8 = 'Felaqua'
}
$SureFlapFlapProducts = 3, 6

function Get-SureFlapLoginDeviceId {
    [CmdletBinding()]
    param()

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Derived rather than stored: a hash of computer and user name gives the same 10-digit
    # ID on every run with nothing to keep on disk, and reveals neither name.
    $seed = "SureFlap|$([Environment]::MachineName)|$([Environment]::UserName)"
    $hash = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($seed))
    '{0}' -f ([BitConverter]::ToUInt64($hash, 0) % 9000000000 + 1000000000)
}

function Connect-SureFlap {
    [CmdletBinding()]
    param([switch]$Force)

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if ($Force -or -not $env:SureFlapToken) {
        $email = $env:SureFlapEmail
        $password = $env:SureFlapPassword
        if (-not $email -or -not $password -or "$email$password" -match 'REPLACE_ME') {
            throw 'SureFlapEmail/SureFlapPassword not set. Dot-source Set-PSEnvVars.ps1 first.'
        }
        $body = @{
            email_address = $email
            password      = $password
            device_id     = Get-SureFlapLoginDeviceId
        } | ConvertTo-Json
        try {
            $res = Invoke-RestMethod -Method Post -Uri "$endpoint/api/auth/login" -Body $body -ContentType 'application/json'
        } catch {
            throw "SureFlap login failed: $($_.Exception.Message) Check SureFlapEmail/SureFlapPassword."
        }
        $env:SureFlapToken = $res.data.token
        if (-not $env:SureFlapToken) { throw 'SureFlap login succeeded but returned no token.' }
    }
    $env:SureFlapToken
}

function Invoke-SureFlapApi {
    [CmdletBinding()]
    param(
        # Path and query string after the endpoint, e.g. '/api/device?with[]=status'.
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Get', 'Post', 'Put', 'Delete')][string]$Method = 'Get',
        # Converted to JSON.
        [object]$Body
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    $request = @{ Method = $Method; Uri = "$endpoint$Path"; ContentType = 'application/json' }
    if ($PSBoundParameters.ContainsKey('Body')) { $request.Body = $Body | ConvertTo-Json -Depth 5 }

    $loggedInAgain = $false
    for ($attempt = 1; ; $attempt++) {
        $request.Headers = @{ Authorization = "Bearer $(Connect-SureFlap)" }
        try {
            $res = Invoke-RestMethod @request
            if ($res -and $res.PSObject.Properties['data']) { return $res.data }
            return $res
        } catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $response = $_.Exception.Response
            $status = [int]$response.StatusCode
            if ($status -eq 401 -and -not $loggedInAgain) {
                # Expired or revoked token: the API rejected it before acting, so log in and retry once.
                $env:SureFlapToken = $null
                $loggedInAgain = $true
                continue
            }
            # 429 is always safe to retry; 5xx only for GET, because a write may already have landed.
            $retryable = $status -eq 429 -or ($status -ge 500 -and $Method -eq 'Get')
            if (-not $retryable -or $attempt -ge 4) {
                $detail = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { ' ' + ($_.ErrorDetails.Message -replace '\s+', ' ') } else { '' }
                if ($detail.Length -gt 200) { $detail = $detail.Substring(0, 200) + '...' }
                throw "SureFlap $($Method.ToUpper()) $Path failed: $status $($response.ReasonPhrase).$detail"
            }
            $retryAfter = $response.Headers.RetryAfter
            $wait = if ($retryAfter -and $retryAfter.Delta) { $retryAfter.Delta.TotalSeconds } else { [math]::Pow(2, $attempt) }
            Write-Verbose "SureFlap returned $status for $Method $Path; retrying in $wait s."
            Start-Sleep -Seconds ([math]::Min($wait, 60))
        }
    }
}
