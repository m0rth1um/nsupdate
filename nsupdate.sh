#!/bin/bash

# Update a nameserver entry at inwx with the current WAN IP (DynDNS)

# Copyright 2013 Christian Busch
# http://github.com/chrisb86/

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# check required tools
command -v curl >/dev/null 2>&1 || { echo >&2 "I require curl but it's not installed. Note: all needed items are listed in the README.md file."; exit 1; }
command -v awk >/dev/null 2>&1 || { echo >&2 "I require awk but it's not installed. Note: all needed items are listed in the README.md file."; exit 1; }
command -v drill >/dev/null 2>&1 || command -v nslookup >/dev/null 2>&1 || { echo >&2 "I need drill or nslookup installed. Note: all needed items are listed in the README.md file."; exit 1; }

LOG=$0.log
SILENT=NO

# Check if there are any usable config files
if ls $(dirname $0)/nsupdate.d/*.config 1> /dev/null 2>&1; then
   
   # Loop through configs
   for f in $(dirname $0)/nsupdate.d/*.config
   do
      if [ "$SILENT" == "NO" ]; then
         echo "Starting nameserver update with config file $f"
      fi
      ## Set record type to IPv4
      TYPE=A
      CONNECTION_TYPE=4

      source $f

      ## Set record type to MX
      if [[ "$MX" == "YES" ]]; then
         TYPE=MX
      fi

      ## Set record type to IPv6
      if [[ "$IPV6" == "YES" ]]; then
         TYPE=AAAA
         CONNECTION_TYPE=6
      fi

      if [[ "$USE_DRILL" == "YES" ]]; then
         if [[ "$TYPE" == "MX" ]]; then
          echo looking up MX records with drill currently not supported!
         exit 1;
        else
          NSLOOKUP=$(drill $DOMAIN @ns.inwx.de $TYPE | head -7 | tail -1 | awk '{print $5}')   
        fi
      else
        if [[ "$TYPE" == "MX" ]]; then
         PART_NSLOOKUP=$(nslookup -sil -type=$TYPE $DOMAIN - ns.inwx.de | tail -2 | head -1 | cut -d' ' -f5)
         NSLOOKUP=${PART_NSLOOKUP%"."}
        else
         NSLOOKUP=$(nslookup -sil -type=$TYPE $DOMAIN - ns.inwx.de | tail -2 | head -1 | cut -d' ' -f2)
        fi
      fi

      # WAN_IP=`curl -s -$CONNECTION_TYPE ${IP_CHECK_SITE}| grep -Eo '\<[[:digit:]]{1,3}(\.[[:digit:]]{1,3}){3}\>'`
      # WAN_IP=`curl -s -$CONNECTION_TYPE ${IP_CHECK_SITE}`

      WAN_IP=`$(dirname $0)/nsupdate.d/${LOCAL_GET_IP_SCRIPT} ${LOCAL_GET_IP_SCRIPT_PW}`
      if [ "x$WAN_IP" == "x" ]; then
        echo "$(date) - Not successful: ${LOCAL_GET_IP_SCRIPT}"
         
        WAN_IP=`curl -s -$CONNECTION_TYPE ${IP_CHECK_SITE}`
        if [ "x$WAN_IP" == "x" ]; then
         echo "$(date) - Not successful: curl -s -$CONNECTION_TYPE ${IP_CHECK_SITE} - exit"
         echo "$(date) - Not successful: curl -s -$CONNECTION_TYPE ${IP_CHECK_SITE} - exit" >> $LOG
         exit 1
        fi
      fi

      if [[ "$IPV6" == "YES" ]]; then
        # only /64 prefix dynamic ?
        if [[ "$IPV6_USE_ONLY_PREFIX" == "YES" ]]; then
          WAN_PREFIX=`echo -n $WAN_IP |  grep -Eo '[[:xdigit:]]{0,4}(\:[[:xdigit:]]{0,4}){3}\:'`
          WAN_IP="${WAN_PREFIX}${IPV6_SUBNET}"
        fi
      fi

      API_XML="<?xml version=\"1.0\"?>
      <methodCall>
         <methodName>nameserver.updateRecord</methodName>
         <params>
            <param>
               <value>
                  <struct>
                     <member>
                        <name>user</name>
                        <value>
                           <string>$INWX_USER</string>
                        </value>
                     </member>
                     <member>
                        <name>pass</name>
                        <value>
                           <string>$INWX_PASS</string>
                        </value>
                     </member>
                     <member>
                        <name>id</name>
                        <value>
                           <int>$INWX_DOMAIN_ID</int>
                        </value>
                     </member>
                     <member>
                        <name>content</name>
                        <value>
                           <string>$WAN_IP</string>
                        </value>
                     </member>
                  </struct>
               </value>
            </param>
         </params>
      </methodCall>"
      
      if [ ! "$NSLOOKUP" == "$WAN_IP" ]; then
         curl -silent -v -XPOST -H"Content-Type: application/xml" -d "$API_XML" https://api.domrobot.com/xmlrpc/
         echo "$(date) - $DOMAIN updated. Old IP: "$NSLOOKUP "New IP: "$WAN_IP >> $LOG
      elif [ "$SILENT" == "NO" ]; then
         echo "$(date) - No update needed for $DOMAIN. Current IP: "$NSLOOKUP >> $LOG
      fi

      unset DOMAIN
      unset IPV6
      unset MX
      unset WAN_IP
      unset NSLOOKUP
      unset INWX_PASS
      unset INWX_USER
      unset INWX_DOMAIN_ID
   done
else
   echo "There does not seem to be any config file available in $(dirname $0)/nsupdate.d/." ; exit 1;
fi
