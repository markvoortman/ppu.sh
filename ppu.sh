#!/bin/sh

# quit on any error
set -e

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

if [ "$(id -u)" != "0" ]; then
  echo "7 - This script must be run as root" 1>&2
  exit 7
fi

# set ppuconf location
ppuconf=/usr/local/etc/ppu.conf
if [ ! -f "$ppuconf" ]
then
  echo "8 - Configuration not found at $ppuconf" 1>&2
  exit 8
fi

# parameters from ppu.conf
dataset=`cat $ppuconf | grep dataset | sed "s|dataset=||g"`
ipaddress=`cat $ppuconf | grep ipstart | sed "s|ipstart=||g" | cut -d "." -f1-3`
iptest=`cat $ppuconf | grep ipstart | sed "s|ipstart=||g" | cut -d "." -f4`
ipend=`cat $ppuconf | grep ipend | sed "s|ipend=||g" | cut -d "." -f4`
location=`cat $ppuconf | grep location | sed "s|location=||g"`
backupds=`cat $ppuconf | grep backupds | sed "s|backupds=||g"`
backuphost=`cat $ppuconf | grep backuphost | sed "s|backuphost=||g"`

# script parameters
action=$1
username=$2
list=$location/jaillist.txt
log=$location/jaillog.txt
jailconf=/usr/local/etc/qjail.config/$username
dnsconf=/usr/jails/ns1/usr/local/etc/namedb/master/it.pointpark.edu

# check if qjail is installed
testvar=`pkg info | grep qjail`
if [ -z "$testvar" ]
then
  echo "6 - You must install qjail to use ppu.sh. pkg install sysutils/qjail" 1>&2
  exit 6
fi

createjail() {
  # check if a username is provided; end if not
  if [ -z "$username" ]
  then
    echo "5 - No username was provided" 1>&2
    exit 5
  fi
  
  # check if jails dataset doesn't exist; end if it doesn't
  if [ ! -d "$location" ]
  then
    echo "1 - The jails dataset does not exist" 1>&2
    exit 1
  fi
  
  # check if username already exists; end if it does
  if [ -d "$location/$username" ]
  then
    echo "2 - A jail for $username already exists" 1>&2
    exit 2
  fi
  
  # check if at end of IP usable range
  if [ $ipend = $iptest ]
  then
    echo "4 - Jail not created; IP end range reached." 1>&2
    exit 4
  fi
  
  # create dataset for each username/jail; mount to jails location
  zfs create $dataset/$username
  zfs set mountpoint=$location/$username $dataset/$username
  ipfind=1
  
  # check each IP in log file, exit if at end value, make new jail for unused value
  while [ "$ipfind" -eq 1 ]
  do
    if [ "$iptest" -gt "$ipend" ]
    then
      echo "4 - Jail not created; IP end range reached." 1>&2
      exit 4
    fi
    check=`grep $ipaddress.$iptest $list || true`
    if [ -n "$check" ]
    then
      iptest=`expr $iptest + 1`
    else
      ipfind=0
    fi
  done
  
  # create a jail with username/password $username and ask to change password on logging in
  qjail create -c -4 $ipaddress.$iptest $username
  
  # enable sysvipc in jail
  qjail config -y $username
  
  # enable raw sockets jail
  qjail config -k $username
  
  # DNS serial serial parameters
  currentserial=`cat $dnsconf | grep Serial | sed "s| ||g" | sed "s|;Serial||g"`
  currentdate=`date +"%Y%m%d"`
  oldval=`echo $currentserial | cut -c 9-10`
  olddate=`echo $currentserial | cut -c 1-8`
  
  # add jail to DNS, increment serial number
  if [ "$olddate" = "$currentdate" ]
  then
    newval=`expr $oldval + 1`
    if [ "$newval" -lt 10 ]
    then
      newval=0$newval
    fi
    newserial=$currentdate$newval
  elif [ ! "$olddate" = "$currentdate" ]
  then
    newserial=${currentdate}00
  fi
  sed -i '' 's/.*Serial.*/'$newserial' \; Serial/' $dnsconf
  echo $username IN A $ipaddress.$iptest >> $dnsconf
  
  # log list of all created and active jails
  echo $username $ipaddress.$iptest $username.it.pointpark.edu >> $list
  
  # log action CREATE taken on a jail
  echo `date +"[%y/%m/%d:%I:%M:%S]"` CREATE $username $ipaddress.$iptest `who -m | awk '{print $1}'` >> $log
  
  # configure the jail before starting it
  confjail
  
  # start jail
  qjail start $username
  
  # remove exec.poststart after jail start
  sed -i '' '/'exec.poststart'/ d' $jailconf
}

confjail() {
  # configure jail
  
  poudrierecert=/usr/local/etc/ssl/certs/poudriere.cert
  if [ -f "$poudrierecert" ]
  then
    # install poudriere certificate if it exists
    usernamecertsdir=/usr/jails/$username/usr/local/etc/ssl/certs
    mkdir -p $usernamecertsdir
    cp -f $poudrierecert $usernamecertsdir/
    
    # configure pkg to use the poudriere repository
    poudriererepodir=/usr/local/etc/pkg/repos
    usernamerepodir=/usr/jails/$username/usr/local/etc/pkg/repos
    mkdir -p $usernamerepodir
    cp -f $poudriererepodir/freebsd.conf $usernamerepodir/
    cp -f $poudriererepodir/poudriere.conf $usernamerepodir/
  fi
}

deletejail() {
  # check if a username is provided; end if not
  if [ -z "$username" ]
  then
    echo "5 - No username was provided" 1>&2
    exit 5
  fi
  
  # check if username exists; end if it doesn't
  if [ ! -d "$location/$username" ]
  then
    echo "3 - $username does not exist" 1>&2
    exit 3
  fi
  
  # get jail IP
  ip=`cat $list | grep $username | awk '{print $2}'`
  
  # stop jail, remove it, unmount dataset, remove it, remove remaining directory
  qjail stop $username
  qjail delete $username
  zfs unmount -f $location/$username
  zfs destroy -r $dataset/$username
  rmdir $location/$username
  
  # update list of all jails
  sed -i '' '/'$username'/ d' $list
  
  # log action DELETE action
  echo `date +"[%y/%m/%d:%I:%M:%S]"` DELETE $username $ip `who -m | awk '{print $1}'` >> $log
  
  # remove DNS record from conf
  sed -i '' '/'$username'/ d' $dnsconf
}

jailtest() {
  username=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  createjail
  deletejail
}

password() {
  # check if a username is provided; end if not
  if [ -z "$username" ]
  then
    echo "5 - No username was provided" 1>&2
    exit 5
  fi
  
  password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
  echo $password | pw -V /usr/jails/$username/etc usermod $username -h 0
  echo Your new password is $password. Don\'t forget it again!
  echo `date +"[%y/%m/%d:%I:%M:%S]"` CNGPWD $username $ipaddress.$iptest `who -m | awk '{print $1}'` >> $log
  echo A password change has been requested for your Point Park University server jail. Your temporary new password is: $password. After logging into your jail manually change your password using the command \'passwd\'. This is an automated message. Replies to this address will not be read or received. | mail -s "Point Park University Jail Password Change Notification" -F $username@pointpark.edu
}

buildpkg() {
  # build package list
  /usr/local/bin/poudriere jail -u -j freebsd_10-1x64
  /usr/local/bin/poudriere ports -u -p HEAD
  /usr/local/bin/poudriere bulk -j freebsd_10-1x64 -p HEAD -f /usr/local/etc/poudriere.d/port-list
}

editpkg() {
  # edit package list
  vi /usr/local/etc/poudriere.d/port-list
}

snapshot() {
  # check parameter
  if [ "$dataset" = "" ]
  then
    echo "Dataset must be specified" 1>&2
    exit 99
  fi
  # make snapshot
  zfs snapshot -r $dataset@`date +%Y-%m-%d-%H-%M`
}

backup_one() {
  src=$1
  dst=`echo $src | sed 's|'$backupsrc'|'$backupdst'|'`
  snapshots=`zfs list -r -d 1 -t snapshot -o name -s name $src`
  firstsnapshot=`echo $snapshots | cut -d " " -f2`
  lastsnapshot=`echo $snapshots | rev | cut -d " " -f1 | rev`
  remotesnapshots=`ssh $backupdsthost sudo zfs list -r -d 1 -t snapshot -o name -s name $dst || true`
  if [ "$remotesnapshots" = "no datasets available" ] || [ "$remotesnapshots" = "" ]
  then
    zfs send $firstsnapshot | ssh $backupdsthost sudo zfs receive -F $dst
    remotesnapshots=`ssh $backupdsthost sudo zfs list -r -d 1 -t snapshot -o name -s name $dst || true`
  fi
  lastremotesnapshot=`echo $remotesnapshots | rev | cut -d " " -f1 | rev`
  fromsnapshot=`echo $lastremotesnapshot | sed 's|'$backupdst'|'$backupsrc'|'`
  if [ "$fromsnapshot" != "$lastsnapshot" ]
  then
    zfs send -I $fromsnapshot $lastsnapshot | ssh $backupdsthost sudo zfs receive -F $dst
  fi
}

backup() {
  # get parameters
  backupsrc=$dataset
  backupdst=$backupds
  backupdsthost=$backuphost
  # check parameters
  if [ "$backupsrc" = "" ]
  then
    echo "Backupsrc must be specified" 1>&2
    exit 99
  fi
  if [ "$backupdst" = "" ]
  then
    echo "Backupdst must be specified" 1>&2
    exit 99
  fi
  if [ "$backupdsthost" = "" ]
  then
    echo "Backupdsthost must be specified" 1>&2
    exit 99
  fi
  # run backup
  datasets=`zfs list -r -o name -s name $backupsrc`
  for tmpdataset in $datasets
  do
    if [ "$tmpdataset" != "NAME" ]
    then
      backup_one $tmpdataset
    fi
  done
}

cron() {
  # hourly cron job
  runpkg="no"
  hour=`date +"%H"`
  if [ "$hour" = "03" ]
  then
    runpkg="yes"
  fi
  snapshot
  backup
  if [ "$runpkg" = "yes" ]
  then
    buildpkg
  fi
}

if [ "$action" = "createjail" ]
then
  # create a jail 'ppu.sh createjail username'
  createjail
  
elif [ "$action" = "confjail" ]
then
  # configuure a jail 'ppu.sh confjail username'
  confjail
  
elif [ "$action" = "deletejail" ]
then
  # remove a jail 'ppu.sh deletejail username'
  deletejail
  
elif [ "$action" = "list" ]
then
  # list all jails created with script 'ppu.sh list'
  # print empty if file doesn't exist
  if [ -f "$list" ]
  then
    cat $list
  fi
  
elif [ "$action" = "log" ]
then
  # list all changes to jails as a result of the script 'ppu.sh log'
  # print empty if file doesn't exist
  if [ -f "$log" ]
  then
    cat $log
  fi
  
elif [ "$action" = "jailtest" ]
then
  # create a jail for random student; delete the jail 'ppu.sh jailtest'
  jailtest
  
elif [ "$action" = "password" ]
then
  # change password for a user to random 16 character string 'ppu.sh password username'
  password
  
elif [ "$action" = "buildpkg" ]
then
  buildpkg
  
elif [ "$action" = "editpkg" ]
then
  editpkg
  
elif [ "$action" = "snapshot" ]
then
  snapshot
  
elif [ "$action" = "backup" ]
then
  backup
  
elif [ "$action" = "cron" ]
then
  cron
  
fi
