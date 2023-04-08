param($async)
$path = "F:\sources\MonitorSwapAutomation"

# Since pre-commands in sunshine are synchronous, we'll launch this script again in another powershell process
if ($null -eq $async) {
    Start-Process powershell.exe  -ArgumentList "-File `"$($MyInvocation.MyCommand.Path)`" $($MyInvocation.MyCommand.UnboundArguments) -async $true" -WindowStyle Hidden
    # Need to give it enough time to activate the display.
    Start-Sleep -Seconds 2
    exit
}

Set-Location $path

function OnStreamStart() {
    Write-Output "Dummy plug activated"
    & .\MultiMonitorTool.exe /LoadConfig ".\dummy.cfg" 
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
            # Its not necessary to check the next four lines because its not the monitor we want.
            $i += 4
        }
    }

    return $false
}

function SetPrimaryScreen() {
    Write-Host "Attempting to set primary screen"
    if (IsCurrentlyStreaming) {
        return "No Operating Necessary Because already streaming"
    }

    & .\MultiMonitorTool.exe /LoadConfig ".\primary.cfg"
    

    Start-Sleep -Milliseconds 750
}

function OnStreamEnd() {

    for ($i = 0; $i -lt 100000000; $i++) {
        try {

            # To prevent massive performance hitches to users when streaming, we're breaking here in the event they started streaming again.
            if (IsCurrentlyStreaming) {
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






$settings = ConvertFrom-Json ([string](Get-Content -Path "$path/settings.json"))

$gracePeroid = $settings.gracePeriod
$configSaveLocation = [System.Environment]::ExpandEnvironmentVariables($settings.configSaveLocation)
$primaryMonitorId = $settings.primaryMonitorId

while ($true) {
    $streaming = ((IsCurrentlyStreaming) -or ($streamStartEvent -eq $false))
   

    if ($streaming) {
        $lastStreamed = Get-Date
        if (!($streamStartEvent)) {
            OnStreamStart
            Remove-Item "$configSaveLocation/stream_ended.txt" -ErrorAction Ignore
            $streamStartEvent = $true
            $streamEndEvent = $true
        }
    }
    elseif (Test-Path "$configSaveLocation/stream_ended.txt") {
        OnStreamEnd
        Remove-Item "$configSaveLocation/stream_ended.txt"
        break;
    }
    else {
        if ($streamEndEvent -and ((Get-Date) - $lastStreamed).TotalSeconds -gt $gracePeroid) {
            OnStreamEnd
            $streamStartEvent = $false
            $streamEndEvent = $false
            Remove-Item "$configSaveLocation/stream_ended.txt" -ErrorAction Ignore
            break;
        }

    }
    Start-Sleep -Seconds 1
}
