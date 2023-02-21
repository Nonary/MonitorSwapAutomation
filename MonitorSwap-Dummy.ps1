# The ID after MONITOR\{ID}\
# Example: MONITOR\GSMC0C8\{4d36e96e-e325-11ce-bfc1-08002be10318}\0002
$primaryMonitor = "GSMC0C8"
$primarySerial = "LGTV"
$dummySerial = "DUMMY"
# How many seconds to wait after a stream is suspended/terminated before swapping back.
$gracePeroid = 30
$configSaveLocation = "C:\tools\monitorinfo.ini"

function OnStreamStart() {
    Write-Output "Dummy plug activated"
    & .\MultiMonitorTool.exe /SetPrimary /enable $dummySerial
    & .\MultiMonitorTool.exe /disable $primarySerial
}

function PrimaryScreenIsActive() {
    # For some displays, the primary screen can't be set until it wakes up from sleep.
    # This will continually poll the configuration to make sure the display has been set.

    & .\MultiMonitorTool.exe /SaveConfig $configSaveLocation
    $content = (Get-Content -Path $configSaveLocation | Select-String "MonitorID=.*|Width.*|Height.*|DisplayFrequency.*")
    for ($i = 0; $i -lt $content.Count; $i++) {
        $element = $content[$i]

        if ($element.ToString().Contains($primaryMonitor)) {
            $w = ($content[$i + 1] -split "=") | Select-Object -Last 1
            $h = ($content[$i + 2] -split "=") | Select-Object -Last 1
            $r = ($content[$i + 3] -split "=") | Select-Object -Last 1

            return ($h -ne 0 -and $w -ne 0) -and $r -eq 120
            Write-Host "$w $h $r"
        }
    }

    return $false
}

function SetPrimaryScreen() {
    Write-Host "Attempting to set primary screen"
    if(IsCurrentlyStreaming){
        return "No Operating Necessary Because already streaming"
    }
    ./MultiMonitorTool.exe /SetPrimary /enable $primarySerial
    Start-Sleep -Milliseconds 750
    & .\MultiMonitorTool.exe  /disable $dummySerial
}

function OnStreamEnd() {

    for ($i = 0; $i -lt 100000000; $i++) {
        try {

            if (IsCurrentlyStreaming) {
                break;
                return;
            }
            
            SetPrimaryScreen

            if (!(PrimaryScreenIsActive)) {
                SetPrimaryScreen
            }
            else {
                break
            }
            
        }
        catch {
            ## Do Nothing
        }
        finally {
            Start-Sleep -Seconds 5
        }
    }

    Write-Host "Dummy Plug Deactivated!"


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
    return $null -ne $connectionDetected -and $duration -lt 1500
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