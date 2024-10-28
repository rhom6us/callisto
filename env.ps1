

$callisto_home = "c:\dev\callisto"
$shell_path = [System.IO.Path]::Combine("%CALLISTO_HOME%", "shell")
if($null -eq [Environment]::GetEnvironmentVariable("CALLISTO_HOME", [EnvironmentVariableTarget]::Machine)){
    [Environment]::SetEnvironmentVariable("CALLISTO_HOME", $callisto_home, [EnvironmentVariableTarget]::Machine)
}
$path = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)
if($path -inotmatch "$shell_path;"){

    [Environment]::SetEnvironmentVariable("PATH", "$($path.TrimEnd(";"));$shell_path;", [EnvironmentVariableTarget]::Machine)
}

