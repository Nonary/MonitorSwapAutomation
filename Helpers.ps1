param($terminate)
$path = (Split-Path $MyInvocation.MyCommand.Path -Parent)
$scriptName = Split-Path $path -Leaf
Set-Location $path
$script:attempt = 0

function OnStreamEndAsJob() {

    return Start-Job -Name "$scriptName-OnStreamEnd" -ScriptBlock {
        param($path)
        Set-Location $path
        . .\Helpers.ps1
        . .\Events.ps1
    
        Write-Host "Stream has ended, now invoking code"
        $job = Create-Pipe -pipeName "$scriptName-OnStreamEnd" 

        while ($true) {
            $maxTries = 25
            $tries = 0

            if ($job.State -eq "Completed" -or (IsCurrentlyStreaming)) {
                Write-Host "Another session of $scriptName was started, gracefully closing this one..."
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
        Send-PipeMessage "$scriptName-OnStreamEnd" Terminate
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

function Stop-Script() {
    Send-PipeMessage -pipeName $scriptName Terminate
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
            if (-not (Test-Path "\\.\pipe\$pipeName")) {
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
    Stop-Script | Out-Null
}
