param($async)
$path = "Please run the Install_as_Precommand.ps1 script to finish the setup of this script."

# Since pre-commands in sunshine are synchronous, we'll launch this script again in another powershell process
if ($null -eq $async) {
    Start-Process powershell.exe  -ArgumentList "-File `"$($MyInvocation.MyCommand.Path)`" $($MyInvocation.MyCommand.UnboundArguments) -async $true" -WindowStyle Hidden
    # Need to give it enough time to activate the display.
    Start-Sleep -Seconds 2
    exit
}

Set-Location $path

. $path\MonitorSwap-Functions.ps1


$mutexName = "MonitorSwapper"
$global:monitorSwapMutex = New-Object System.Threading.Mutex($false, $mutexName)

# There is no need to have more than one of these scripts running.
if (-not $global:monitorSwapMutex.WaitOne(0)) {
    Write-Host "Another instance of the script is already running. Exiting..."
    exit
}

# Asynchronously start the monitor swapper, so we can use a named pipe to terminate it.
Start-Job -Name MonitorSwapJob -ScriptBlock {
    param($path)
    . $path\MonitorSwap-Functions.ps1
    $lastStreamed = Get-Date


    Register-EngineEvent -SourceIdentifier MonitorSwapper -Forward
    New-Event -SourceIdentifier MonitorSwapper -MessageData { OnStreamStart }
    while ($true) {
        if ((IsCurrentlyStreaming)) {
            $lastStreamed = Get-Date
        }
        else {
            # Grace period is dot sourced here from MonitorSwap-Functions.ps1
            if (((Get-Date) - $lastStreamed).TotalSeconds -gt $gracePeroid) {
                Write-Output "Ending the stream script"
                New-Event -SourceIdentifier MonitorSwapper -MessageData { OnStreamEnd; break }
                break;
            }
    
        }
        Start-Sleep -Seconds 1
    }
    
} -ArgumentList $path


# To allow other powershell scripts to communicate to this one.
Start-Job -Name NamedPipeJob -ScriptBlock {
    $pipeName = "MonitorSwapper"
    $pipe = New-Object System.IO.Pipes.NamedPipeServerStream($pipeName, [System.IO.Pipes.PipeDirection]::In, 1, [System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous)

    $streamReader = New-Object System.IO.StreamReader($pipe)
    Write-Output "Waiting for named pipe to recieve kill command"
    $pipe.WaitForConnection()

    $message = $streamReader.ReadLine()
    if ($message -eq "Terminate") {
        Write-Output "Terminating pipe..."
        $pipe.Dispose()
        $streamReader.Dispose()
    }
}






while ($true) {
    Start-Sleep -Seconds 1
    $eventFired = Get-Event -SourceIdentifier MonitorSwapper -ErrorAction SilentlyContinue
    $pipeJob = Get-Job -Name "NamedPipeJob"
    if ($null -ne $eventFired) {
        Write-Host "Processing event..."
        $eventData = [scriptblock]::Create($eventFired.MessageData)
        $eventData.Invoke()
        Remove-Event -SourceIdentifier MonitorSwapper
    }
    elseif ($pipeJob.State -eq "Completed") {
        Write-Host "Stopping the monitor swap script, please be advised that the script may still run until the primary screen has been set."
        OnStreamEnd
        break;
    }
    else {
        Write-Host "Waiting for next event..."
    }
}
