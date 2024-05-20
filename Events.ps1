param(
    [Parameter(Position = 0, Mandatory = $true)]
    [Alias("n")]
    [string]$scriptName
)
$path = (Split-Path $MyInvocation.MyCommand.Path -Parent)
Set-Location $path
. .\Helpers.ps1 -n $scriptName

# Load settings from a JSON file located in the same directory as the script
$settings = Get-Settings

# Initialize a script scoped dictionary to store variables.
# This dictionary is used to pass parameters to functions that might not have direct access to script scope, like background jobs.
if (-not $script:arguments) {
    $script:arguments = @{}
}

# Load settings from a JSON file located in the same directory as the script
$settings = Get-Settings
$configSaveLocation = [System.Environment]::ExpandEnvironmentVariables($settings.configSaveLocation)
$dummyMonitorId = $settings.dummyMonitorId


function OnStreamStart() {
    if ($settings.debug) {
        $script:arguments['debug'] = $true
    }
    Write-Debug "Starting OnStreamStart function"

    # Attempt to load the dummy profile for up to 5 times in total.
    # Always try to restore it at least once, due to a bug in Windows... if a profile restoration fails (especially when switching back to the primary screen),
    # and a stream is initiated again, the display switcher built into windows (Windows + P) may not update and remain stuck on the last used setting.
    # This can cause significant problems in some games, including frozen visuals and black screens.    
    Write-Debug "Loading dummy monitor configuration from dummy.cfg"
    & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
    Start-Sleep -Seconds 2

    for ($i = 0; $i -lt 6; $i++) {
        Write-Debug "Attempt $i to check if dummy monitor is active"
        if (-not (IsMonitorActive -monitorId $dummyMonitorId)) {
            Write-Debug "Dummy monitor is not active, reloading dummy configuration"
            & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
        }
        else {
            Write-Debug "Dummy monitor is active, exiting loop"
            break
        }

        if ($i -eq 5) {
            Write-Host "Failed to verify dummy plug was activated, did you make sure dummyMonitorId was included and was properly escaped with double backslashes?"
            Write-Debug "Failed to activate dummy plug after 5 attempts"
            return
        }

        Start-Sleep -Seconds 1
    }

    Write-Output "Dummy plug activated"
    Write-Debug "Dummy plug activated successfully"
}


function OnStreamEnd($kwargs) {
    Write-Debug "Starting OnStreamEnd function"

    try {
        # Check if the primary monitor is not active
        Write-Debug "Checking if the primary monitor is active"
        if (-not (IsPrimaryMonitorActive)) {
            Write-Debug "Primary monitor is not active, attempting to set primary screen"
            # Attempt to set the primary screen if it is not already set.
            SetPrimaryScreen
        }

        # Check again if the primary monitor is not active after the first attempt to set it.
        Write-Debug "Re-checking if the primary monitor is active"
        if (-not (IsPrimaryMonitorActive)) {
            Write-Debug "Primary monitor is still not active after the first attempt"
            if (($script:attempt++ -eq 1) -or ($script:attempt % 120 -eq 0)) {
                # Output a message to the host indicating difficulty in restoring the display.
                # This message is shown once initially, and then once every 10 minutes.
                Write-Host "Failed to restore display(s), some displays require multiple attempts and may not restore until returning back to the computer. Trying again after 5 seconds... (this message will be suppressed to only show up once every 10 minutes)"
                Write-Debug "Output message to host about difficulty in restoring display"
            }

            # Return false indicating the primary monitor is still not active.
            # If we reached here, that indicates the first two attempts had failed.
            Write-Debug "Returning false as primary monitor is still not active"
            return $false
        }

        # Primary monitor is active, return true.
        Write-Host "Primary monitor(s) have been successfully restored!"
        Write-Debug "Primary monitor is active, returning true"
        return $true
    }
    catch {
        Write-Debug "Caught an exception, expected in cases like when the user has a TV as a primary display"
        # Do Nothing, because we're expecting it to fail in cases like when the user has a TV as a primary display.
    }

    # Return false by default if an exception occurs.
    Write-Debug "Returning false by default due to exception"
    return $false
}


function IsMonitorActive($monitorId) {
    Write-Debug "Starting IsMonitorActive function for monitorId: $monitorId"

    # For some displays, the primary screen can't be set until it wakes up from sleep.
    # This will continually poll the configuration to make sure the display has been set.
    $filePath = "$configSaveLocation\current_monitor_config.cfg"
    Write-Debug "Saving current monitor configuration to $filePath"
    & .\MultiMonitorTool.exe /SaveConfig $filePath
    Start-Sleep -Seconds 3

    $currentTime = Get-Date
    Write-Debug "Current time: $currentTime"

    # Get the file's last write time
    $fileLastWriteTime = (Get-Item $filePath).LastWriteTime
    Write-Debug "File last write time: $fileLastWriteTime"

    # Calculate the time difference in minutes
    $timeDifference = ($currentTime - $fileLastWriteTime).TotalMinutes
    Write-Debug "Time difference in minutes: $timeDifference"

    # Check if the file was saved in the last minute, if it has not been saved recently, then we could have a potential false positive.
    if ($timeDifference -gt 1) {
        Write-Debug "File was not saved recently. Potential false positive."
        return $false        
    }

    Write-Debug "Reading monitor configuration from $filePath"
    $monitorConfigLines = (Get-Content -Path $filePath | Select-String "MonitorID=.*|SerialNumber=.*|Width.*|Height.*|DisplayFrequency.*")
    
    Write-Debug "Iterating over monitor configuration lines"
    for ($i = 0; $i -lt $monitorConfigLines.Count; $i++) {
        $configMonitorId = ($monitorConfigLines[$i] -split "=") | Select-Object -Last 1
        Write-Debug "Checking monitor ID: $configMonitorId"

        if ($configMonitorId -eq $monitorId) {
            Write-Debug "Found matching monitor ID: $configMonitorId"
            $width = ($monitorConfigLines[$i + 2] -split "=") | Select-Object -Last 1
            $height = ($monitorConfigLines[$i + 3] -split "=") | Select-Object -Last 1
            $refresh = ($monitorConfigLines[$i + 4] -split "=") | Select-Object -Last 1

            Write-Debug "Monitor width: $width, height: $height, refresh rate: $refresh"

            # Inactive displays will be zero on everything basically.
            $result = ($height -ne 0 -and $width -ne 0 -and $refresh -ne 0)
            Write-Debug "Monitor active status: $result"
            return $result
        }
        else {
            Write-Debug "Monitor ID $configMonitorId does not match $monitorId. Skipping next four lines."
            # It's not necessary to check the next four lines because it's not the monitor we want.
            $i += 4
        }
    }

    Write-Debug "Monitor ID $monitorId not found in configuration"
    return $false
}


function SetPrimaryScreen() {
    Write-Debug "Starting SetPrimaryScreen function"

    Write-Debug "Checking if currently streaming"
    if (IsCurrentlyStreaming) {
        Write-Debug "Currently streaming, exiting function"
        return
    }

    Write-Debug "Loading primary monitor configuration from primary.cfg"
    & .\MultiMonitorTool.exe /LoadConfig "primary.cfg"

    Write-Debug "Sleeping for 3 seconds to allow configuration to take effect"
    Start-Sleep -Seconds 3

    Write-Debug "SetPrimaryScreen function completed"
}

function Get-PrimaryMonitorIds($filePath) {
    Write-Debug "Starting Get-PrimaryMonitorIds function for filePath: $filePath"

    $pattern = '(?<=MonitorID=)(?<id>.*)|(?<=DisplayFrequency=)(?<freq>\d+)'
    $primaryMonitorIds = @()
    $foundMonitors = [regex]::Matches((Get-Content -Raw -Path $filePath), $pattern)
    Write-Debug "Found monitor matches: $($foundMonitors.Count)"

    for ($i = 0; $i -lt $foundMonitors.Count; $i += 2) {
        $match = $foundMonitors[$i]
        $monitorId = $match.Groups[0].Value
        $refresh = $foundMonitors[$i + 1].Groups[0].Value

        Write-Debug "Monitor ID: $monitorId, Refresh rate: $refresh"

        if ($refresh -ne 0) {
            Write-Debug "Adding active monitor ID: $monitorId"
            $primaryMonitorIds += $monitorId.Trim()
        }
        else {
            Write-Debug "Skipping inactive monitor ID: $monitorId"
        }
    }

    Write-Debug "Primary monitor IDs: $($primaryMonitorIds -join ', ')"
    return $primaryMonitorIds
}


function IsPrimaryMonitorActive() {
    $filePath = "$configSaveLocation\current_monitor_config.cfg"

    Write-Debug "Saving current monitor configuration to $filePath"
    & .\MultiMonitorTool.exe /SaveConfig $filePath
    Start-Sleep -Seconds 3

    $currentTime = Get-Date
    Write-Debug "Current time: $currentTime"

    # Get the file's last write time
    $fileLastWriteTime = (Get-Item $filePath).LastWriteTime
    Write-Debug "File last write time: $fileLastWriteTime"

    # Calculate the time difference in minutes
    $timeDifference = ($currentTime - $fileLastWriteTime).TotalMinutes
    Write-Debug "Time difference in minutes: $timeDifference"

    # Check if the file was saved in the last minute, if it has not been saved recently, then we could have a potential false positive.
    if ($timeDifference -gt 1) {
        Write-Debug "File was not saved recently. Potential false positive."
        return $false        
    }

    Write-Debug "Getting primary monitor IDs from primary.cfg"
    [string[]]$primaryProfile = (Get-PrimaryMonitorIds -filePath "primary.cfg") -as [string[]] | Sort-Object
    Write-Debug "Primary monitor IDs: $primaryProfile"

    Write-Debug "Getting primary monitor IDs from current configuration file"
    [string[]]$currentProfile = (Get-PrimaryMonitorIds -filePath $filePath) -as [string[]] | Sort-Object
    Write-Debug "Current monitor IDs: $currentProfile"



    $comparisonResults = Compare-Object $primaryProfile $currentProfile

    if($null -ne $comparisonResults){
        Write-Debug "Primary monitor IDs do not match current configuration. Returning false."
        Write-Debug $comparisonResults
        return $false
    }

    Write-Debug "Primary monitor IDs match current configuration. Returning true."
    return $true
}

