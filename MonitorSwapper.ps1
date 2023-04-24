﻿param($async)


# Since pre-commands in sunshine are synchronous, we'll launch this script again in another powershell process
if ($null -eq $async) {
    Start-Process powershell.exe  -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $($MyInvocation.MyCommand.UnboundArguments) -async $true" -WindowStyle Hidden
    Start-Sleep -Seconds 1
}

Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)
. .\MonitorSwapper-Functions.ps1
$lock = $false
Start-Transcript -Path .\log.txt


$mutexName = "MonitorSwapper"
$resolutionMutex = New-Object System.Threading.Mutex($false, $mutexName, [ref]$lock)

# There is no need to have more than one of these scripts running.
if (-not $resolutionMutex.WaitOne(0)) {
    Write-Host "Another instance of the script is already running. Exiting..."
    exit
}

try {
    
    # Asynchronously start the Resolution Matcher, so we can use a named pipe to terminate it.
    Start-Job -Name MonitorSwapperJob -ScriptBlock {
        . .\MonitorSwap-Functions.ps1
        $lastStreamed = Get-Date


        Register-EngineEvent -SourceIdentifier MonitorSwapper -Forward
        New-Event -SourceIdentifier MonitorSwapper -MessageData "Start"
        while ($true) {
            if ((IsCurrentlyStreaming)) {
                $lastStreamed = Get-Date
            }
            else {
                if (((Get-Date) - $lastStreamed).TotalSeconds -gt 120) {
                    Write-Output "Ending the stream script"
                    New-Event -SourceIdentifier MonitorSwapper -MessageData "End"
                    break;
                }
    
            }
            Start-Sleep -Seconds 1
        }
    
    }


    # To allow other powershell scripts to communicate to this one.
    Start-Job -Name "MonitorSwapper-Pipe" -ScriptBlock {
        $pipeName = "MonitorSwapper"
        Remove-Item "\\.\pipe\$pipeName" -ErrorAction Ignore
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



    $eventMessageCount = 0
    Write-Host "Waiting for the next event to be called... (for starting/ending stream)"
    while ($true) {
        $eventMessageCount += 1
        Start-Sleep -Seconds 1
        $eventFired = Get-Event -SourceIdentifier MonitorSwapper -ErrorAction SilentlyContinue
        $pipeJob = Get-Job -Name "MonitorSwapper-Pipe"
        if ($null -ne $eventFired) {
            $eventName = $eventFired.MessageData
            Write-Host "Processing event: $eventName"
            if($eventName -eq "Start"){
                OnStreamStart
            }
            elseif ($eventName -eq "End") {
                OnStreamEnd
                break;
            }
            Remove-Event -SourceIdentifier MonitorSwapper
        }
        elseif ($pipeJob.State -eq "Completed") {
            Write-Host "Request to terminate has been processed, script will now revert resolution."
            OnStreamEnd
            Remove-Job $pipeJob
            break;
        }
        elseif($eventMessageCount -gt 59) {
            Write-Host "Still waiting for the next event to fire..."
            $eventMessageCount = 0
        }

    
    }
}
finally {
    Remove-Item "\\.\pipe\MonitorSwapper" -ErrorAction Ignore
    $resolutionMutex.ReleaseMutex()
    Remove-Event -SourceIdentifier MonitorSwapper -ErrorAction Ignore
    Stop-Transcript
}