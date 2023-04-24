. .\MonitorSwap-Functions.ps1

Describe "MonitorSwapper Tests" {

    
    BeforeAll {

        Mock Set-Location {}
        Mock Get-Content { return '{"configSaveLocation": "%TEMP%", "primaryMonitorId": 1, "gracePeriod": 5}' }
        Mock Export-MonitorConfiguration {}
        Mock Activate-DummyPlug {}
        Mock Activate-PrimaryScreen {}
        Mock IsSunshineUser { return $false }
        Mock Get-Process { return $null }
        Mock Get-NetUDPEndpoint { return $null }
        Mock Start-Sleep {}
    }


    Context "OnStreamStart" {
        It "should output 'Dummy plug activated'" {
            OnStreamStart | Should -Be "Dummy plug activated"
        }
        It "should call Activate-DummyPlug function" {
            OnStreamStart
            Assert-MockCalled Activate-DummyPlug 
        }
    }

    Context "PrimaryScreenIsActive" {

        $global:primaryMonitorId = "1"
        It "should call Export-MonitorConfiguration" {
            PrimaryScreenIsActive
            Assert-MockCalled Export-MonitorConfiguration
        }
        It "should return false when primary screen is not active" {
            Mock Get-Content { return "MonitorID=0`nSerialNumber=0`nWidth=0`nHeight=0`nDisplayFrequency=0" }
            PrimaryScreenIsActive | Should -Be $false
        }
        It "should return true when primary screen is active" {
            Mock Get-Content { return "MonitorID=1`nSerialNumber=1`nWidth=1920`nHeight=1080`nDisplayFrequency=60" }
            PrimaryScreenIsActive | Should -Be $true
        }
    }

    Context "SetPrimaryScreen" {
        It "should call Activate-PrimaryScreen when not streaming" {
            Mock IsCurrentlyStreaming { return $false }
            SetPrimaryScreen
            Assert-MockCalled Activate-PrimaryScreen
        }
        It "should not call Activate-PrimaryScreen when streaming" {
            Mock IsCurrentlyStreaming { return $true }
            SetPrimaryScreen
            Assert-MockCalled Activate-PrimaryScreen -Times 0
        }
    }

    Context "OnStreamEnd" {
        BeforeEach {
            Mock IsCurrentlyStreaming { return $false }
            Mock PrimaryScreenIsActive { return $true }
            Mock SetPrimaryScreen {}
        }
        It "should break the loop when currently streaming" {
            Mock IsCurrentlyStreaming { return $true }
            OnStreamEnd
            Should -Invoke SetPrimaryScreen -Times 0
        }
        It "should call SetPrimaryScreen" {
            OnStreamEnd
            Assert-MockCalled SetPrimaryScreen
        }
    }

    Context "IsSunshineUser" {

        BeforeAll {
            Remove-Item Alias:\IsSunshineUser -ErrorAction SilentlyContinue
            Remove-Alias IsSunshineUser -ErrorAction SilentlyContinue
        }

        AfterAll {
            Mock IsSunshineUser { return $true }
        }

        It "should return true when sunshine process exists" {
            Mock Get-Process { return "Yes" }
            IsSunshineUser | Should -Be $true
        }
        It "should return false when sunshine process does not exist" {
            Mock Get-Process { return $null }
            IsSunshineUser | Should -Be $false
        }
    }

    Describe "IsCurrentlyStreaming" {
        It "should return true when Sunshine user and has a UDP endpoint" {
            Mock IsSunshineUser { return $true }
            Mock Get-Process { return [PSCustomObject]@{ Id = 1 } }
            Mock Get-NetUDPEndpoint { return [PSCustomObject]@{ OwningProcess = 1 } }
            IsCurrentlyStreaming | Should -Be $true
        }
        It "should return false when Sunshine user but has no UDP endpoint" {
            Mock IsSunshineUser { return $true }
            Mock Get-Process { return [PSCustomObject]@{ Id = 1 } }
            Mock Get-NetUDPEndpoint { return $null }
            IsCurrentlyStreaming | Should -Be $false
        }
        It "should return true when nvstreamer process exists" {
            Mock IsSunshineUser { return $false }
            Mock Get-Process { return [PSCustomObject]@{ Name = "nvstreamer" } }
            IsCurrentlyStreaming | Should -Be $true
        }
        It "should return false when nvstreamer process does not exist" {
            Mock IsSunshineUser { return $false }
            Mock Get-Process { return $null }
            IsCurrentlyStreaming | Should -Be $false
        }
    }

    Describe "Stop-MonitorSwapperScript" {
        BeforeEach {
            Mock Get-ChildItem { return [PSCustomObject]@{ Name = "MonitorSwapper" } }
            Mock New-Object {
                switch ($TypeName) {
                    'System.IO.Pipes.NamedPipeClientStream' {
                        return [PSCustomObject]@{} | Add-Member -MemberType ScriptMethod -Name "Connect" -Value {} -PassThru
                    }
                    'System.IO.StreamWriter' {
                        return [PSCustomObject]@{} | Add-Member -MemberType ScriptMethod -Name "WriteLine" -Value {} -PassThru
                    }
                }
            }
        }
        It "should call Get-ChildItem with '\\.\pipe\'" {
            Stop-MonitorSwapperScript
            Assert-MockCalled Get-ChildItem -ParameterFilter { $Path -eq "\\.\pipe\" }
        }
        It "Should call terminate against the named pipe to end the main script" {
            Stop-MonitorSwapperScript
            Assert-MockCalled -CommandName New-Object -ParameterFilter { $TypeName -eq 'System.IO.StreamWriter' } -Exactly -Times 1
        }

        It "If named pipe does not exist, should not call Terminate"
        {
            Mock Get-ChildItem {return @()}

        }
    }
    
}

