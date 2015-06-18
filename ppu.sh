#!/bin/sh
set -e

# ppu.sh
# By: Faiz Ali
# ali.faiz019@gmail.com

# Parameters from ppu.conf
poolname=`cat ppu.conf | grep poolname | sed "s|poolname=||g"`
ipaddress=`cat ppu.conf | grep ipaddress | sed "s|ipaddress=||g"`
iptest=`cat ppu.conf | grep ipteststart | sed "s|ipteststart=||g"`
location=`cat ppu.conf | grep location | sed "s|location=||g"`

# Script parameters
action=$1
username=$2
list=$location/jaillist.txt
log=$location/jaillog.txt

createjail() {
  #Check if jails dataset doesn't exist; end if it doesn't
  if [ ! -d "$location" ] 
		then 
      echo "1 - The jails dataset does not exist" 1>&2
      exit 1
	fi
	
	#Check if username already exists; end if it does
	if [ -d "$location/$username" ] 
		then
      echo "2 - A jail for $username already exists" 1>&2
      exit 2
	fi
	
	#Create dataset for each username/jail; mount to jails location
	zfs create $poolname/jails/$username
	zfs set mountpoint=$location/$username $poolname/jails/$username
	ipfind=1
  
	#Check each IP for ping response, if no response IP is not being used
	while [ $ipfind -eq 1 ]
	do 
    check=`grep $ipaddress$iptest $list || true`    
		if [ -n "$check" ]
    then	
			iptest=`expr $iptest + 1` 
		else
      ipfind=0	
		fi
	done
  
	#Create a jail with username/password $username and ask to change password on logging in
	qjail create -c -4 $ipaddress$iptest $username
	
	#Log list of all created and active jails 
	echo $username $ipaddress$iptest host$iptest.cmps.pointpark.edu >> $list
	
	#Log action CREATE taken on a jail
	echo `date +"[%y/%m/%d:%I:%M:%S]"` CREATE $username $ipaddress$iptest `who | awk '{print $1}'` >> $log

	#Start jail
	qjail start $username
}

 deletejail() {
  #Check if username exists; end if it doesn't
  if [ ! -d "$location/$username" ] 
    then
      echo "3 - $username does not exist" 1>&2 
      exit 3
  fi
  
  #Get jail IP
  ip=`cat $list | grep $username | awk '{print $2}'`

  #Stop jail, remove it, unmount dataset, remove it, remove remaining directory
  qjail stop $username
  qjail delete $username
  zfs unmount -f $location/$username #doesn't work without -f?
  zfs destroy $poolname/jails/$username
  rmdir $location/$username
  
  #Update list of all jails
  sed -i '' '/'$username'/ d' $list
  
  #Log action DELETE action
  echo `date +"[%y/%m/%d:%I:%M:%S]"` DELETE $username $ip `who -m | awk '{print $1}'` >> $log
}

jailtest() {
  username=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1) 
  echo $username
  createjail
  deletejail
}

#Create a jail "ppu.sh createjail username"
if [ $action = "createjail" ]
	then
    createjail
		
#Remove a jail "ppu.sh deletejail username"
elif [ $action = "deletejail" ]
	then
		deletejail

#List all jails created with script "ppu.sh list"
elif [ $action = "list" ]
	then
		cat /usr/jails/jaillist.txt

#List all changes to jails as a result of the script "ppu.sh log"
elif [ $action = "log" ]
	then
		cat /usr/jails/jaillog.txt

#Create a jail for random student; delete the jail "ppu.sh jailtest"
elif [ $action = "jailtest" ]
	then
    jailtest
fi