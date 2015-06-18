#!/bin/sh
set -e

# ppu.sh
# By: Faiz Ali
# ali.faiz019@gmail.com

# (done) Check if jails dataset exists; quit if doesn't exist
# (done) Check if username exits
# (done) Two different log files; list of all jails; list of all changes to the jails [year/month/day:hour:min:sec]
# (done) Delete operation
# (done) List jails
# (done) 2 spaces for indentation
# (done-ish) make everything a separate function
# (done) print errors to error stream &2 echo "# - error" exit #
# (done-ish)get IP from log instead of ping
# (done) create configuration file ppu.conf
# (done-ish) test create and delete jail in same statement; generate random student
# Change password

# Parameters from ppu.conf
poolname=`cat ppu.conf | grep poolname | sed "s|poolname=||g"`
ipaddress=`cat ppu.conf | grep ipaddress | sed "s|ipaddress=||g"`
iptest=`cat ppu.conf | grep ipteststart | sed "s|ipteststart=||g"`
list=`cat ppu.conf | grep jaillist | sed "s|jaillist=||g"`jaillist.txt
log=`cat ppu.conf | grep jaillog | sed "s|jaillog=||g"`jaillog.txt

# Script parameters
action=$1
username=$2

createjail() {
  #Check if jails dataset doesn't exist; end if it doesn't
  if [ ! -d "/usr/jails" ] 
		then 
      echo "1 - The jails dataset does not exist" 1>&2
      exit 1
	fi
	
	#Check if username already exists; end if it does
	if [ -d "/usr/jails/$username" ] 
		then
      echo "2 - A jail for $username already exists" 1>&2
      exit 2
	fi
	
	#Create dataset for each username/jail; mount to jails location
	#zfs create $poolname/jails/$username
	#zfs set mountpoint=/usr/jails/$username $poolname/jails/$username
	#ipfind=1

  echo "hi"

	#Check each IP for ping response, if no response IP is not being used
	while [ $ipfind -eq 1 ]
	do
    check=`cat $list | grep $ipaddress$iptest`
    echo $check
    #if [ $check = ];
		#if [[ ! -z "$check" ]]
    then	
			iptest=`expr $iptest + 1` 
		else
      ipfind=0	
		fi
	done
	
  test=$ipaddress$iptest
  echo $test
  
	#Create a jail with username/password $username and ask to change password on logging in
	#qjail create -c -4 $ipaddress$iptest $username
	
	#Log list of all created and active jails 
	#echo $username $ipaddress$iptest host$iptest.cmps.pointpark.edu >> $list
	
	#Log action CREATE taken on a jail
	#echo `date +"[%y/%m/%d:%I:%M:%S]"` CREATE $username $ipaddress$iptest `who | awk '{print $1}'` >> $log

	#Start jail
	#qjail start $username
}

# deletejail() {
  # #Check if username exists; end if it doesn't
  # if [ ! -d "/usr/jails/$username" ] 
    # then
      # echo "3 - $username does not exist" 1>&2 
      # exit 3
  # fi
  
  # #Get jail IP
  # ip=`cat $list | grep $username | awk '{print $2}'`

  # #Stop jail, remove it, unmount dataset, remove it, remove remaining directory
  # qjail stop $username
  # qjail delete $username
  # zfs unmount -f /usr/jails/$username #doesn't work without -f?
  # zfs destroy $poolname/jails/$username
  # rmdir /usr/jails/$username
  
  # #Update list of all jails
  # sed -i '' '/'$username'/ d' $list
  
  # #Log action DELETE action
   # echo `date +"[%y/%m/%d:%I:%M:%S]"` DELETE $username $ip `who -m | awk '{print $1}'` >> $log
 # }

#jailtest() {
  #username=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) 
  #createjail
  #deletejail
# }

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
elif [ $action = "test" ]
	then
    #jailtest
fi





