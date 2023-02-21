param($install)
$file_location = Get-Item . | Get-ChildItem | Where-Object {$_.Extension -eq '.ps1' -and $_.Name -ne 'InstallTask.ps1'} | Select-Object -First 1
$file_name = $file_location.Name.Replace(".ps1", "")

if($install -eq $true -or $install -eq "true"){
Write-Host "Installing Task"


$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-windowstyle hidden -executionpolicy bypass -file `"$($file_location.FullName)`"" -WorkingDirectory $file_location.Directory
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartInterval (New-TimeSpan -Minutes 15) -DontStopOnIdleEnd -ExecutionTimeLimit 0 -RestartCount 5
$trigger = New-ScheduledTaskTrigger -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -Once

#Reinstall Task

$taskExists = Get-ScheduledTask -TaskName $file_name -ErrorAction Ignore
if($taskExists){
    Write-Host "Existing task was found, deleting this task so it can be recreated again"
    # If user moves folder where script is at, they will have to install again, so let's remove existing task if exists.
    $taskExists | Unregister-ScheduledTask -Confirm:$false
}


$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings
Register-ScheduledTask -InputObject $task -User $env:USERNAME -TaskName $file_name | Out-Null

# We can't automate a logon task without admin rights, so this is a workaround to that.
# It will be added to startup folder instead.
New-Item -Name "$file_name.bat" -Value "powershell.exe -windowstyle hidden -executionpolicy bypass -command `"Start-ScheduledTask -TaskName '$file_name' | Out-Null`"" -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -Force | Out-Null

Write-Host "Task was installed sucessfully."
Start-ScheduledTask -TaskName $file_name| Out-Null

}


else {
    Write-Host "Uninstalling Task"
    Get-ScheduledTask $file_name | Stop-ScheduledTask
    Get-ScheduledTask $file_name | Unregister-ScheduledTask -Confirm:$false
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\$file_name.bat" -Force -Confirm:$false | Out-Null
    Write-Host "Task was removed successfully."
}