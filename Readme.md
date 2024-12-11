# README

This tool helps automatically switch your main display between a “real” monitor and a “dummy” monitor when streaming with **Sunshine**.

**Key Idea:**  
- When you’re not streaming, your computer uses your normal monitor setup.
- When you start streaming (for example, using a mobile device to control your PC remotely with Moonlight), the script will switch to a dummy monitor. 


## Important Notes

1. **Windows 11 Users:**  
   Due to a bug, you must set the default terminal to **Windows Console Host**.  
   - On newer Windows 11 versions:  
     1. Open **Settings**  
     2. Go to **System > For Developers**  
     3. Find the **Terminal** setting that says "**Let Windows decide**"  
     4. Change it to **Terminal [Windows Console Host]**
   
   - On older Windows 11 versions:  
     1. Open **Settings**  
     2. Go to **Privacy & Security > Security > For Developers**  
     3. Find the **Terminal** option and change it from "**Let Windows decide**" to **Terminal [Windows Console Host]**.
   
   This is required for the script to work properly.

2. **Do Not Move the Script’s Folder:**  
   If you move the folder after installing, the script may stop working. If that happens, just reinstall it.

3. **Cold Reboots (Hard Crash or Full Shutdown) Issue:**  
   If you start your computer from a completely off state (a “cold boot”), the script cannot automatically switch the monitor right away due to Windows limitations.  
   **Workaround:**  
   - After a cold boot, sign into your PC using the “Desktop” app on Moonlight.  
   - Then end the stream and start it again.  
   After doing this once, the script will work normally again on subsequent uses.

4. **Sunshine WEB UI Setting:**  
   In the Sunshine Web UI, **do not fill in the “Output Name”** under the Audio/Video tab. Leave it blank.  
   If you set an output name, it can break how this script works.

---

## Requirements

- **For GFE (GeForce Experience) Users:**  
  This script no longer supports GFE. If you need the old version that works with GFE, get it here:  
  [Legacy Version Download](https://github.com/Nonary/MonitorSwapAutomation/releases/tag/legacy)

- **For Sunshine Users:**  
  - You need Sunshine version **0.19.1 or higher**  
  - Host computer must be running Windows.

---

## Step-by-Step Instructions

1. **IMPORTANT: Erase Display Output Settings on Sunshine WEB UI** 
   In the Sunshine Web UI, **do not fill in the “Output Name”** under the Audio/Video tab. Leave it blank.  
   If you set an output name, it can break how this script works.

2. **Install the Script:**  
   Follow the instructions provided with the script or the installer to get it set up on your computer.

3. **Set Your Desired Baseline Monitor Setup:**  
   Before saving any profiles, make sure your monitors are arranged exactly how you want them when you’re **not streaming**. This will be your “normal” setup.

4. **Save Your “Primary Monitor” Profile:**  
   - Open a **Terminal/Command Prompt window** in the folder where you saved the script.  
   - Type:  
     ```  
     .\MonitorSwitcher.exe -save:Primary.xml
     ```  
   This command saves a snapshot of your current monitor setup as “Primary.xml.”

5. **Prepare to Save Your “Dummy Monitor” Profile:**  
   Now you need to start a Moonlight stream from another device (like your phone or tablet) so you can see your PC’s screen even if the actual monitor goes black.

6. **Switch to the Dummy Monitor Setup (While Streaming):**  
   - With the stream running and using your other device to view your computer:  
     1. On your Windows PC, go to **Settings > System > Display**.  
     2. Change the setting to show only on the dummy display. (This might make your physical monitor go dark, but you’ll still see your PC screen on your remote device.)  
   
   Now your PC is using the dummy monitor as the “main display.”

7. **Save Your “Dummy Monitor” Profile:**  
   - While still in the folder on your PC (visible via your remote device), open Terminal again and type:  
     ```  
     .\MonitorSwitcher.exe -save:Dummy.xml
     ```  

8. **Finish Up:**  
   - End the stream on your mobile or remote device.  
   - Your display should now return to normal on your physical monitor.
   
   From now on, every time you start a stream, the script will automatically switch to the dummy display, and when you end the stream, it will switch back to your normal setup.


---

## Troubleshooting

**Problem: ResolutionAutomation Script Doesn’t Change Resolution or Works Intermittently**  
- First, ensure you installed **MonitorSwapper first**, and then the [ResolutionAutomation script](https://github.com/Nonary/ResolutionAutomation) after.  
  If you did it the other way around, uninstall both, then install MonitorSwapper first and ResolutionAutomation second.
  
- If you still have issues, try increasing the start delay in the **settings.json** file (found in the script’s folder) to 3 or 4 seconds. This gives the monitor swap process more time to complete before the resolution attempts to change.

---

## Change Log 

**v2.0.0**  
- Changed the script’s backend from Nirsoft MultiMonitorTool to MonitorSwitcher to address compatibility issues with Windows 24H2 and improve reliability.

**v1.2.0**  
- Added support changes required for Hybrid GPU fixes, helping laptop users force NVIDIA encoding.

**v1.1.9**  
- Updated MultiMonitorTool to v2.10 and added stricter validation for restoring primary monitors.

**v1.1.8**  
- Added debug logging to help troubleshoot issues.
- Fixed a monitor flicker issue related to a known workaround.

**v1.1.7 & v1.1.6**  
- Various fixes to improve file handling, profile restoration, and logging.
- Integrated updates from the SunshineScript Installer template.
