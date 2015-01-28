#! /bin/bash
#
# https://supportforums.cisco.com/discussion/12401026/cluster-esa
#
# Script to save the ESA config, then copy locally via SCP.  This is assuming you wish to
# have the cluster in SSH via port 22.  This script has been written and tested against
# AsyncOS 9.0.0-390 (01/15/2014).
#
# *NOTE* This script is a proof-of-concept and provided as an example basis. While these steps have 
# been successfully tested, this script is for demonstration and illustration purposes. Custom 
# scripts are outside of the scope and supportability of Cisco. Cisco Technical Assistance will 
# not write, update, or troubleshoot custom external scripts at any time.
#
# <SCRIPT>
#
# $HOSTNAME & $HOSTNAME2 can be either the FQDN or IP address of the ESAs in cluster.
#

HOSTNAME= [IP/HOSTNAME ESA1]
HOSTNAME2= [IP/HOSTNAME ESA2]

#
# $MACHINENAME is the local name for ESA1.
# 

MACHINENAME= [MACHINENAME AS LISTED FROM ‘clusterconfig list’]

#
# $USERNAME assumes that you have preconfigured SSH key from this host to your ESA.
# http://www.cisco.com/c/en/us/support/docs/security/email-security-appliance/118305-technote-esa-00.html
#

USERNAME=admin

#
# $BACKUP_PATH is the directory location on the local system.
#

BACKUP_PATH= [/local/path/as/desired]

#
# Following will remove ESA1 from cluster in order to backup standalone config.
# "2> /dev/null" at the end of string will quiet any additional output of the clustermode command.
#

echo "|=== PHASE 1  ===| REMOVING $MACHINENAME FROM CLUSTER"
ssh $USERNAME@$HOSTNAME "clustermode cluster; clusterconfig removemachine $MACHINENAME" 2> /dev/null

#
# $FILENAME contains the actual script that calls the ESA, issues the 'saveconfig' command.
# The rest of the string is the cleanup action to reflect only the <model>-<serial number>-<timestamp>.xml.
#

echo "|=== PHASE 2  ===| BACKUP CONFIGURATION ON ESA"
FILENAME=`ssh -q $USERNAME@$HOSTNAME "saveconfig y 1" | grep xml | sed -e 's/\/configuration\///g' | sed 's/\.$//g' | tr -d "\""`

#
# The 'scp' command will secure copy the $FILENAME from the ESA to specified backup path, as entered above.
# The -q option for 'scp' will disable the copy meter/progress bar.
#

echo "|=== PHASE 3  ===| COPY XML FROM ESA TO LOCAL"
scp -q $USERNAME@$HOSTNAME:/configuration/$FILENAME $BACKUP_PATH

#
# Following will re-add ESA1 back into cluster.
#

echo "|=== PHASE 4  ===| ADDING $MACHINENAME BACK TO CLUSTER"
ssh $USERNAME@$HOSTNAME "clusterconfig join $HOSTNAME2 admin ironport Main_Group" 2> /dev/null

#

echo "|=== COMPLETE ===| $FILENAME successfully saved to $BACKUP_PATH"

#
# </SCRIPT>
#