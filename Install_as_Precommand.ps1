## Fun fact, most of this code is generated entirely using GPT-3.5

## CHATGPT PROMPT 1
## Explain to me how to parse a conf file in PowerShell.

## AI EXPLAINS HOW... this is important as it invokes reflective thinking.
## Having AI explain things to us first before asking 
## your question, significantly improves the quality of the response.


### PROMPT 2
### Okay, using this conf, can you write a powershell script that saves a new value to the global_prep_cmd?

### AI Generates valid code for saving to conf file

## Prompt 3
### I think I have found a mistake, can you double check your work?

## Again, this is important for reflective thinking, having the AI
## check its work is important, as it may improve quality. 

## Response: Did not find any errors.

## Prompt 4: I tried this and unfortunately my config file requires admin to save.

## AI Responses solutions

## Like before, I already knew the solution but having the AI
## respond with tips, greatly improves the quality of the next prompts

## Prompt 5 (Final with GPT3.5): Can you make this script self elevate itself.
## Repeat the same prompt principles, and basically 70% of this script is entirely written by Artificial Intelligence. Yay!

## Refactor Prompt (GPT-4): Please refactor the following code, remove duplication and define better function names, once finished you will also add documentation and comments to each function.
param($scriptPath)



# This script modifies the global_prep_cmd setting in the Sunshine configuration file
# to add a command that runs MonitorSwap-Dummy.ps1

# Check if the current user has administrator privileges
$isAdmin = [bool]([System.Security.Principal.WindowsIdentity]::GetCurrent().groups -match 'S-1-5-32-544')

# If the current user is not an administrator, re-launch the script with elevated privileges
if (-not $isAdmin) {
    Start-Process powershell.exe  -Verb RunAs -ArgumentList "-NoExit -File `"$($MyInvocation.MyCommand.Path)`" `"$(Join-Path -Path (Get-Location) -ChildPath "MonitorSwap-Dummy.ps1")`" $($MyInvocation.MyCommand.UnboundArguments)"
    exit
}

# Define the path to the Sunshine configuration file
$confPath = "C:\Program Files\Sunshine\config\sunshine.conf"
$settings = ConvertFrom-Json ([string](Get-Content -Path "$(Split-Path $scriptPath -Parent)/settings.json"))



function FillOut-VariableOnMainScript($variableName, $value) {
    # Define the path to the file you want to modify

    # Define the regular expression to search for and the new value you want to replace it with
    $searchPattern = "(\`$$variableName\s*=\s*)`"([^`"]*)`""

    # Read the contents of the file into a variable
    $content = Get-Content $scriptPath
    

    # Loop through each line in the file
    for ($i = 0; $i -lt $content.Count; $i++) {
        # If the current line matches the search pattern, replace it with the new value
        if ($content[$i] -match $searchPattern) {
            $content[$i] = $content[$i] -replace $searchPattern, "`$1`"$value`""
        }
    }

    # Write the modified contents back to the file
    $content | Set-Content $scriptPath

}

# Get the current value of global_prep_cmd from the configuration file
function Get-GlobalPrepCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    # Read the contents of the configuration file into an array of strings
    $config = Get-Content -Path $ConfigPath

    # Find the line that contains the global_prep_cmd setting
    $globalPrepCmdLine = $config | Where-Object { $_ -match '^global_prep_cmd\s*=' }

    # Extract the current value of global_prep_cmd
    if ($globalPrepCmdLine -match '=\s*(.+)$') {
        return $matches[1]
    }
    else {
        Write-Error "Unable to extract current value of global_prep_cmd"
        return [object[]]@()
    }
}

# Remove any existing commands that contain MonitorSwap-Dummy from the global_prep_cmd value
function Remove-MonitorSwapCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    # Get the current value of global_prep_cmd as a JSON string
    $globalPrepCmdJson = Get-GlobalPrepCommand -ConfigPath $ConfigPath

    # Convert the JSON string to an array of objects
    $globalPrepCmdArray = $globalPrepCmdJson | ConvertFrom-Json
    $filteredCommands = @()

    # Loop through the array in reverse order and remove any commands that contain MonitorSwap-Dummy
    for ($i = $globalPrepCmdArray.Count - 1; $i -ge 0; $i--) {
        if (-not ($globalPrepCmdArray[$i].do -like "*MonitorSwap-Dummy*")) {
            $filteredCommands += $globalPrepCmdArray[$i]
        }
    }

    # Return the modified array of objects
    return [object[]] $filteredCommands
}

# Set a new value for global_prep_cmd in the configuration file
function Set-GlobalPrepCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        # The new value for global_prep_cmd as an array of objects
        [Parameter(Mandatory)]
        [object[]]$Value
    )

    # Read the contents of the configuration file into an array of strings
    $config = Get-Content -Path $ConfigPath

    # Get the current value of global_prep_cmd as a JSON string
    $currentValueJson = Get-GlobalPrepCommand -ConfigPath $ConfigPath

    # Convert the new value to a JSON string
    $newValueJson = ConvertTo-Json -InputObject $Value -Compress

    # Replace the current value with the new value in the config array
    try {
        $config = $config -replace [regex]::Escape($currentValueJson), $newValueJson
    }
    catch {
        # If it failed, it probably does not exist yet.
        $config += "global_prep_cmd = $($newValueJson)"
    }



    # Write the modified config array back to the file
    $config | Set-Content -Path $ConfigPath -Force
}

# Add a new command to run MonitorSwap-Dummy.ps1 to the global_prep_cmd value
function Add-MonitorSwapCommand {
    param (
        # The path to the configuration file
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        # The path to the MonitorSwap-Dummy script
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    # Remove any existing commands that contain MonitorSwap-Dummy from the global_prep_cmd value
    [object[]]$globalPrepCmdArray = Remove-MonitorSwapCommand -ConfigPath $ConfigPath

    # Create a new object with the command to run MonitorSwap-Dummy.ps1
    $monitorSwapCommand = [PSCustomObject]@{
        do       = "powershell.exe -executionpolicy bypass -file `"$($ScriptPath)`""
        elevated = "false"
        undo     = "powershell.exe -executionpolicy bypass -command `"New-Item $($settings.configSaveLocation)/stream_ended.txt`""
    }

    # Add the new object to the global_prep_cmd array
    $globalPrepCmdArray += $monitorSwapCommand

    # Set the new value for global_prep_cmd in the configuration file
    Set-GlobalPrepCommand -ConfigPath $ConfigPath -Value $globalPrepCmdArray
}

FillOut-VariableOnMainScript -variableName "path" -value (Split-Path $scriptPath -Parent)
# Invoke the function to add the MonitorSwap-Dummy command
Add-MonitorSwapCommand -ConfigPath $confPath -ScriptPath $scriptPath


