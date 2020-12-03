
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
 -Argument '-NoProfile -WindowStyle Hidden -command "& {c:\Program Files\osquery\osqueryd\osqueryd.exe" --flagfile="c:\Program Files\osquery\osquery_win.flags")}"'

$trigger =  New-ScheduledTaskTrigger -AtStartup

Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "startosqueryagent" -Description "Enroll osquery agent onto fleet server"