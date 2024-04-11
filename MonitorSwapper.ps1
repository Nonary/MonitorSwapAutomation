﻿param($async)
$path = (Split-Path $MyInvocation.MyCommand.Path -Parent)
Set-Location $path
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json

# Since pre-commands in sunshine are synchronous, we'll launch this script again in another powershell process
if ($null -eq $async) {
    Start-Process powershell.exe  -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $($MyInvocation.MyCommand.UnboundArguments) -async $true" -WindowStyle Hidden
    Start-Sleep -Seconds $settings.startDelay
    exit
}


. .\MonitorSwapper-Functions.ps1

if(Test-Path "\\.\pipe\MonitorSwapper"){
    Write-Host "Existing session found"
    # Script is already running, let's gracefully terminate it and launch it again.
    Send-PipeMessage MonitorSwapper Terminate
    Start-Sleep -Seconds 20
}

if(Test-Path "\\.\pipe\OnStreamEnd"){
    Write-Host "Pending termination pipe found, closing it out"
    Send-PipeMessage OnStreamEnd Terminate
    Start-Sleep -Seconds 5
}

Start-Transcript -Path .\log.txt


# There is no need to have more than one of these scripts running, so lets close out the previous one gracefully.



try {
    
    # Asynchronously start the MonitorSwapper, so we can use a named pipe to terminate it.
    Start-Job -Name MonitorSwapperJob -ScriptBlock {
        param($path, $gracePeriod)
        . $path\MonitorSwapper-Functions.ps1
        $lastStreamed = Get-Date


        Register-EngineEvent -SourceIdentifier MonitorSwapper -Forward
        New-Event -SourceIdentifier MonitorSwapper -MessageData "Start"
        while ($true) {
            try {
                if ((IsCurrentlyStreaming)) {
                    $lastStreamed = Get-Date
                }
                else {
                    if (((Get-Date) - $lastStreamed).TotalSeconds -gt $gracePeriod) {
                        New-Event -SourceIdentifier MonitorSwapper -MessageData "End"
                        break;
                    }
        
                }
            }
            finally {
                Start-Sleep -Seconds 1
            }
        }
    
    } -ArgumentList $path, $settings.gracePeriod


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
            else{
                OnStreamEndAsJob | Wait-Job
                break;
            }
            Remove-Event -EventIdentifier $eventFired.EventIdentifier
        }
        elseif ($pipeJob.State -eq "Completed") {
            Write-Host "Request to terminate has been processed, script will now revert monitor configuration."
            $endJob = OnStreamEndAsJob

            # Continually poll the job to write to log file once every 1 seconds
            while($endJob.State -ne "Completed"){
                $endJob | Receive-Job
                Start-Sleep -Seconds 1
            }
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
    Remove-Event -SourceIdentifier MonitorSwapper -ErrorAction Ignore
    Stop-Transcript
}
