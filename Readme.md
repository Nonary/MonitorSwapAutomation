# README

This script automates the process of switching your primary monitor with a dummy monitor using MultiMonitorTool. 
This is useful for users of Sunshine (a screen sharing software) who experience issues with sharing their primary monitor.

## Caveats:
 - If using Windows 11, you'll need to set the default terminal to Windows Console Host as there is currently a bug in Windows Terminal that prevents hidden consoles from working properly.
    * That can be changed at Settings > Privacy & security > Security > For developers > Terminal [Let Windows decide] >> (change to) >> Terminal [Windows Console Host]
 - Prepcommands do not work from cold reboots, and will prevent Sunshine from working until you logon locally.
   * You should add a new application (with any name you'd like) in the WebUI and leave **both** the command and detached command empty.
   * When adding this new application, make sure global prep command option is disabled.
   * That will serve as a fallback option when you have to remote into your computer from a cold start.
   * Normal reboots issued from start menu, will still work without the workaround above as long as Settings > Accounts > Sign-in options and "Use my sign-in info to automatically finish setting up after an update" is enabled which is default in Windows 10 & 11.
 - The script will stop working if you move the folder, simply reinstall it to resolve that issue.
 - In the Sunshine WEB UI, make sure you leave the Output Name blank under the Audio/Video tab, otherwise it could cause breaking behavior with this script.


## REQUIREMENTS

### For GFE users

- This script no longer supports GFE, but you are able to retrieve a legacy version of this script that does support it: https://github.com/Nonary/MonitorSwapAutomation/releases/tag/legacy

### For Sunshine users
- Version 0.19.1 or higher
- Host must be Windows
- Sunshine must be installed as a service (it does not work with the zip version of Sunshine)
- Sunshine logging level must be set to Debug
- Users must have read permissions to `%WINDIR%/Temp/Sunshine.log` (do not change other permissions, just make sure Users have at least read permissions)

## INSTRUCTIONS

1. Open up MultiMonitorTool and click on `File -> Save Monitors Configuration` and save it in the current folder this script is located in with the name of `primary.cfg`.
2. Repeat the same steps of step 1, except save it with the name of `dummy.cfg`.
3. Open up the `dummy.cfg` file and set every parameter related to your primary monitor's position, refresh rate, etc. to `0`. For example:

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
        
        Name=\\.\DISPLAY11
        MonitorID=MONITOR\XMD29831\{4d36e96e-e325-11ce-bfc1-08002be10318}\0007
        SerialNumber=DUMMY
        BitsPerPixel=32
        Width=3840
        Height=2160
        DisplayFlags=0
        DisplayFrequency=120
        DisplayOrientation=0
        PositionX=0

    In the example above, every numerical value has been set to 0, which lets the script know that the display should be turned off.
    Also take note in the example, that my dummy display should have values configured to let it know that it should be turned on.

4. Verify that the `dummy.cfg` file has only **one** display that contains values for the `BitsPerPixel`, `Width`, `Height`, and so on. 
4a. For the `primary.cfg file`, it does not matter if there are other displays enabled, but you would want to make sure your dummy is "zeroed out" so you don't end up with an invisible monitor.
5. Basically, primary will "zero out" the dummy plug, and dummy will "zero out" the main display. This will automatically transfer games and windows back to the primary monitor if setup this way.
6. In the `dummy.cfg` file, locate your dummy `MonitorId` and copy and paste it to the `dummyMonitorId` key in the settings.json file. Make sure to escape the backslashes.
7. Validate you have escaped the backslashes, below is an example of a valid settings.json file.
    ```
    {
    "startDelay": 2,
    "gracePeriod": 60,
    "configSaveLocation": "%TEMP%",
    "dummyMonitorId": "MONITOR\\XMD009A\\{4d36e96e-e325-11ce-bfc1-08002be10318}\\0010"
    }
    ```

8. Install the script by double clicking the Install.bat file, you may get a smart-screen warning... this is normal.
9. You will be prompted for administrator rights, as modifying Sunshine configuration will require admin rights in the coming future.
10. Verify that the sunshine.conf file is configured properly, if successful the global_prep_cmd should look like this
    global_prep_cmd = [{"do":"powershell.exe -executionpolicy bypass -file \"F:\\sources\\MonitorSwapAutomation\\MonitorSwap-Dummy.ps1\"","elevated":"false","undo":"powershell.exe -executionpolicy bypass -file \"F:\\sources\\MonitorSwapAutomation\\MonitorSwap-Functions.ps1\" True"}]

The paths referenced above will vary on your machine.
## TROUBLESHOOTING

If you encounter issues with the script, you can try the following:

#### Monitor is not swapping before stream or afterwards
- Check that your dummy monitor `MonitorId` matches the value in the `dummyMonitorId` variable in the `settings.json` file.
- Check that you have escaped the backslashes for dummyMonitorId in the `settings.json` file.
  Valid: MONITOR\\\\GSMC0C8\\\\{4d36e96e-e325-11ce-bfc1-08002be10318}\\\\0009

  Invalid: MONITOR\GSMC0C8\{4d36e96e-e325-11ce-bfc1-08002be10318}\0009
  
- Check that you have set every parameter related to the primary monitor's resolution in the `dummy.cfg` file to `0`.
- Check that you have set every parameter related to the dummy monitor's resolution in the `primary.cfg` file to `0`.
- Check that you have at least one monitor not "zeroed out" in both the primary.cfg and dummy.cfg files.
- Ensure that you have followed the requirements for Sunshine users as listed above.
- Increase the startDelay in the settings file if you're experiencing the script only works intermitently.
- If you are still experiencing issues, try uninstalling and installing it again.

#### Only one screen is being restored, everything else works
- You will have to do this workaround mentioned here: https://github.com/Nonary/MonitorSwapAutomation/issues/9 
  - There is currently a bug in the MultiMonitor tool in some scenarios with people who have dual screens. I do not have the source code for that tool, so it is impossible for me to fix directly, a workaround has to be done until resolved by Nirsoft. Please report your issue to [nirsofer@yahoo.com](mailto:nirsofer@yahoo.com) so he can gather more users and data to ultimately resolve this issue.

### Recent Changes
- Fixes a bug that prevented the script from restoring the display in some scenarios, if user left their Moonlight client at the host screen.
- Fixed a bug that prevented the script from self-terminating itself after the user suspended the session longer than their defined grace period in the settings file.
-  Better multi-monitor support by validating that all screens have been restored instead of just the main primary one.
-  Primary monitor id is no longer required in settings and has been removed, script will now automatically figure out the primary monitors identity.
