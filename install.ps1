$ScriptDir = Split-Path $MyInvocation.MyCommand.Path

$mklinkArgs = @()
$mklinkArgs += [PSCustomObject]@{"source"="$(Join-Path $ScriptDir "profile.ps1")"; "target"="$($PROFILE.CurrentUserAllHosts)"}

$Command = "/c cd /d `"$ScriptDir`""
$mklinkArgs | %{ $Command += " `& mklink `"$($_.target)`" `"$($_.source)`"" }

Start-Process cmd -Verb Runas -WindowStyle Hidden -ArgumentList $Command