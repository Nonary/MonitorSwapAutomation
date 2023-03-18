# README

This script automates the process of switching your primary monitor with a dummy monitor using MultiMonitorTool. This is useful for users of Sunshine (a screen sharing software) who experience issues with sharing their primary monitor.

## CAVEATS

- If you are using Windows 11, you need to set your default terminal to "Windows Console Host". Windows Terminal is currently bugged and does not respect hiding PowerShell scripts.
- Once installing this script, you cannot move this folder as it will break the automation. If you need to move the folder, simply uninstall and install the script again.

## REQUIREMENTS

### For GFE users

- None

### For Sunshine users

- Host must be Windows
- Sunshine must be installed as a service (it does not work with the zip version of Sunshine)
- Sunshine logging level must be set to Debug
- Users must have read permissions to `%WINDIR%/Temp/Sunshine.log` (do not change other permissions, just make sure Users have at least read permissions)

## INSTRUCTIONS

1. Open up MultiMonitorTool and click on `File -> Save Monitors Configuration` and save it in the current folder this script is located in with the name of `primary.cfg`.
2. Open up MultiMonitorTool and click on `File -> Save Monitors Configuration` and save it in the current folder this script is located in with the name of `dummy.cfg`.
3. Open up the `dummy.cfg` file and set every parameter related to your primary monitors position, refresh rate, etc. to `0`. For example:

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

    In the example above, every numerical value has been set to 0, which lets the script know to turn it off.
4. In the `MonitorSwap-Dummy.ps1` file, locate your primary `MonitorId` and copy and paste it to the `primaryMonitorId` variable. For example:

        $primaryMonitorId = "MONITOR\GSMC0C8\{4d36e96e-e325-11ce-bfc1-08002be10318}\0009"

5. Install the script by double-clicking the `Install Script.bat` file.

## TROUBLESHOOTING

If you encounter issues with the script, you can try the following:

- Check that your primary monitor `MonitorId` matches the value in the `primaryMonitorId` variable in the `MonitorSwap-Dummy.ps1` file.
- Check that you have set every parameter related to the primary monitors resolution in the `dummy.cfg` file to `0`.
- Ensure that you have followed the requirements for Sunshine users as listed above.
- If you are still experiencing issues, try uninstalling and reinstalling the script.
