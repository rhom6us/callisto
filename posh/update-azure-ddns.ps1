<#
.SYNOPSIS
    Updates an Azure DNS A/AAAA record with this host's current public IP(s).

.DESCRIPTION
    Windows port of github.com/fnrhombus/azure-ddns (bash + systemd). Designed
    to be driven by Task Scheduler on user logon + periodic. Talks directly to
    the Azure Resource Manager REST API (no Az PowerShell module dependency at
    runtime — keeps the cold-start under a second).

    Reads service-principal credentials from a key=value env file at
    $env:LOCALAPPDATA\azure-ddns\env (override via -EnvFile). Caches last
    pushed values + OAuth token in the same directory; short-circuits without
    an Azure call when nothing changed.

    Source-selection for IPv6 mirrors the bash tool's pick_ipv6(): introspects
    local interfaces instead of using a "what's my IP" service, so we can pin
    to a stable address (DHCPv6-assigned or SLAAC) rather than the rotating
    RFC 4941 temporary one that Windows hands out to outbound connections
    when privacy extensions are on.

.PARAMETER EnvFile
    Path to the key=value env file. Default: $env:LOCALAPPDATA\azure-ddns\env.

.PARAMETER WhatIfRecord
    Resolve IPs and show what would be sent to Azure, but don't actually PUT.
#>
[CmdletBinding()]
param(
    [string]$EnvFile = (Join-Path $env:LOCALAPPDATA 'azure-ddns\env'),
    [switch]$WhatIfRecord
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Write-Log { param([string]$Msg) Write-Host "azure-ddns: $Msg" }
function Write-Warn { param([string]$Msg) Write-Warning "azure-ddns: $Msg" }
function Die { param([string]$Msg) Write-Error "azure-ddns: $Msg" -ErrorAction Stop }

# ---- Read env file ------------------------------------------------------
if (-not (Test-Path -LiteralPath $EnvFile)) {
    Die "env file not found at $EnvFile — see README"
}

$cfg = @{}
foreach ($line in Get-Content -LiteralPath $EnvFile) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    $eq = $t.IndexOf('=')
    if ($eq -lt 1) { continue }
    $key = $t.Substring(0, $eq).Trim()
    $val = $t.Substring($eq + 1).Trim().Trim('"').Trim("'")
    $cfg[$key] = $val
}

foreach ($k in @('AZURE_TENANT_ID','AZURE_CLIENT_ID','AZURE_CLIENT_SECRET',
                 'AZURE_SUBSCRIPTION_ID','AZURE_RESOURCE_GROUP',
                 'AZURE_DNS_ZONE','AZURE_DNS_RECORD')) {
    if (-not $cfg.ContainsKey($k) -or [string]::IsNullOrWhiteSpace($cfg[$k])) {
        Die "$k is empty or missing in $EnvFile"
    }
}

$ttl = if ($cfg.ContainsKey('AZURE_DNS_TTL') -and $cfg['AZURE_DNS_TTL']) { [int]$cfg['AZURE_DNS_TTL'] } else { 300 }
$disableV4 = ($cfg['AZURE_DDNS_DISABLE_IPV4'] -eq '1')
$disableV6 = ($cfg['AZURE_DDNS_DISABLE_IPV6'] -eq '1')
$v6Mode    = if ($cfg.ContainsKey('AZURE_DDNS_IPV6_SELECT') -and $cfg['AZURE_DDNS_IPV6_SELECT']) { $cfg['AZURE_DDNS_IPV6_SELECT'] } else { 'stable' }
$v6Iface   = $cfg['AZURE_DDNS_IPV6_INTERFACE']

# ---- Cache layout -------------------------------------------------------
$cacheDir = Split-Path -Parent $EnvFile
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
$cacheV4  = Join-Path $cacheDir 'last.a'
$cacheV6  = Join-Path $cacheDir 'last.aaaa'
$cacheTok = Join-Path $cacheDir 'token.json'

# ---- IPv6 source selection ---------------------------------------------
# Modes: stable (default) | dhcp | random | <ipv6-literal>.
# "stable" = SuffixOrigin = Link — the kernel-managed stable SLAAC GUA
# (RFC 7217 stable-privacy or EUI-64). Matches the Linux tool's
# slaac-stable semantic. Avoids both the RFC 4941 temporary address
# (rotates ~24h) and DHCPv6-assigned addresses (which are valid but
# subject to the DHCP server's whim rather than purely kernel-managed).
function Get-PreferredIPv6 {
    $params = @{ AddressFamily = 'IPv6' }
    if ($v6Iface) { $params.InterfaceAlias = $v6Iface }

    $candidates = Get-NetIPAddress @params -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike 'fe80*' -and        # link-local
            $_.IPAddress -notlike 'fc*' -and          # ULA
            $_.IPAddress -notlike 'fd*' -and          # ULA
            $_.IPAddress -notlike '::1' -and
            $_.AddressState -eq 'Preferred' -and
            $_.PrefixOrigin -ne 'WellKnown'
        }

    if (-not $candidates) { return $null }

    # Literal mode: exact match.
    if ($v6Mode -match '^[0-9a-fA-F:]+$' -and $v6Mode -like '*:*') {
        $hit = $candidates | Where-Object { $_.IPAddress -eq $v6Mode }
        if (-not $hit) { Write-Warn "AZURE_DDNS_IPV6_SELECT='$v6Mode' not found among preferred global IPv6 addresses" }
        return ($hit | Select-Object -First 1).IPAddress
    }

    switch ($v6Mode) {
        'stable'  { $filtered = $candidates | Where-Object { $_.SuffixOrigin -eq 'Link' } }
        'dhcp'    { $filtered = $candidates | Where-Object { $_.SuffixOrigin -eq 'Dhcp' } }
        'random'  { $filtered = $candidates | Where-Object { $_.SuffixOrigin -eq 'Random' } }
        default   { Die "AZURE_DDNS_IPV6_SELECT='$v6Mode' invalid (expected: stable | dhcp | random | <ipv6-literal>)" }
    }

    if (-not $filtered) { return $null }

    # Longest ValidLifetime wins. TimeSpan compares correctly via sort.
    return ($filtered | Sort-Object ValidLifetime -Descending | Select-Object -First 1).IPAddress
}

# ---- Resolve current IPs ------------------------------------------------
# NOTE: IPv4 detection is deliberately NOT done via a "what's my IP" web
# service. On a CG-NAT'd home connection that returns the carrier gateway
# (useless for DNS); for a publicly-routable v4 host you'd add interface
# introspection here. Today the only caller is IPv6-only, so this stays
# unimplemented and DDNS_DISABLE_IPV4=1 is the default.
$ipv4 = $null
if (-not $disableV4) {
    Write-Warn 'IPv4 detection not implemented (set AZURE_DDNS_DISABLE_IPV4=1 to silence). Skipping A record.'
}

$ipv6 = $null
if (-not $disableV6) { $ipv6 = Get-PreferredIPv6 }

if (-not $ipv4 -and -not $ipv6) {
    if ($disableV4 -and $disableV6) { Die "both IPv4 and IPv6 disabled — nothing to do" }
    Write-Warn 'no usable public IP detected — network down? skipping.'
    exit 0
}

# ---- Short-circuit on unchanged values ---------------------------------
$lastV4 = if (Test-Path -LiteralPath $cacheV4) { Get-Content -LiteralPath $cacheV4 -Raw } else { '' }
$lastV6 = if (Test-Path -LiteralPath $cacheV6) { Get-Content -LiteralPath $cacheV6 -Raw } else { '' }

if ($ipv4 -eq $lastV4.Trim() -and $ipv6 -eq $lastV6.Trim()) { exit 0 }

# WhatIf mode: print what we'd push and exit before any Azure call.
if ($WhatIfRecord) {
    if ($ipv4) { Write-Log "WHATIF A    $($cfg['AZURE_DNS_RECORD']).$($cfg['AZURE_DNS_ZONE']) → $ipv4" }
    if ($ipv6) { Write-Log "WHATIF AAAA $($cfg['AZURE_DNS_RECORD']).$($cfg['AZURE_DNS_ZONE']) → $ipv6" }
    exit 0
}

# ---- OAuth client-credentials → ARM token ------------------------------
$token = $null
if (Test-Path -LiteralPath $cacheTok) {
    try {
        $cached = Get-Content -LiteralPath $cacheTok -Raw | ConvertFrom-Json
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        if ($cached.expires_at -gt ($now + 60)) { $token = $cached.access_token }
    } catch { $token = $null }
}

if (-not $token) {
    Write-Log 'minting new Azure access token...'
    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $cfg['AZURE_CLIENT_ID']
        client_secret = $cfg['AZURE_CLIENT_SECRET']
        scope         = 'https://management.azure.com/.default'
    }
    $resp = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$($cfg['AZURE_TENANT_ID'])/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $body -TimeoutSec 15
    $token = $resp.access_token
    if (-not $token) { Die "token request returned no access_token" }

    $expiresAt = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + [int]$resp.expires_in
    @{
        access_token = $token
        expires_at   = $expiresAt
    } | ConvertTo-Json | Set-Content -LiteralPath $cacheTok -NoNewline -Encoding utf8
    # Lock cache file to current user (token is bearer-grade for the SP scope).
    $acl = Get-Acl -LiteralPath $cacheTok
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        [System.Security.Principal.WindowsIdentity]::GetCurrent().User,
        'FullControl', 'Allow')
    $acl.SetAccessRule($rule)
    Set-Acl -LiteralPath $cacheTok -AclObject $acl
}

# ---- PUT (CreateOrUpdate) ----------------------------------------------
$urlBase = "https://management.azure.com/subscriptions/$($cfg['AZURE_SUBSCRIPTION_ID'])/resourceGroups/$($cfg['AZURE_RESOURCE_GROUP'])/providers/Microsoft.Network/dnsZones/$($cfg['AZURE_DNS_ZONE'])"
$apiVer  = '2018-05-01'

function Update-RecordSet {
    param([string]$Kind, [string]$Address)

    $url = "$urlBase/$Kind/$($cfg['AZURE_DNS_RECORD'])?api-version=$apiVer"
    if ($Kind -eq 'A') {
        $body = @{ properties = @{ TTL = $ttl; ARecords    = @(@{ ipv4Address = $Address }) } } | ConvertTo-Json -Depth 5 -Compress
    } else {
        $body = @{ properties = @{ TTL = $ttl; AAAARecords = @(@{ ipv6Address = $Address }) } } | ConvertTo-Json -Depth 5 -Compress
    }

    Invoke-RestMethod -Method Put -Uri $url `
        -Headers @{ Authorization = "Bearer $token" } `
        -ContentType 'application/json' `
        -Body $body -TimeoutSec 30 | Out-Null
}

if ($ipv4 -and $ipv4 -ne $lastV4.Trim()) {
    Update-RecordSet -Kind 'A' -Address $ipv4
    Set-Content -LiteralPath $cacheV4 -Value $ipv4 -NoNewline
    Write-Log "A    $($cfg['AZURE_DNS_RECORD']).$($cfg['AZURE_DNS_ZONE']) → $ipv4"
}

if ($ipv6 -and $ipv6 -ne $lastV6.Trim()) {
    Update-RecordSet -Kind 'AAAA' -Address $ipv6
    Set-Content -LiteralPath $cacheV6 -Value $ipv6 -NoNewline
    Write-Log "AAAA $($cfg['AZURE_DNS_RECORD']).$($cfg['AZURE_DNS_ZONE']) → $ipv6"
}
