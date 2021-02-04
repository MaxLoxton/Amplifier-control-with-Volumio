#!/bin/bash

LOGFILE=/home/volumio/checkwifi.log

if ifconfig wlan0 | grep -q "inet" ;
then
        echo "$(date "+%m %d %Y %T") : WiFi OK" >> $LOGFILE
else
        echo "$(date "+%m %d %Y %T") : WiFi connection down! Attempting reconnection." >> $LOGFILE
        ifup --force 'wlan0'
        OUT=$? #save exit status of last command to decide what to do next
        if [ $OUT -eq 0 ] ; then
                STATE=$(ifconfig wlan0 | grep "inet")
                echo "$(date "+%m %d %Y %T") : Network connection reset. Current state is" $STATE >> $LOGFILE
        else
                echo "$(date "+%m %d %Y %T") : Failed to reset wifi connection" >> $LOGFILE
		sleep 5
		/sbin/shutdown -r now
        fi
fi


# ping -c4 10.0.0.138 > /dev/null
#if [ $? = 0 ] 
#then 
#   echo "$(date "+%m %d %Y %T") : Network OK" >> /home/volumio/checkwifi.log
#fi
#if [ $? != 0 ] 
#then
#  echo "$(date "+%m %d %Y %T") : No network connection, restarting wlan0" >> /home/volumio/checkwifi.log
#  /sbin/ifdown 'wlan0'
#  sleep 5
#  /sbin/ifup --force 'wlan0'
# sudo /sbin/shutdown -r now
#fi
