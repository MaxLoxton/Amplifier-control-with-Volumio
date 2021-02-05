# Amplifier-control-with-Volumio
Raspberry Pi zero running Volumio, with MPD client to control an audio amplifier using IR emitter

I have a HiFi amplifier which still sounds great, but it dates from well before the age of network streaming and internet radio. I thought a neat project would be to use a Raspberry Pi with a DAC (digital to audio decoder) to feed the amlifier. I wanted a system that would work from my mobile, streaming music from a NAS and reading the Volumio status to  turn the amplifier on and off, using an IR emitter to controlthe amplifier.

The hardware required (about $A200 in Australia) is:
  
	Raspberry Pi zero with 2.5A power supply
	Pimoroni onoff shim
	DAC hat 	IQ Audio DAC+
	HiPi case black
	IR Diode 	5mm 940nm
	IR Receiver	TSOP38238
	Transistor	NPN 2N3904
	220 ohm resistor
	10kohm resistor
	Momentary push button
	IR emitter with cable
	Various ribbon cable, connector, Veroboard, screws and stand-offs, etc
  
The GPIO pins in use are:

	Onoff shim
	   GPIO4	pin 7		Shutdown
	   GPIO17	pin 11		Button and LED for shutdown initiate
	
	LIRC
	   GPIO23	pin 16		IR receive
	   GPIO15	pin 10		IR diode emitter (was GPIO24 on prototype)
	
	IQ Audio DAC+
	   GPIO2/3	pins 3/5	I2C
	   GPIO18/19/20/21	pins 12/35/38/40	I2S Audio

The software and system set-up turned out to be straightforward. Download the current Volumio image (version 2.861) and write it to a 16Gb micro SD memory card. When inserted into the Pi zero this booted and it was fairly simple to follow the Volumio install guide and set things up. A few additional steps:

1. Set a static IP address on the local WiFi network, using Volumio settings->Network page
2. From the Volumio Plugins page, install and activate the IR remote controller Plug-in
3. From the browser go to http://volumio.local/dev , enable SSH, and then use putty to log in (set port 22, SSH)
4. Load additional software

    	Sudo apt-get update
    	Sudo apt-get install cron
    	Sudo apt-get install python-mpd

5. For the Pimoroni onoff shim, load the software with curl

   		https://get.pimoroni.com/onoffshim | bash

6. LIRC was installed by the IR remote controlled plug-in, but there are a few extra settings for IR transmit:
    
	edit the file /boot/userconfig.txt using sudo nano:

		#Add your custom config.txt options to this file, which will be preserved during updates
		dtoverlay=gpio-ir-tx,gpio_pin=15
		dtoverlay=gpo-ir,gpio_pin=23
		dtparam=gpio_in_pull=up
  
 	Create the new file /etc/udev/rules.d/71-lirc.rules 

		ACTION=="add", SUBSYSTEM=="lirc", DRIVERS=="gpio_ir_recv", SYMLINK+="lirc-rx"
		ACTION=="add", SUBSYSTEM=="lirc", DRIVERS=="gpio-ir-tx", SYMLINK+="lirc-tx"
      
7. If your remote is not supported by the built in lircd profiles which you can select in the plugin UI, you will need to install a custom lircd.conf for it. Custom profiles can be downloaded from [http://lirc-remotes.sourceforge.net/remotes-table.html](http://lirc-remotes.sourceforge.net/remotes-table.html)  If you cannot find your remote, you can create an lircd.conf file using the IR receiver with LIRC’s code recording program.

	Either way, the custom lircd profiles can be installed in /data/plugins/accessory/ir_controller/configurations. 

		cd /data/plugins/accessory/ir_controller/configurations

	Create a new directory for your remote using an indicative name and copy the new lircd.conf file into it. Also copy the lircrc file from one of the other configured remotes as a placeholder - this project does not use it.

	With the remote configuration files in place, you will be able to select the new remote from the Volumio->Plugins->Installed->IR Remote Controlled->Settings page.

8. Edit the hardware.conf.templ template in /data/plugins/accessory/ir_controller/hardware.conf.templ to add the extra lirc1 device. The lirc1 receive device should be commented out.

		# usually /dev/lirc0 is the correct setting for systems using udev
		# lirc1 for receive, lirc0 for transmit
		# DEVICE="/dev/lirc1"
		DEVICE="/dev/lirc0"
		# MODULES="${module}"
		# MODULES="gpio_ir_recv"
		MODULES="gpio-ir-tx"

9. Reboot the pi and you should be able to test the IR function.

		lsmod | grep gpio			show the configured devices
		
			gpio_ir_recv           16384  0
			gpio_ir_tx             16384  0

	To test send (Use the name of your remote, mine is Onkyo_RC-632M):

		irsend LIST "" ""		    	  list available remote name
		irsend LIST Onkyo_RC-632M ""	lists available commands
	
		irsend SEND_ONCE <DEVICE> <KEY>	    irsend command

	For my remote this is:

		irsend SEND_ONCE Onkyo_RC-632M KEY_POWER

	To test receive, update /etc/lirc/hardware.conf, commenting our the transmit lines and uncommenting receive. Hardware.conf will look like:

		# usually /dev/lirc0 is the correct setting for systems using udev
		# lirc1 for receive, lirc0 for transmit
		DEVICE="/dev/lirc1"
		# DEVICE="/dev/lirc0"
		# MODULES="${module}"
		MODULES="gpio_ir_recv"
		# MODULES="gpio-ir-tx"

 	Restart the lirc subsystem with

		sudo /etc/init.d/lirc restart
		irw

	Now pressing a button on your remote should show the button name on the screen
	Restarting the Raspberry Pi will overwrite the /etc/lirc/hardware.conf file from the template

10. Copy the mpdclient.py program into /usr/local/bin

    Copy mpdclient start script into /etc/init.d and make it executable

		Sudo cp mpdclient /etc/init.d/mpdclient
		Sudo chmod +x /etc/init.d/mpdclient

    Test with
 
     	sudo /etc/init.d/mpdclient start
    	sudo /etc/init.d/mpdclient stop

    To register your script to be run at start-up and shutdown, run the following command:

      	sudo update-rc.d mpdclient defaults 

    If you ever want to remove the script from start-up, run the following command:

      	sudo update-rc.d -f  mpdclient  remove 

11. The WiFi network sometimes switches off after a long time (eg overnight). The problem seems to be the interface goes down (it could be the NBN router stopping the link on inactivity or some other network issue). My fix for this is to install a script to check and if needed restart the wifi interface.

	Copy checkwifi.sh to /usr/local/bin and make it executable

		Sudo cp checkwifi.sh /usr/local/bin/checkwifi.sh
		Sudo chown +x /usr/local/bin/checkwifi.sh

	Set up the cron entry with

      	sudo crontab -e
        
		MAILTO=""
		*/5 * * * * /usr/local/bin/checkwifi.sh 2>&1 /home/volumio/cronerr.log
      
12. For cron to work properly, you will also need to set the timezone

		sudo dpkg-reconfigure tzdata


