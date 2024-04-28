$path = (Split-Path $MyInvocation.MyCommand.Path -Parent)
$scriptName = Split-Path $path -Leaf
Set-Location $path
$settings = Get-Content -Path .\settings.json | ConvertFrom-Json

function OnStreamStart() {
    return $true
}

function OnStreamEnd() {
    return $false
}