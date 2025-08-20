#Requires -Version 2

<#
.SYNOPSIS
	Updates the IP address of your Duck DNS domain(s).
.DESCRIPTION
	Updates the IP address of your Duck DNS domain(s). Intended to be run as a
	scheduled task.
.PARAMETER Domains
	A comma-separated list of your Duck DNS domains to update.
.PARAMETER Token
	Your Duck DNS token.
.PARAMETER IP
	The IP address to use. If you leave it blank, Duck DNS will detect your
	gateway IP.
.INPUTS
	None. You cannot pipe objects to this script.
.OUTPUTS
	None. This script does not generate any output.
.EXAMPLE
	.\update-duckdns.ps1 -Domains "foo,bar" -Token my-duck-dns-token
.LINK
	https://github.com/ataylor32/duckdns-powershell
#>

Param (
	[Parameter(
		Mandatory = $True,
		HelpMessage = "Comma separate the domains if you want to update more than one."
	)]
	[ValidateNotNullOrEmpty()]
	[String]$Domains,

	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$Token
)

If ($PSVersionTable.PSVersion.Major -lt 2) {
	throw 'Powershell v2 or greater required'
}


$IP = Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv6 -AddressState Preferred -SuffixOrigin Link |
	Where-Object PrefixOrigin -ne "WellKnown" |
	Select-Object -expand IpAddress

$Request = @{
	Uri    = 'https://www.duckdns.org/update'
	Method = 'GET'
	Body   = @{
		domains = $Domains
		token   = $Token
		ip      = $IP
	}
}

$URL   = "https://www.duckdns.org/update/$Domains/$Token/$IP"

write-host $URL
$Response = Invoke-WebRequest $URL

write-host $Response


If ($Null -eq $Response) {
	throw 'wtf mate'
}
if($Response.StatusDescription -ne "OK") {
	Throw "Update failed."
}


Write-Verbose "Update successful."
