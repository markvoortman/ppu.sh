#!/bin/sh
set -e

#ppu.sh
#By: Faiz Ali

# (done) Check if jails dataset exists; quit if doesn't exist
# (done) Check if username exits
# (done) Two different log files; list of all jails; list of all changes to the jails [year/month/day:hour:min:sec]
# (done-ish) Delete operation
# (done) List jails
# Change password

#Pool name
poolname=zroot

#Create a jail "ppu.sh createjail username"
if [ $1 = "createjail" ]
	then
		#Check if jails dataset doesn't exist; end if it doesn't
		if [ ! -d "/usr/jails" ] 
			then
				exit "1 - The jails dataset does not exist"
		fi
		
		#Check if username already exists; end if it does
		username=$2
		if [ -d "/usr/jails/$username" ] 
			then
				exit "2 - A jail for $username already exists"
		fi
		
		#Create dataset for each username/jail; mount to jails location
		zfs create $poolname/jails/$username
		zfs set mountpoint=/usr/jails/$username $poolname/jails/$username
		
		#Range to start checking IP address from
		iptest=51
		ipfind=1
		
		#Check each IP for ping response, if no response IP is not being used
		while [ $ipfind -eq 1 ]
		do
			output=`ping -c 1 167.88.242.$iptest | grep packets | awk '{print $4}'`
			if [ $output = "1" ];
			then	
				iptest=`expr $iptest + 1` 
			else
				ipfind=0
			fi
		done
			
		#Create a jail with username/password $username and ask to change password on logging in
		qjail create -c -4 167.88.242.$iptest $username
		
		#Log list of all jails 
		echo $username 167.88.242.$iptest host$iptest.cmps.pointpark.edu >> /usr/jails/jaillist.txt
		
		#Log action CREATE taken on a jail
		echo `date +"[%y/%m/%d:%I:%M:%S]"` CREATE $username 167.88.242.$iptest `who | awk '{print $1}'` >> /usr/jails/jaillog.txt

		#Start jail
		qjail start $username
	
#Remove a jail "ppu.sh deletejail username"
elif [ $1 = "deletejail" ]
	then
		username=$2
		
		#Check if username exists; end if it doesn't
		if [ ! -d "/usr/jails/$username" ] 
			then
				exit "3 - $username does not exist"
		fi
		
		#Get jail IP
		ip=`cat /usr/jails/jaillist.txt | grep $username | awk '{print $2}'`

		#Stop jail, remove it, unmount dataset, remove it
		qjail stop $username
		echo jail stop
		sleep 2
		qjail delete $username
		echo jail delete
		sleep 2
		zfs unmount -f /usr/jails/$username #doesn't work without -f?
		echo data set unmount
		sleep 2
		zfs destroy $poolname/jails/$username
		echo destroy dataset
		sleep 2
		echo remove directory
		rmdir /usr/jails/$username
		
		#Update list of all jails
		#sed -i '' '/pizza3001/ d' /usr/jails/jaillist.txt
		sed -i '' '/'$username'/ d' /usr/jails/jaillist.txt #works individually but not in script?
		
		#Log action DELETE action
		echo `date +"[%y/%m/%d:%I:%M:%S]"` DELETE $ip `who | awk '{print $1}'` >> /usr/jails/jaillog.txt

#List all jails created with script
elif [ $1 = "list" ]
	then
		cat /usr/jails/jaillist.txt

#List all changes to jails as a result of the script
elif [ $1 = "log" ]
	then
		cat /usr/jails/jaillog.txt

#Test Case; ignore
elif [ $1 = "test" ]
	then
		test=$2
		#Check if username exists
		if [ -d "$test" ] 
		then
			echo This directory exists
		else
			echo this directory doesnt exist
		fi
fi

