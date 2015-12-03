#!/bin/sh
#          shell script wrapper for getFritzWANip.ssh.exp
#
#
#  read the current external WAN IP from a
#  DSL Router with SSH Daemon running...
# 
#  here: FRITZ.box
#
#  example:
#            getFritzWANip.ssh.sh <password>
#
#
#######################################################################

LOCAL_WAN_IP=`$(dirname $0)/getFritzWANip.ssh.exp $1 \
              | grep WWWW \
              | grep -Eo '[[:digit:]]{1,3}(\.[[:digit:]]{1,3}){3}'`

echo -n $LOCAL_WAN_IP

