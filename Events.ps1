# Determine the path of the currently running script and set the working directory to that path
$path = (Split-Path $MyInvocation.MyCommand.Path -Parent)
Set-Location $path

# Load settings from a JSON file located in the same directory as the script
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json
$configSaveLocation = [System.Environment]::ExpandEnvironmentVariables($settings.configSaveLocation)
$dummyMonitorId = $settings.dummyMonitorId

. .\Helpers.ps1

function OnStreamStart() {
    # Attempt to load the dummy profile for up to 5 times in total.
    # Always try to restore it at least once, due to a bug in Windows... if a profile restoration fails (especially when switching back to the primary screen),
    # and a stream is initiated again, the display switcher built into windows (Windows + P) may not update and remain stuck on the last used setting.
    # This can cause significant problems in some games, including frozen visuals and black screens.    
    & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
    Start-Sleep -Seconds 2
    for ($i = 0; $i -lt 6; $i++) {
        if (-not (IsMonitorActive -monitorId $dummyMonitorId)) {
            & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
        }
        else {
            break;
        }
        if ($i -eq 5) {
            Write-Host "Failed to verify dummy plug was activated, did you make sure dummyMonitorId was included and was properly escaped with double backslashes?"
            return;
        }
        Start-Sleep -Seconds 1
    }

    Write-Output "Dummy plug activated"
}

function OnStreamEnd() {
    try {
        # Check if the primary monitor is not active
        if (-not (IsPrimaryMonitorActive)) {
            # Attempt to set the primary screen if it is not already set.
            SetPrimaryScreen
        }

        # Check again if the primary monitor is not active after the first attempt to set it.
        if (-not (IsPrimaryMonitorActive)) {
            if (($script:attempt++ -eq 1) -or ($script:attempt % 120 -eq 0)) {
                # Output a message to the host indicating difficulty in restoring the display.
                # This message is shown once initially, and then once every 10 minutes.
                Write-Host "Failed to restore display(s), some displays require multiple attempts and may not restore until returning back to the computer. Trying again after 5 seconds... (this message will be supressed to only show up once every 10 minutes)"
            }
            
            # Return false indicating the primary monitor is still not active.
            # If we reached here, that indicates the first two attempts had failed.
            return $false
        }

        # Primary monitor is active, return true.
        Write-Host "Primary monitor(s) have been successfully restored!"
        return $true
    }
    catch {
        ## Do Nothing, because we're expecting it to fail in cases like when the user has a TV as a primary display.
    }

    # Return false by default if an exception occurs.
    return $false
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
        return
    }

    & .\MultiMonitorTool.exe /LoadConfig "primary.cfg"

    Start-Sleep -Seconds 3
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

function IsPrimaryMonitorActive() {
    $primaryMonitorIds = Get-PrimaryMonitorIds

    $checks = foreach ($monitor in $primaryMonitorIds) {
        IsMonitorActive -monitorId $monitor
    }

    $successCount = ($checks | Where-Object { $_ -eq $true }).Count
    if ($successCount -ge $primaryMonitorIds.Count) {
        return $true
    }

    return $false
}

