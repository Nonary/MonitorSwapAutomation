param($async)
$path = (Split-Path $MyInvocation.MyCommand.Path -Parent)
Set-Location $path
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json
$scriptName = "SunshineScriptInstaller"

# Since pre-commands in sunshine are synchronous, we'll launch this script again in another powershell process
if ($null -eq $async) {
    Start-Process powershell.exe  -ArgumentList "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $($MyInvocation.MyCommand.UnboundArguments) -async $true" -WindowStyle Hidden
    Start-Sleep -Seconds $settings.startDelay
    exit
}


. .\Functions.ps1

if (Test-Path "\\.\pipe\$scriptName") {
    Send-PipeMessage $scriptName Terminate
    Start-Sleep -Seconds 20
}

if (Test-Path "\\.\pipe\$scriptName-OnStreamEnd") {
    Send-PipeMessage "$scriptName-OnStreamEnd" Terminate
    Start-Sleep -Seconds 5
}

# Attempt to start the transcript multiple times in case previous process is still running.
for ($i = 0; $i -lt 10; $i++) {
    
    try {
        Start-Transcript .\log.txt -ErrorAction Stop
        break;
    }
    catch {
        Start-Sleep -Seconds 1
    }
}

try {
    
    # Asynchronously start the script, so we can use a named pipe to terminate it.
    Start-Job -Name "$($scriptName)Job" -ScriptBlock {
        param($path, $gracePeriod)
        . $path\Functions.ps1
        $lastStreamed = Get-Date


        Register-EngineEvent -SourceIdentifier $scriptName -Forward
        New-Event -SourceIdentifier $scriptName -MessageData "Start"
        while ($true) {
            try {
                if ((IsCurrentlyStreaming)) {
                    $lastStreamed = Get-Date
                }
                else {
                    if (((Get-Date) - $lastStreamed).TotalSeconds -gt $gracePeriod) {
                        New-Event -SourceIdentifier MonitorSwapper -MessageData "GracePeriodExpired"
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
    Start-Job -Name "$scriptName-Pipe" -ScriptBlock {
        Register-EngineEvent -SourceIdentifier MonitorSwapper -Forward
        for ($i = 0; $i -lt 10; $i++) {
            # We could be pending a previous termination, so lets wait up to 10 seconds.
            if (-not (Test-Path "\\.\pipe\$scriptName")) {
                break
            }
            
            Start-Sleep -Seconds 1
        }


        Remove-Item "\\.\pipe\$scriptName" -ErrorAction Ignore
        $pipe = New-Object System.IO.Pipes.NamedPipeServerStream($scriptName, [System.IO.Pipes.PipeDirection]::In, 1, [System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous)

        $streamReader = New-Object System.IO.StreamReader($pipe)
        Write-Output "Waiting for named pipe to recieve kill command"
        $pipe.WaitForConnection()

        $message = $streamReader.ReadLine()
        if ($message -eq "Terminate") {
            Write-Output "Terminating pipe..."
            $pipe.Dispose()
            $streamReader.Dispose()
        }

        New-Event -SourceIdentifier $scriptName -MessageData "Pipe-Terminated"
    }



    Write-Host "Waiting for the next event to be called... (for starting/ending stream)"
    while ($true) {
        Start-Sleep -Seconds 1
        $eventFired = Get-Event -SourceIdentifier $scriptName -ErrorAction SilentlyContinue
        if ($null -ne $eventFired) {
            $eventName = $eventFired.MessageData
            Write-Host "Processing event: $eventName"
            if ($eventName -eq "Start") {
                OnStreamStart
            }
            else {
                $job = OnStreamEndAsJob
                while ($job.State -ne "Completed") {
                    $job | Receive-Job
                    Start-Sleep -Seconds 1
                }
                $job | Wait-Job | Receive-Job
                break;
            }
            Remove-Event -EventIdentifier $eventFired.EventIdentifier
        }
    }
}
finally {
    Stop-Transcript
}
