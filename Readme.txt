With CRU (Custom Resolution Utility), edit your displays (click edit button) and add a serial number if it is empty. 
Make sure the box that states "Include if slot available" is checked.

If you don't see the serial number in the detailed resolution box, you may need to delete a resolution.
You will know it is correct if you see the serial number grayed out under detailed resolutions.

Once done, run the reset64.exe to apply the changes.

Then edit the MonitorSwap-Dummy.ps1 script

Change the value of $primarySerial to match you primary monitors serial.
Change the value of $dummySerial to match you dummy plugs serial.

Save changes, then install the script.

CAVEAT: Do not move this folder after installing script, otherwise it will break.
If you need to move the folder, simply install it again after moving.