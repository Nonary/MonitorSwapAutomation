param($terminate)
$path = (Split-Path $MyInvocation.MyCommand.Path -Parent)
Set-Location $path
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json
$configSaveLocation = [System.Environment]::ExpandEnvironmentVariables($settings.configSaveLocation)
$dummyMonitorId = $settings.dummyMonitorId
$script:attempt = 0


function OnStreamStart() {
    # Attempt to load the dummy profile for up to 5 times in total.
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


function OnStreamEndAsJob() {

    return Start-Job -Name "MonitorSwapper-OnStreamEnd" -ScriptBlock {
        param($path)
        Set-Location $path
        . .\MonitorSwapper-Functions.ps1
    
        Write-Host "Attempting to set primary screen, some displays may not activate until you return to the computer"
        $job = Create-Pipe -pipeName "MonitorSwapper-OnStreamEnd" 

        while ($true) {
            $maxTries = 25
            $tries = 0

            if ($job.State -eq "Completed" -or (IsCurrentlyStreaming)) {
                break;
            }

            while (($tries -lt $maxTries) -and ($job.State -ne "Completed")) {
                Start-Sleep -Milliseconds 200
                $tries++
            }


            if ((OnStreamEnd)) {
                break;
            }
        } 
        # We no longer need to listen for the end command since we've already restored at this point.
        Send-PipeMessage MonitorSwapper-OnStreamEnd Terminate
    } -ArgumentList $path
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
    Send-PipeMessage -pipeName MonitorSwapper Terminate
}


function Send-PipeMessage($pipeName, $message) {
    $pipeExists = Get-ChildItem -Path "\\.\pipe\" | Where-Object { $_.Name -eq $pipeName } 
    if ($pipeExists.Length -gt 0) {
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName, [System.IO.Pipes.PipeDirection]::Out)
        $pipe.Connect(3)
        $streamWriter = New-Object System.IO.StreamWriter($pipe)
        $streamWriter.WriteLine($message)
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

function Create-Pipe($pipeName) {
    return Start-Job -Name "$pipeName-PipeJob" -ScriptBlock {
        param($pipeName) 
        
        for ($i = 0; $i -lt 10; $i++) {
            # We could be pending a previous termination, so lets wait up to 10 seconds.
            if(-not (Test-Path "\\.\pipe\$pipeName")){
                break
            }
            
            Start-Sleep -Seconds 1
        }
        Remove-Item "\\.\pipe\$pipeName" -ErrorAction Ignore
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
    } -ArgumentList $pipeName
}

if ($terminate) {
    Stop-MonitorSwapperScript | Out-Null
}
