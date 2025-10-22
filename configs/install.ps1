# $configs = "$env:CALLISTO_HOME\configs"

$config = [ordered]@{
    ".\pwsh\profile.ps1"               = $profile.CurrentUserAllHosts
    ".\clink\oh-my-posh.lua"           = "$env:LOCALAPPDATA\clink\oh-my-posh.lua"
    ".\windows.terminal\settings.json" = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    ".\vscode\settings.json"           = "$env:APPDATA\Code\User\settings.json"
    ".\vscode\mcp.json"           = "$env:APPDATA\Code\User\mcp.json"
    ".\vscode\keybindings.json"           = "$env:APPDATA\Code\User\keybindings.json"
}


function New-Link ([string]$RepoFile, [string]$ProdFile) {


    if (-not (Test-Path $RepoFile)) {
        if (-not (Test-Path $ProdFile)) {
            Write-Warning "Neither `"$RepoFile`" nor `"$ProdFile`" exist"
            return
        }
        Write-Information "Creating source config from `"$ProdFile`""
        Copy-Item -Path $ProdFile -Destination $RepoFile
        git add $RepoFile
        git commit -m "File sourced from `"$ProdFile`""
        git push
    }


    if (Test-Path $ProdFile) {
        Write-Warning "`"$ProdFile`" already exists. Backing up to `"$ProdFile.bak`""
        Move-Item -Path "$ProdFile" -Destination "$ProdFile.bak" -Force
    }


    New-Item -Path "$ProdFile" -ItemType SymbolicLink -Value "$RepoFile"
}



cd $PSScriptRoot

foreach ($Key in $config.Keys) {
    New-Link $Key $($config[$Key])
}


# New-Link "$configs\pwsh\profile.ps1" $profile.CurrentUserAllHosts
# New-Link "$configs\clink\oh-my-posh.lua" "$env:LOCALAPPDATA\clink\oh-my-posh.lua"
# New-Link "$configs\windows.terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
# New-Link "$configs\vscode\settings.json" "$env:APPDATA\Code\User\settings.json"

