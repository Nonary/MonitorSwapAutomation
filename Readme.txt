CAVEATS:
    If you are using Windows 11, you need to set your default terminal to "Windows Console Host"
    Windows Terminal is currently bugged and does not respect hiding powershell scripts.

    Once installing this script, you cannot move this folder as it will break the automation.
    If you need to move the folder, simply uninstall and install the script again.

Requirements:

For GFE users:
    None

For Sunshine Users
    Host must be Windows
    Sunshine must be installed a service (it does not work with the zip version of Sunshine)
    Sunshine logging level must be set to Debug
    Users must have read permissions to %WINDIR%/Temp/Sunshine.log (do not change other permissions, just make sure Users has atleast read permisisons)

1. Open up MultiMonitorTool and click on File -> Save Monitors Configuration and save it in the current folder this script is located in with the name of primary.cfg
2. Open up MultiMonitorTool and click on File -> Save Monitors Configuration and save it in the current folder this script is located in with the name of dummy.cfg
3. Open up the dummy.cfg file and set every parameter related to montor position, refresh, etc to -
example:
        Name=\\.\DISPLAY1
        MonitorID=MONITOR\GSMC0C8\{4d36e96e-e325-11ce-bfc1-08002be10318}\0009
        SerialNumber=LGTV
        BitsPerPixel=0
        Width=0
        Height=0
        DisplayFlags=0
        DisplayFrequency=0
        DisplayOrientation=0
        PositionX=0

In the example above, I set every value to 0 which lets the script know to turn it off.
4. In the primary.cfg file, locate your primary MonitorId and copy and paste it to the primaryMonitorId variable in the MonitorSwap-Dummy.ps1 file
    example: 
        $primaryMonitorId = "MONITOR\GSMC0C8\{4d36e96e-e325-11ce-bfc1-08002be10318}\0009"

5. Install the script by double clicking the Install Script.bat file.