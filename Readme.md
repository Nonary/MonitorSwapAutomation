# README

This script automates the process of switching your primary monitor with a dummy monitor using MultiMonitorTool. 
This is useful for users of Sunshine (a screen sharing software) who experience issues with sharing their primary monitor.

## Caveats:
 - If using Windows 11, you'll need to set the default terminal to Windows Console Host as there is currently a bug in Windows Terminal that prevents hidden consoles from working properly.
    * That can be changed at Settings > System > For Developers > Terminal [Let Windows decide] >> (change to) >> Terminal [Windows Console Host]
    * On older versions of Windows 11 it can be found at: Settings > Privacy & security > Security > For developers > Terminal [Let Windows decide] >> (change to) >> Terminal [Windows Console Host]
 - The script will stop working if you move the folder, simply reinstall it to resolve that issue.
 - Due to Windows API restrictions, this script does not work on cold reboots (hard crashes or shutdowns of your computer).
    * If you're cold booting, simply sign into the computer using the "Desktop" app on Moonlight, then end the stream, then start it again. 
 - In the Sunshine WEB UI, make sure you leave the Output Name blank under the Audio/Video tab, otherwise it could cause breaking behavior with this script.


## REQUIREMENTS

### For GFE users

- This script no longer supports GFE, but you are able to retrieve a legacy version of this script that does support it: https://github.com/Nonary/MonitorSwapAutomation/releases/tag/legacy

### For Sunshine users
- Version 0.19.1 or higher
- Host must be Windows

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
10. If there are no error messages presented on the screen, the script successfully installed and you can close the terminal.

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

#### ResolutionAutomation script isn't changing my resolution after connecting and or is intermittently working
  - First, ensure that MonitorSwapper is installed *first*, then install the [ResolutionAutomation](https://github.com/Nonary/ResolutionAutomation) script.
    - If you installed them out of order, uninstall both, then install MonitorSwapper, then ResolutionAutomation.
  - Adjust the start delay in the settings.json file to 3 or 4 seconds and that should resolve that issue.
    - Sometimes the swap can take longer to do and the resolution swap is happening on your primary screen
    - Adjusting the start delay will give the swap more time to complete, thus making sure resolution is changed on the correct monitor.

#### Only One Screen is Being Restored, Everything Else Works
- You will have to follow the workaround mentioned here: [MonitorSwapAutomation Issue #9](https://github.com/Nonary/MonitorSwapAutomation/issues/9)
  - There is currently a bug in the MultiMonitor tool affecting users with dual screens. I do not have the source code for that tool, so it is impossible for me to fix directly. A workaround is necessary until Nirsoft resolves this issue. Please report your issue to [nirsofer@yahoo.com](mailto:nirsofer@yahoo.com) so he can gather more users and data to ultimately resolve this issue.

#### Primary Monitor Wasn't Restored
Check the logs to see if they claim the primary monitor was successfully restored. If it was, enable `enableStrictRestoration` in the `settings.json` file by setting it to `true`. If the logs do not show it restored, it probably was closed out before the script could finish (in the case of reboots). In such cases, you can't do much to resolve it other than ensuring you do not reboot before returning to your machine.

#### Resolution Change When Resuming or Starting a New Stream
- Double-check and ensure you have put the correct `dummyMonitorId` in the `settings.json` file. This way, the script doesn't attempt to restore monitor profiles that are already active.

### Change Log

### v1.2.0
- **Hybrid GPU Script Support:** Implements changes required for the Hybrid GPU Fix (https://github.com/Nonary/DuplicateOutputFailFix). Allowing those with laptops to always force NVIDIA Encoding, etc.

### v1.1.9
- **Updated MultiMonitorTool:** Updated to v2.10.
- **Primary Monitor Validation:** Added a new option to increase the strictness of validation on restoring the primary monitor. This should reduce false positives for some users but may cause problems for others, so this option is not enabled by default.

#### v1.1.8
- **Debug Logging:** Added debug write statements across the app to facilitate easier troubleshooting of future issues.
- **Monitor Flicker Fix:** Resolved an issue causing the monitor to constantly flicker when applying the workaround mentioned in issue [#9](https://github.com/Nonary/MonitorSwapAutomation/issues/9).

#### v1.1.7
- **File Lock Fixes:** Reduced the frequency of issues causing file lockouts during the parsing of monitor configurations.
- **Improved Profile Restore:** Enhanced the validation logic to ensure all monitor IDs match, reducing the occurrence of false positives.

#### v1.1.6
- **Logging Fix:** Fixed an issue where the log file wasn't created if a new stream started before the monitor was restored from the previous session.
- **Code Update:** Updated the script to use the [SunshineScript Installer template](https://github.com/Nonary/SunshineScriptInstaller), simplifying the maintenance of the installation process for all projects.
