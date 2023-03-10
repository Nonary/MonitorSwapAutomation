$primaryMonitorId = "MONITOR\GSMC0C8\{4d36e96e-e325-11ce-bfc1-08002be10318}\0009"
# How many seconds to wait after a stream is suspended/terminated before swapping back.
$gracePeroid = 30
$configSaveLocation = $env:TEMP


function OnStreamStart() {
    Write-Output "Dummy plug activated"
    & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
}


function PrimaryScreenIsActive() {
    # For some displays, the primary screen can't be set until it wakes up from sleep.
    # This will continually poll the configuration to make sure the display has been set.

    & .\MultiMonitorTool.exe /SaveConfig "$configSaveLocation\current_monitor_config.cfg"
    Start-Sleep -Seconds 1
    $monitorConfigLines = (Get-Content -Path "$configSaveLocation\current_monitor_config.cfg" | Select-String "MonitorID=.*|SerialNumber=.*|Width.*|Height.*|DisplayFrequency.*")
    for ($i = 0; $i -lt $monitorConfigLines.Count; $i++) {
        $monitorId = ($monitorConfigLines[$i] -split "=") | Select-Object -Last 1

        if ($monitorId -eq $primaryMonitorId) {
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
        return "No Operating Necessary Because already streaming"
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
            # So start an infinite loop to check and set that.
            if (!(PrimaryScreenIsActive)) {
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

    Write-Host "Dummy Plug Deactivated, Restoring original monitor configuration!"


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

function IsAboutToStartStreaming() {
    # The difference with this function is that it checks to see if user recently queried the application list on the host.
    # Useful in scenarios where a script must run prior to starting a stream.
    # Sunshine already supports this functionaly, Geforce Experience does not.

    $connectionDetected = & netstat -a -i -n | Select-String 47989 | Where-Object { $_ -like '*TIME_WAIT*' } 
    [int] $duration = $connectionDetected -split " " | Where-Object { $_ } | Select-Object -Last 1
    return $null -ne $connectionDetected -and $duration -lt 1750
}


$streamStartEvent = $false
$streamEndEvent = $false
$lastStreamed = Get-Date

while ($true) {
    $streaming = (IsAboutToStartStreaming) -or (IsCurrentlyStreaming)

    if ($streaming) {
        $lastStreamed = Get-Date
        if (!($streamStartEvent)) {
            OnStreamStart
            $streamStartEvent = $true
            $streamEndEvent = $true
        }
        
    }
    else {
        if ($streamEndEvent -and ((Get-Date) - $lastStreamed).TotalSeconds -gt $gracePeroid) {
            OnStreamEnd
            $streamStartEvent = $false
            $streamEndEvent = $false
        }

    }
    Start-Sleep -Seconds 1
}