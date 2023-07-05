param (
[string] $remote='git@github.com:rhom6us/callisto.git',
#[Parameter(Mandatory)]
[string] $repo=[System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'callisto'),
[switch] $deleteRepoAfter
)


if ([System.IO.Directory]::Exists([System.IO.Path]::Combine($repo, '.git'))) {

    $a = git -C $repo remote -v | Get-RepoUrl
    $b = $remote | Get-RepoUrl
    if($a -ne $b) {
        Write-Host "wtf mate" -ForegroundColor Red
        exit 1
    }
    git -C $repo pull
 } else {
    git clone -b winget --single-branch $remote $repo 2>&1 | %{ "$_" }
 }
set-location -Path $repo



winget export -o .\winget.json --include-versions
git commit -a -m "New export via Windows Task Scheduler"
git push  2>&1 | %{ "$_" }

if ($deleteRepoAfter){
    Remove-Item -Recurse -Force $repo
}

function Get-RepoUrls {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(ValueFromPipeline, ParameterSetName = "local")] [string] $Path,
        [Parameter(ValueFromPipeline, ParameterSetName = "remote")] [string] $Url
    )
}
function Get-RepoUrl([Parameter(ValueFromPipeline)] [string] $gitpath) {
    #$r = git remote -v
    $r = $gitpath | Select-String -Pattern "(https:\/\/|git@)(?<git>.*)\.git"
    if ($r.Matches.Length -gt 0) {
        $t = "https://" + ($r.Matches[0].Groups |
            Where-Object { $_.Name -eq "git" }).Value.Replace(":", "/")
        #Write-Host "gh: openning ",$t,"..." -ForegroundColor "green"
        return $t
    }
    else {
        Write-Host "Please use the ""git@...git"" format url." -ForegroundColor "red"
    }
}