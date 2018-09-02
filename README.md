# ppu.sh
Created by: Faiz Ali<br>
ali.faiz019@gmail.com<br>
Maintained by: Mark Voortman<br>
mvoortman@pointpark.edu<br>

## Functionality 

ppu.sh is a script to create jails, delete jails, and log jail actions in ZFS. A single data set is created inside the datapool (default: /usr/jails) which will contain every created jail. Each created jail will additionally be inside it's own datset (default: /usr/jails/username). These parameters can be changed via the configuration file ppu.conf. Additionally an IP range can be assigned to limit where the jails will be located. By default a user will be created on each jail of the same name and password of the jail itself. A user will be prompted to change their password upon logging in.

## Commands

```
./ppu.sh createjail [username]
```

Create a jail of username/password and name [username] (default: /usr/jails/username)

```
./ppu.sh deletejail [username]
```

Delete a jail of username/password and name [username]

```
./ppu.sh list
```

List of all jails created using this script (default: /usr/jails/jaillist.txt)

```
./ppu.sh log
```

List of all actions taken on the jail using this script (default: /usr/jails/jaillist.txt)

```
./ppu.sh password [username]
```

Reset the password for a jail to a random 8 character string. User must manually change on login.

```
./ppu.sh jailtest
```

Create a jail with a random 16 character string and immediately delete a jail. For testing purposes.

## Configuration File

```
dataset=[tank]/jails
```

Location of the dataset that will house the jails. [datapool] is the name of the datapool that will contain said dataset.

```
ipstart=[ipaddressstart]
```

(ex. 192.168.1.1) First IP address to begin searching if available for jail creation. Note that the script is only aware of IP addresses that are stored in it's own log file so the selected range should reflect this. 

```
ipend=[ipaddresssend]
```

(ex. 192.168.1.2) The last IP address in a range where jails can be created. The script will teriminate if it reaches this address at any point.

```
location=/usr/jails/
```

The default location of the log files and created jails.
