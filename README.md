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
  GPIO4		pin 7		Shutdown
  GPIO17	pin 11	Button and LED for shutdown initiate

LIRC
  GPIO23	pin 16	IR receive
  GPIO15	pin 10	IR diode emitter (was GPIO24 on prototype)

IQ Audio DAC+
  GPIO2/3	pins 3/5	I2C
  GPIO18/19/20/21	pins 12/35/38/40	I2S Audio

The software and system set-up turned out to be fairly simple. Download the current Volumio image (version 2.861) and write it to a 16Gb micro SD memory card. When inserted into the Pi zero this booted and it was fairly simple to follow the Volumio install guide and set things up. A few additional steps:
1. Set a static IP address on the local WiFi network, using Volumio settings->Network page
2. From the Volumio Plugins page, install and activate the IR remote controller Plug-in
3. From the browser page http://<volumio-name>.local/dev, enable SSH, and then use putty to log in (set port 22, SSH)
4. Load additional software
    Sudo apt-get update
    Sudo apt-get install cron
    Sudo apt-get install python-mpd
5. For the Pimoroni onoff shim, load the software with curl https://get.pimoroni.com/onoffshim | bash
6. LIRC was installed by the IR remote controlled plug-in, but there are a few extra settings for IR transmit:
    edit the file /boot/userconfig.txt using sudo nano:

      # Add your custom config.txt options to this file, which will be preserved during updates
      dtoverlay=gpio-ir-tx,gpio_pin=15
      dtoverlay=gpo-ir,gpio_pin=23
      dtparam=gpio_in_pull=up
  
  /etc/udev/rules.d/71-lirc.rules (you will need to create this file using nano)

      ACTION=="add", SUBSYSTEM=="lirc", DRIVERS=="gpio_ir_recv", SYMLINK+="lirc-rx"
      ACTION=="add", SUBSYSTEM=="lirc", DRIVERS=="gpio-ir-tx", SYMLINK+="lirc-tx"
      
7. If your remote is not supported by the built in lircd profiles which you can select in the plugin UI, you will need to install a custom lircd.conf     for it. Custom profiles can be downloaded from http://lirc-remotes.sourceforge.net/remotes-table.html If you cannot find your remote, you can create  one using the the IR receiver with LIRC’s code recording program.
Either way, the custom lircd profiles can be installed in /data/plugins/accessory/ir_controller/configurations. Create a new directory for your   remote and copy the new lircd.conf file into it. Also copy the lircrc file from one of the other configured remotes - this project does not use it.
With the remote configuration files in place, you will be able to select the new remote from the Volumio->Plugins->Installed->IR Remote Controlled->Settings page.

8. Edit the hardware.conf.templ template in /data/plugins/accessory/ir_controller/hardware.conf.templ to add the extra lirc1 device (receive, commented out) and lirc0 for transmit
    # Use lirc1 and modules="gpio_ir" for receive, use lirc0 and MODULES="gpio_ir_tx" for transmit
    # DEVICE="/dev/lirc1"
    DEVICE="/dev/lirc0"
    # MODULES="${module}"
    MODULES="gpio_ir_tx"

9. Reboot the pi and you should be able to test either IR receive or IR transmit as required

10. Copy the mpdclient.py program into /usr/local/bin
    Copy mpdclient start script into /etc/init.d
    Test with 
     	sudo /etc/init.d/mpdclient start
    	sudo /etc/init.d/mpdclient stop
    To register your script to be run at start-up and shutdown, run the following command:
      sudo update-rc.d mpdclient defaults 
    If you ever want to remove the script from start-up, run the following command:
      sudo update-rc.d -f  mpdclient  remove 

11. The WiFi network sometimes switches off after a long time (eg overnight). The problem seems to be the interface goes down (it could be the NBN router stopping the link on inactivity or some other network issue). My fix for this is to install a script to check and if needed restart the wifi interface.
    Copy checkwifi.sh to /usr/local/bin
    Set up the cron entry with
        sudo crontab -e
        
          MAILTO=""
          */5 * * * * /usr/local/bin/checkwifi.sh 2>&1 /home/volumio/cronerr.log
      
12. Set the timezone on the Raspberry Pi
        sudo dpkg-reconfigure tzdata
