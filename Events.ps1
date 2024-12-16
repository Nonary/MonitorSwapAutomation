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

$script:attempts = 0

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
    Write-Debug "Loading dummy monitor configuration from Dummy.xml"
    & .\MonitorSwitcher.exe -load:Dummy.xml 
    Start-Sleep -Seconds 2

    for ($i = 0; $i -lt 6; $i++) {
        Write-Debug "Attempt $i to check if dummy monitor is active"
        $dummyMonitorId = Get-MonitorIdFromXML -filePath ".\Dummy.xml"
        if (-not (IsMonitorActive -monitorId $dummyMonitorId)) {
            Write-Debug "Dummy monitor is not active, reloading dummy configuration"
            & .\MonitorSwitcher.exe -load:Dummy.xml 
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
        Write-Debug "Now attempting to restore the primary monitor"
        SetPrimaryScreen

        if ((IsPrimaryMonitorActive)) {
            # Primary monitor is active, return true.
            Write-Host "Primary monitor(s) have been successfully restored!"
            Write-Debug "Primary monitor is active, returning true"
            return $true
           
        }
        else {
            Write-Debug "Primary monitor failed to be restored, this is most likely because the display is currently not available."
            if (($script:attempts++ -eq 1) -or ($script:attempts % 120 -eq 0)) {
                # Output a message to the host indicating difficulty in restoring the display.
                # This message is shown once initially, and then once every 10 minutes.
                Write-Host "Failed to restore display(s), some displays require multiple attempts and may not restore until returning back to the computer. Trying again after 5 seconds... (this message will be suppressed to only show up once every 10-15 minutes)"
            }

            # Return false indicating the primary monitor is still not active.
            return $false
        }
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
    # Continually poll the configuration to ensure the display is fully updated.
    $filePath = "$configSaveLocation\current_monitor_config.xml"
    Write-Debug "Saving current monitor configuration to $filePath"
    & .\MonitorSwitcher.exe -save:$filePath
    Start-Sleep -Seconds 1

    $currentTime = Get-Date
    Write-Debug "Current time: $currentTime"

    # Check when the file was last updated
    $fileLastWriteTime = (Get-Item $filePath).LastWriteTime
    Write-Debug "File last write time: $fileLastWriteTime"

    # Calculate the time difference in minutes
    $timeDifference = ($currentTime - $fileLastWriteTime).TotalMinutes
    Write-Debug "Time difference in minutes: $timeDifference"

    # If the file isn't recent, it might be a stale configuration leading to a false positive
    if ($timeDifference -gt 1) {
        Write-Debug "File was not saved recently. Potential false positive."
        return $false        
    }

    Write-Debug "Reading monitor configuration from $filePath"
    [xml]$xml = Get-Content -Path $filePath

    # Find the path info node that matches the given monitorId
    # The monitorId is found in the targetInfo.id element.
    foreach ($path in $xml.displaySettings.pathInfoArray.DisplayConfigPathInfo) {
        if ($path.targetInfo.id -eq $monitorId) {
            Write-Debug "Found matching path for monitor ID: $monitorId"

            # Extract refresh rate
            $numerator = [int]$path.targetInfo.refreshRate.numerator
            $denominator = [int]$path.targetInfo.refreshRate.denominator
            $refresh = if ($denominator -ne 0) { $numerator / $denominator } else { 0 }

            # Locate the source mode info to get width and height
            $sourceModeIdx = [int]$path.sourceInfo.modeInfoIdx
            $sourceModeInfo = $xml.displaySettings.modeInfoArray.modeInfo[$sourceModeIdx]

            # Confirm that this modeInfo is a Source type
            if ($sourceModeInfo.DisplayConfigModeInfoType -eq 'Source') {
                $width = [int]$sourceModeInfo.DisplayConfigSourceMode.width
                $height = [int]$sourceModeInfo.DisplayConfigSourceMode.height
            }
            else {
                Write-Debug "Source mode not found as expected. Returning false."
                return $false
            }

            Write-Debug "Monitor width: $width, height: $height, refresh rate: $refresh"

            # Inactive displays are expected to have zero width, height, or refresh.
            $isActive = ($width -ne 0 -and $height -ne 0 -and $refresh -ne 0)
            Write-Debug "Monitor active status: $isActive"
            return $isActive
        }
    }

    Write-Debug "Monitor ID $monitorId not found in configuration"
    return $false
}



function SetPrimaryScreen() {
    Write-Debug "Starting SetPrimaryScreen function"

    Write-Debug "Checking if currently streaming"
    if (IsCurrentlyStreaming) {
        Write-Debug "Currently streaming, exiting function as this would cause performance issues to users who are currently streaming."
        return
    }
    else {
        Write-Debug "Verified user is currently not streaming."
    }

    Write-Debug "Loading primary monitor configuration from Primary.xml"
    & .\MonitorSwitcher.exe -load:Primary.xml

    Write-Debug "Sleeping for 3 seconds to allow configuration to take effect"
    Start-Sleep -Seconds 3

    Write-Debug "SetPrimaryScreen function completed"
}

function Get-MonitorIdFromXML($filePath) {
    Write-Debug "Starting Get-MonitorIdFromXML function for filePath: $filePath"

    # Load the XML from the file
    [xml]$xml = Get-Content -Path $filePath

    # Prepare the array to hold primary monitor IDs
    $primaryMonitorIds = @()

    # Iterate through each DisplayConfigPathInfo node in the XML
    foreach ($path in $xml.displaySettings.pathInfoArray.DisplayConfigPathInfo) {
        # Extract the monitor ID from the targetInfo section
        $monitorId = $path.targetInfo.id

        # Extract the refresh rate numerator and denominator
        $numerator = [int]$path.targetInfo.refreshRate.numerator
        $denominator = [int]$path.targetInfo.refreshRate.denominator

        # Calculate the refresh rate
        $refreshRate = 0
        if ($denominator -ne 0) {
            $refreshRate = $numerator / $denominator
        }

        Write-Debug "Monitor ID: $monitorId, Refresh rate: $refreshRate"

        # If refresh rate is not zero, consider it an active (primary) monitor
        if ($refreshRate -ne 0) {
            Write-Debug "Adding active monitor ID: $monitorId"
            $primaryMonitorIds += $monitorId
        }
        else {
            Write-Debug "Skipping inactive monitor ID: $monitorId"
        }
    }

    Write-Debug "Primary monitor IDs: $($primaryMonitorIds -join ', ')"
    return $primaryMonitorIds
}



function IsPrimaryMonitorActive() {
    $filePath = "$configSaveLocation\current_monitor_config.xml"

    Write-Debug "Saving current monitor configuration to $filePath"
    & .\MonitorSwitcher.exe -save:$filePath
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

    [string[]]$primaryProfile = Get-MonitorIdFromXML -filePath "Primary.xml" -as [string[]]
    Write-Debug "Primary monitor IDs: $primaryProfile"

    Write-Debug "Getting primary monitor IDs from current configuration file"
    [string[]]$currentProfile = Get-MonitorIdFromXML -filePath $filePath -as [string[]] 
    Write-Debug "Current monitor IDs: $currentProfile"



    $comparisonResults = Compare-Object $primaryProfile $currentProfile

    if ($null -ne $comparisonResults) {
        Write-Debug "Primary monitor IDs do not match current configuration. Returning false."
        Write-Debug $comparisonResults
        return $false
    }

    Write-Debug "Primary monitor IDs match current configuration. Returning true."
    return $true
}

