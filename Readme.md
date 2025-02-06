# README

This tool automatically switches your main display to a dummy plug (or any virtual display) that you have set up for **Sunshine**. The goal is to seamlessly switch from your normal monitor setup to a dummy display when you start streaming (e.g., using Moonlight on a mobile device).

## How It Works

- **Normal Operation:** When you’re not streaming, your PC uses your regular monitor arrangement.
- **While Streaming:** As soon as you start a Moonlight stream on another device, the script automatically switches to a dummy monitor configuration (or another specified monitor layout).

---

## Important Notes

1. **Dummy Plug / Virtual Display:**  
   This script is designed for systems with a dummy plug or virtual display, but it can be used in other scenarios. For instance, you can use it to switch from a dual-monitor setup to a single monitor while streaming.

2. **Windows 11 Users:**  
   Due to a known bug, you must set the default terminal to **Windows Console Host**.
   
   - On newer Windows 11 versions:
     1. Open **Settings**.
     2. Go to **System > For Developers**.
     3. Locate the **Terminal** setting (which defaults to "Let Windows decide").
     4. Change it to **Terminal [Windows Console Host]**.

   - On older Windows 11 versions:
     1. Open **Settings**.
     2. Go to **Privacy & Security > Security > For Developers**.
     3. Find the **Terminal** option.
     4. Change it from "Let Windows decide" to **Terminal [Windows Console Host]**.

   Without this setting, the script may not work correctly.

3. **Do Not Move the Script’s Folder After Installation:**  
   If you move the installation folder after setting up the script, it may stop working. In that case, simply reinstall it.

4. **Cold Reboots / Hard Crashes Issue:**  
   On a cold boot (from a fully powered-off state), Windows may not allow the script to switch monitors immediately.

   **Workaround:**  
   - After a cold boot, start your PC and log in using the "Desktop" stream option in Moonlight.
   - End the stream, then start it again.
   
   After doing this once, subsequent uses should work normally.

5. **Sunshine Web UI Setting:**  
   **Do not set an “Output Name” in the Sunshine Web UI under the Audio/Video tab.** Leave it blank. Setting an output name may break the script’s functionality.

---

## Requirements

- **For GFE (GeForce Experience) Users:**  
  This script no longer supports GFE. If you need the older version that worked with GFE, download the [Legacy Version](https://github.com/Nonary/MonitorSwapAutomation/releases/tag/legacy).

- **For Sunshine Users:**
  - Sunshine version **0.19.1 or higher**.
  - Host computer must be running Windows.

---

## Step-by-Step Setup for Monitor Configuration

1. **Sunshine Output Settings:**  
   - In the Sunshine Web UI, ensure the “Output Name” field is blank under **Audio/Video settings**.

2. **Install the Script:**  
   - Follow the provided installer instructions to set up the script on your computer.

3. **Set Your Baseline (Primary) Monitor Setup:**  
   - Arrange your monitors as desired for normal operation (e.g., when you’re not streaming).

4. **Save Your “Primary” Monitor Profile:**  
   - Open **Terminal/Command Prompt** in the script’s folder.
   - Run the following command:
     ```
     .\MonitorSwitcher.exe -save:Primary.xml
     ```
   - This creates a snapshot of your current monitor configuration as `Primary.xml`.

5. **Prepare to Save Your “Dummy” Monitor Profile:**  
   - Start a Moonlight stream from another device (e.g., phone, tablet) so you can view and control your PC remotely.  
   - This is essential because your physical monitor will go dark when switching to the dummy monitor.

6. **Configure the Dummy Monitor Setup (While Streaming):**  
   - With the remote stream running:
     1. On your Windows PC, open **Settings > System > Display**.
     2. Click **Identify** to determine the monitor number for streaming. For a dummy plug, identify the monitor number that is not physically visible.
     3. If multiple monitors are active, disconnect secondary monitors:
        - Select the monitor to disconnect (e.g., monitor #2).
        - Use the dropdown menu to choose **Disconnect this display**.
        - Repeat until only the primary monitor is active.
     4. Ensure you are remotely viewing the PC on another device before proceeding, as you will not be able to see the screen physically on this next step.
     5. In **Display settings**, set the dropdown to **Show only on {NUMBER}**, where `{NUMBER}` is the dummy/streaming monitor.
     6. If you do not see **Show only on {NUMBER}**
        - Select the dummy display, then click the dropdown and select "Extend desktop to this display"
        - Select the dummy display again and expand the "Multiple Displays" group (if not already done)
        - Click the "Make this my main display" checkbox
        - Click your other monitor that was previously the main display, then click the dropdown again, then click "Disconnect this display".
     7. While at your computer confirm the display settings by clicking "Keep Changes", use your other device that is currently streaming for guidance on moving the mouse.

7. **Save Your “Dummy” Monitor Profile:**  
   - In the Terminal (still in the script’s folder), run the following command:
     ```
     .\MonitorSwitcher.exe -save:Dummy.xml
     ```
   - This saves your dummy/streaming monitor configuration as `Dummy.xml`.

8. **Completing the Setup:**  
   - End the Moonlight stream session.  
   - Your display should revert to the original configuration on your physical monitor.

   Now, the script will automatically switch to the dummy display configuration when streaming and restore your original setup when you stop streaming.

9. **24H2 Workaround Script:**
   If you are using 24H2 and have troubles with Sunshine starting the stream due to 503 errors (missing output/encoder failure) you will need to install the 24H2 workaround script: https://github.com/Nonary/24H2DummyFix/releases/latest


## Troubleshooting

**If the ResolutionAutomation script doesn’t switch resolutions properly or you wish to run scripts after the monitor has swapped:**

- Increase the start delay in **settings.json** (located in the script’s folder) to 3 or 4 seconds. This will give more time for other scripts to run after the monitor has swapped.
- For ResolutionAutomation, this is not necessary to do in most cases as it has a fallback to re-apply resolution multiple times.

**Unable to start stream/503 encoder failure**
If you are using 24H2 and have troubles with Sunshine starting the stream due to 503 errors (missing output/encoder failure) you will need to install the 24H2 workaround script: https://github.com/Nonary/24H2DummyFix/releases/latest

---

## Change Log

**v2.0.5**
- Upgraded script to latest version of [Sunshine Script Intaller](https://github.com/Nonary/SunshineScriptInstaller) which has performance improvements.

**v2.0.4**
- Improved compatibility for Windows 11 24H2, fixing a common scenario that caused Sunshine to be unable to find an output device.
- Removed start delay, which will cause Moonlight to start the stream faster. If this causes issues, you can adjust the start delay back to 3 seconds.

**v2.0.3**
- Fixed another bug that caused script to exit earlier than intended before restoring primary monitor.

**v2.0.2**
- More bug fixes that prevented primary monitor from restoring after a stream was ended.

**v2.0.1**  
- Fixed a bug that prevented the primary monitor from restoring after ending a stream.

**v2.0.0**  
- Switched from Nirsoft MultiMonitorTool to MonitorSwitcher for better compatibility with Windows 24H2 and improved reliability.

---