param($terminate)

Set-Location (Split-Path $MyInvocation.MyCommand.Path -Parent)
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json
$configSaveLocation = [System.Environment]::ExpandEnvironmentVariables($settings.configSaveLocation)
$primaryMonitorId = $settings.primaryMonitorId


function OnStreamStart() {
    Write-Output "Dummy plug activated"
    & .\MultiMonitorTool.exe /LoadConfig "dummy.cfg" 
}


function PrimaryScreenIsActive() {
    # For some displays, the primary screen can't be set until it wakes up from sleep.
    # This will continually poll the configuration to make sure the display has been set.
    Remove-Item -Path "$configSaveLocation\current_monitor_config.cfg" -ErrorAction SilentlyContinue
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

function Stop-MonitorSwapperScript() {

    $pipeExists = Get-ChildItem -Path "\\.\pipe\" | Where-Object { $_.Name -eq "MonitorSwapper" } 
    if ($pipeExists.Length -gt 0) {
        $pipeName = "MonitorSwapper"
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName, [System.IO.Pipes.PipeDirection]::Out)
        $pipe.Connect()
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
