param($terminate)

Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json
$configSaveLocation = [System.Environment]::ExpandEnvironmentVariables($settings.configSaveLocation)
$primaryMonitorId = $settings.primaryMonitorId
$dummyMonitorId = $settings.dummyMonitorId


function OnStreamStart() {

    & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
    Start-Sleep -Seconds 1

    # Attempt to load the dummy profile for up to 5 times in total.
    for ($i = 0; $i -lt 4; $i++) {
        if (-not (IsMonitorActive -monitorId $dummyMonitorId)) {
            & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
        }
        if ($i -eq 4) {
            Write-Host "Failed to verify dummy plug was activated, did you make sure dummyMonitorId was included and was properly escaped with double backslashes?"
        }
        Start-Sleep -Milliseconds 500
    }

    Write-Output "Dummy plug activated"
}


function IsMonitorActive($monitorId) {
    # For some displays, the primary screen can't be set until it wakes up from sleep.
    # This will continually poll the configuration to make sure the display has been set.
    $filePath = "$configSaveLocation\current_monitor_config.cfg"
    & .\MultiMonitorTool.exe /SaveConfig $filePath
    Start-Sleep -Seconds 1

    $currentTime = Get-Date

    # Get the file's last write time
    $fileLastWriteTime = (Get-Item $filePath).LastWriteTime

    # Calculate the time difference in minutes
    $timeDifference = ($currentTime - $fileLastWriteTime).TotalMinutes

    # Check if the file was saved in the last minute, if it has not been saved recently, then we could have a potential false positive.
    if ($timeDifference -gt 1) {
        return $false        
    }

    $monitorConfigLines = (Get-Content -Path $filePath | Select-String "MonitorID=.*|SerialNumber=.*|Width.*|Height.*|DisplayFrequency.*")
    for ($i = 0; $i -lt $monitorConfigLines.Count; $i++) {
        $configMonitorId = ($monitorConfigLines[$i] -split "=") | Select-Object -Last 1

        if ($configMonitorId -eq $monitorId) {
            $width = ($monitorConfigLines[$i + 2] -split "=") | Select-Object -Last 1
            $height = ($monitorConfigLines[$i + 3] -split "=") | Select-Object -Last 1
            $refresh = ($monitorConfigLines[$i + 4] -split "=") | Select-Object -Last 1

            # Inactive displays will be zero on everything basically.
            return  ($height -ne 0 -and $width -ne 0 -and $refresh -ne 0)
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
        Write-Host "Screen will not be reverted because we are already streaming"
        return
    }

    & .\MultiMonitorTool.exe /LoadConfig "primary.cfg"

    Start-Sleep -Milliseconds 750
}

function OnStreamEnd() {

    for ($i = 0; $i -lt 100000000; $i++) {
        try {

            # To prevent massive performance hitches to users when streaming, we're breaking here in the event they started streaming again.
            if (IsCurrentlyStreaming) {
                break;
            }
        
            SetPrimaryScreen

            # Some displays will not activate until the user returns back to their PC and wakes up the display.
            # So start a near infinite loop to check and set that.
            if (!(IsMonitorActive -monitorId $primaryMonitorId)) {
                SetPrimaryScreen
            }
            else {
                break
            }
        
        }
        catch {
            ## Do Nothing, because we're expecting it to fail in cases like when user has a TV as a primary display.
        }
        Start-Sleep -Seconds 5
    }

    Write-Host "Dummy Plug has been successfully deactivated!"

}

function IsSunshineUser() {
    return $null -ne (Get-Process sunshine -ErrorAction SilentlyContinue)
}

function IsCurrentlyStreaming() {
    if (IsSunshineUser) {
        return $null -ne (Get-NetUDPEndpoint -OwningProcess (Get-Process sunshine).Id -ErrorAction Ignore)
    }

    return $null -ne (Get-Process nvstreamer -ErrorAction SilentlyContinue)
}

function Stop-MonitorSwapperScript() {

    $pipeExists = Get-ChildItem -Path "\\.\pipe\" | Where-Object { $_.Name -eq "MonitorSwapper" } 
    if ($pipeExists.Length -gt 0) {
        $pipeName = "MonitorSwapper"
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName, [System.IO.Pipes.PipeDirection]::Out)
        $pipe.Connect(3)
        $streamWriter = New-Object System.IO.StreamWriter($pipe)
        $streamWriter.WriteLine("Terminate")
        try {
            $streamWriter.Flush()
            $streamWriter.Dispose()
            $pipe.Dispose()
        }
        catch {
            # We don't care if the disposal fails, this is common with async pipes.
            # Also, this powershell script will terminate anyway.
        }
    }
}
    

if ($terminate) {
    Stop-MonitorSwapperScript | Out-Null
}
