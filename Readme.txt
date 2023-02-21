Open up MultiMontitor tool and capture the Monitor ID of your primary display.
With CRU, edit your displays (click edit button) and add a serial number if it is empty. 
Make sure the box that states "Include if slot available" is checked.

You may need to delete a detailed resolution, as it only contains 4 slots typically.
You will know it is correct if you see the serial number grayed out under detailed resolutions.


Then edit the DummyPlug.ps1 script

Change the value of $primarySerial to match you primary monitors serial.
Change the value of $dummySerial to match you dummy plugs serial.

Once done, install the script.

NOTE: Do not move this folder after installing script, otherwise it will break.

If you need to move folder, simply install it again to resolve.