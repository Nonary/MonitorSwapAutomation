param($terminate)

Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json
$configSaveLocation = [System.Environment]::ExpandEnvironmentVariables($settings.configSaveLocation)
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

    
    if (IsCurrentlyStreaming) {
        Write-Host "Screen will not be reverted because we are already streaming"
        return
    }

    & .\MultiMonitorTool.exe /LoadConfig "primary.cfg"

    Start-Sleep -Milliseconds 750
}

function Get-PrimaryMonitorIds {
    $pattern = '(?<=MonitorID=)(?<id>.*)|(?<=DisplayFrequency=)(?<freq>\d+)'
    $primaryMonitorIds = @()
    $foundMonitors = [regex]::Matches((Get-Content -Raw -Path "primary.cfg"), $pattern)
    for ($i = 0; $i -lt $foundMonitors.Count; $i += 2) {
        $match = $foundMonitors[$i]
        $monitorId = $match.Groups[0].Value
        $refresh = $foundMonitors[$i + 1].Groups[0].Value

        if ($refresh -ne 0) {
            $primaryMonitorIds += $monitorId.Trim()
        }
    }

    return $primaryMonitorIds
}

function OnStreamEnd() {
    Write-Host "Attempting to set primary screen, some displays may not activate until you return to the computer"

    $maxAttempts = 100000000
    $attemptDelay = 5

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            SetPrimaryScreen
            $primaryMonitorIds = Get-PrimaryMonitorIds
            $checks = foreach ($monitor in $primaryMonitorIds) {
                IsMonitorActive -monitorId $monitor
            }

            $successCount = ($checks | Where-Object { $_ -eq $true }).Count
            if ($successCount -ge $primaryMonitorIds.Count) {
                Write-Host "Monitor(s) have been successfully restored."
                break
            } else {
                Write-Host "Failed to restore display(s), some displays require multiple attempts and may not restore until returning back to the computer. Trying again after $attemptDelay seconds..."
            }
        }
        catch {
            ## Do Nothing, because we're expecting it to fail in cases like when the user has a TV as a primary display.
        }

        Start-Sleep -Seconds $attemptDelay
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
