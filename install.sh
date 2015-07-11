#!/bin/sh

# quit on any error
set -e

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

cp -f $SCRIPTPATH/ppu.sh /usr/local/bin/
cp -f $SCRIPTPATH/ppu.conf.example /usr/local/etc/
cp -f $SCRIPTPATH/ppu.sh.8.gz /usr/local/man/man8/
