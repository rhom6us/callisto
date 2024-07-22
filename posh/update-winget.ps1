param (
    [Parameter(Mandatory)] [string] $RepoUrl,
    [string] $TempDirForRepo = (Join-Path $env:TEMP 'update-winget'),
    [switch] $IncludeVersions,
    [switch] $DeleteRepoAfterward
)

ssh-agent -s


if (Join-Path $TempDirForRepo '.git' | Test-Path) {
    git -C $TempDirForRepo pull
}
else {
    git clone -b winget --single-branch $RepoUrl $TempDirForRepo 2>&1 | % { "$_" }
}

# git@github.com:rhom6us/callisto.git

$outfile = Join-Path $TempDirForRepo 'winget.json'
$args = "export -o $outfile"
if ($IncludeVersions) {
    $args = "$args --include-versions" 
}

#using start-process here to prevent console window from appearing when run from task scheduler
start-process -FilePath 'winget' -NoNewWindow -Wait -ArgumentList $args

#remove the date from the document so that there isn't a new git revision if nothing else changed
(Get-Content $outfile) -replace '[^\n]*"CreationDate"[^\n]*', '' | Set-Content $outfile

git -C $TempDirForRepo add --all
git -C $TempDirForRepo commit -a -m "New export via Windows Task Scheduler"
git -C $TempDirForRepo push  2>&1 | % { "$_" }


if ($DeleteRepoAfterward) {
    Remove-Item -Recurse -Force $TempDirForRepo
}
