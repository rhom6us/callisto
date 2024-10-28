
function New-Link ([string]$Target, [string]$Link) {
    if (Test-Path $Link) {
        Write-Warning "`"$Link`" already exists. Backing up to `"$Link.bak`" and removing"
        Move-Item -Path "$Link" -Destination "$Link.bak" -Force
    }
    New-Item -Path "$Link" -ItemType SymbolicLink -Value "$Target"
}

$configs = "$env:CALLISTO_HOME\configs"

New-Link "$configs\pwsh\profile.ps1" $profile.AllUsersAllHosts
New-Link "$configs\clink\oh-my-posh.lua" "$env:LOCALAPPDATA\clink\oh-my-posh.lua"
New-Link "$configs\windows.terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

