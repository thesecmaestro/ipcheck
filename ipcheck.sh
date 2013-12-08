#!/bin/bash

# ipcheck.sh - a paranoid VPN helper script
SVERSION="Version 0.1.11 9DEC13"
# Usage: ./ipcheck.sh [optional_bad_ip]
# Author: Roger Smith (email below)
#
# TL;DR: If you know what you're doing just set the variables below the
# big block of commented text to meet your needs, they are well
# commented. Change anything that is currently set to CHANGEME and you
# should be set.
#
# What this script is (and why):
#
# This script checks your local external IP (if behind a NAT device)
# and compares it to what your real IP address is.
# It does this by checking the system output (via ifconfig) as well
# as a doing a real world test of the IP address by retreiving the IP from
# an external web server via curl. Multiple methods
# are the only way to be 100% sure as I've seen bugs happen that could
# compromise a users public IP address when using a single detection method.
# I put it together to shut down a system if the VPN drops and the
# real public IP address is exposed on the system and gives the option
# of sending an email notification before taking the system off the
# network or shutting it down entirely if something goes wrong.
# 
# This was designed for a CentOS 6 system. Note that most of the
# executables have the full path specified; if used on a different
# distro, ensure the paths match. This was designed to be ran as root,
# however it should work for any user that has permissions to stop
# the network service and reboot the system.
#
# This script may seem a bit like overkill. That's because it is. I
# designed it to help people that have reasons to be paranoid. It
# meets my needs and mayhap it meets yours. If not, take a look at
# modifying ifup/ifdown or 'ip monitor' may be of some help as well.
# Be warned however that I've found that using one method by itself
# isn't 100% effective.
# 
# IP Address Refreshing:
#
# If you feel you need less protection (for example, for many people
# it's uncommon for their external IP to change) you can comment it out
# (it's well commented) and change the BAD_IP variable to whatever your
# public IP is. You'll notice it refreshes the real public IP address
# information from another server on the same LOCAL network over http.
# It does this so the VPN doesn't have to be dropped to find out if
# there's been a change to the public IP information. The other server
# runs a web server (obviously) and has a cron that runs at an interval:
# /usr/bin/curl -s http://websitewithipinfo > /path/to/www/root/file.txt
# This could be replaced with FTP/SSH/SMB commands or whatever.
# The following sites are useful for only returning the IP address and
# at the time of this writing (Nov. 2013) work with this script.
# 
# Don't set the timer below five minutes (unless you are using your own
# public server such as a hosted website) as it's considered rude and 
# will probably get you banned. Plus, doing requests faster than that
# tends to draw attention, and that's exactly what you don't want.
#
# http://ifconfig.me
# http://ipecho.net/plain
# http://icanhazip.com
# http://roboguys.com/ip.shtml
# http://bot.whatismyipaddress.com
# http://ip.appspot.com
# http://whatismyip.akamai.com
# http://myexternalip.com/raw
# 
# These site may change in the future, so it's a good idea to test
# them occasionally from the command line:
#
# curl -s http://siteyouwanttotest
#
# If the site returns anything other than the IP address or spaces
# before or after the IP address, there might be issues with
# using it in this script.
#
# The following are sites that can return the IP address, however
# they require some manipulation. If you don't understand these, just
# ignore them and only use the ones listed previously. 
# 
# dig +short myip.opendns.com @resolver1.opendns.com
# curl -s http://vigeek.net/extip.php | sed 's/^ *//g' | sed 's/ *$//g'
# curl -s http://www.ip-details.com | grep "Your IP Address :" | awk '{ print $6 }' | sed "s/.....$//"
# curl -s http://checkip.dyndns.org | sed -e 's/[^[:digit:]| .]//g' | sed 's/^ *//g'
# curl -s http://ipogre.com/linux.php | sed -e 's/.*IP Address: //' -e 's/<.*$//'
# 
# These are just some sites I found by poking around some forums. I'm
# sure there are more and you may even want to use your own server
# (see below) you have hosted elsewhere. I am not the owner of any of
# these sites and I have no idea who is. If you are the owner and do
# not want these listed here please email me with verifiable proof
# that you do indeed own the domain and would like it removed.
#
# If you'd like to run your own IP returning web service, here is an
# example.
#
# On a server that has a working Apache installation, copy just the
# following line to a text file:
#
# <!--#echo var="REMOTE_ADDR" -->
#
# Save it and rename it "return.shtml" (no quotes). Upload it to the
# root of your Apache web server. Test it out by using a web browser
# and entering http://whateverthesitesnameis/return.shtml
# If everything is in place, you should just see the public IP of the
# client you are browsing from. If the server is on the same local network
# as the client, it will just show the local LAN address.
#
# Email Notification:
#
# Note that if you do use the email notification, when the email is sent
# it will be using your real public IP address since the notification is
# sent after the IP address information matches.
#
# If you want to use the email notification feature, there are three
# options:
#     1) The local mail system. To send mail externally
#        the local MTA (such as sendmail) has to be configured to
#       forward mail to a SMTP server on the Internet, such as
#       your ISPs mail server. This is unencrypted.
#
#    2) Gmail over TLS. You have to have a valid user/pass on
#       Gmail for this to work and have the following packages
#       installed:
#       perl-Net-SSLeay
#       perl-IO-Socket-SSL
#       perl-Net-LibIDN
#       sendEmail-1.56
#
#    3) Straight up SMTP email. If you have a SMTP server that will
#        allow you to relay mail (such as your ISPs mail server)
#       you can use this. Just remember it isn't encrypted. It uses
#       the following packages:
#       sendEmail-1.56
#
# sendEmail-1.56 may not be found in stock repos. Search pbone.net if
# 'yum install sendEmail-1.56' doesn't find it. Download it and install
# it with 'rpm -ivh name-of-the-file.rpm'. If you are enforcing GPG
# signing, you may have to accept the GPG key. The author is located
# here: http://caspian.dotconf.net/menu/Software/SendEmail/
#
# If you know what you're doing you can use this mechanism to send TLS
# encrypted email to a server that isn't Gmail, just use the GMAIL*
# variables.
#
# Note: Please don't depend on this script with your life. It can be useful
# but by itself it's not enough to protect you entirely.
# No warranties, not liable, not fit for any purpose other than my own, etc.
# Use it at your own risk.
#
# For license purposes it's GPLv3. No verbage from the comments of this script
# may be removed, however they may be added to as long as the changes are
# published.
#
# The next version will incorporate round robin selection of the
# IP address returning websites and a few other goodies.
# 
# One last thing: I'm especially interested in finding sites that will
# return IP information that are hosted in countries that are considered
# 'oppressed', ie. North Korea, China, Afghanistan, most Middle Eastern
# countries, etc. If you know of any please send them via email to:
# rsmith(removethisandparentheses)317-removethisanddashestoo-in at gmail.com
# Bug reports and suggestions are welcome, as well as translation assistance.
# 
# 
# Send tips via Bitcoin to: 1DqkW7VeQ9fABNmNzaHqCmnV6jv9VHfdLJ
# Send tips via Litecoin to: LhTvCL3QrEwxUgCpspTvD1jLZVkzR2ZB2v
#
#
# Tips are used to find information useful for ipcheck and to assist
# politically oppressed subversives communicate. Thanks for supporting
# free speech for all!
#
# Variables:
#
# Replace any variables that are labeled CHANGEME with your information.
#
# Pull public IP info from another server ON THE SAME LOCAL NETWORK. Using a server that is not on your own local network will most likely not give you the needed information.
# Example: DIFF_HOST_BAD_IP_FILE=http://192.168.1.1/external_ip.txt
DIFF_HOST_BAD_IP_FILE=http://CHANGEME/CHANGEME
# Location the real public IP address information should be copied to locally. The account running the script will require read/write/delete permissons. Remember, Linux is case sensitive.
# Example: BAD_IP_FILE=/tmp/external_ip.txt
BAD_IP_FILE=/CHANGEME/CHANGEME.TXT
# Real public IP is provided from a different local system. Passing it an argument (ie, ipcheck.sh 8.8.8.8) overrides until refresh.
# Example: BAD_IP=`/bin/cat $BAD_IP_FILE`
BAD_IP=`/bin/cat $BAD_IP_FILE`
# Host on the local network that will respond to pings.
# Example: TEST_HOST=192.168.1.1
TEST_HOST=CHANGEME
# This is where the current system's public IP comes from. I'd recommend cycling through the ones in the list above over time, the next version will do this automatically.
# Example: IP_CHECK_URL=http://ifconfig.me
IP_CHECK_URL="http://CHANGEME"
# Seconds between getting the system's IP from a public website. Setting it too low will overload the site and probably get you BANNED or worse (it attracts attention)! Don't set this too low unless you really know what you're doing. Keep in mind the more often it refreshes, the more likely something like intermittent network problems will cause things to fail.
LOOPDELAY=600
# Number of passes the script makes before it gets the system's public IP address from the IP_CHECK_URL. REFRESH * LOOPDELAY / 60 = Minutes till BAD_IP update.
REFRESH=2
# Delay in case something is taking too long to die.
KILLDELAY=10
# Email subject line.
SUBJECT="CHANGEME"    
# To: address for the email notification.    
TOADDR="CHANGEME"
# From: address.
FROMADDR="CHANGEME"
# Email notification body.
EMAILBODY="CHANGEME"
# GMail username, do not use the @gmail.com part. This can also be another mail server other than GMail that supports TLS.
GMAILUSER=
# Gmail password, or another TLS mail server account password.
GMAILPASS=
# Gmail server and port, or another TLS server and port.
GMAILSRV=smtp.gmail.com:587
# Use TLS encryption
USETLS=yes
# Standard SMTP relay server that will accept mail from the local system
SMTPSRV=
# Tunnel override. The script by default checks the IP address of the tunnel adapter
# ONCE PER SECOND. This is a lot and it may cause some systems to behave irratically.
# If you're not sure or not worried about it, set it zero to disable.
TUNNEL_STATUS=1
# Tunnel adapter name. While connected to your VPN, from a command line run the
# ipconfig command. Look for an adapter (usually tun0 or ppp0 depending on the
# VPN methodology). If necessary disconnect your VPN and run the ipconfig command
# again, comparing the outputs. Put the name of it here.
# Example: TUNNEL_NAME=tun0
TUNNEL_NAME=CHANGEME
# Occasionally curl will not pull back the refreshed IP address due to network issues,
# server problems, etc. resulting in a zero byte file. This variable represents the
# number of times an IP refresh can fail to return an address, giving you the option
# of allowing the script to have some 'slop' in it.
# Set it to 1 for the paranoid (meaning it will halt the network on a single
# failed IP refresh attempt).
ZBYTE_TOLERANCE=3

# These variables shouldn't be changed.
CURRENT_IP=0.0.0.0    # Placeholder for the current (hopefully VPN'd) IP address.
COUNTER=0        # Public IP counter. Increments once per LOOPDELAY.
LOOPSTART=1        # Placeholder for the throbber.
THROBBER='/-\|'        # The throbber.
THROB=
THR=
TUNNEL_IP=0.0.0.0    # Placeholder for additional change detection on tunnel adapters
LAST_TUNNEL_IP=0.0.0.0
TUNNEL_FOUND=0
ZBYTE_COUNT=0
OCTET=

# End of variables

# If you don't want the refresh and you've hardcoded your BAD_IP variable,
# comment out all the lines starting at 'Start of the REFRESH counter increment'
# down to 'End of the REFRESH counter increment'
ip_is_bad() {    
    [ "$(/usr/bin/curl -s "$IP_CHECK_URL")" = "$BAD_IP" ] && return 0 # THERE'S A MATCH!!

    let COUNTER++ # Start of the REFRESH counter increment
        if [ "$COUNTER" = "$REFRESH" ]; then
        echo " "
        echo "Public IP refresh time reached!"
        /bin/date
        /usr/bin/curl -s $DIFF_HOST_BAD_IP_FILE > $BAD_IP_FILE # Gets public IP from another local box
        export BAD_IP=`/bin/cat $BAD_IP_FILE` # This updates the BAD_IP variable mid-script
        export BAD_IP=`echo -n $BAD_IP` # removes EOL
        hot_or_not # This function checks to see if the IP address retrieved is actually an IP address.
                if [ -z "$BAD_IP" ]; then let ZBYTE_COUNT++
                    zero_byte_file                
                else
                    echo "Update successful!"
                    ZBYTE_COUNT=0
                fi
        echo "Bad IP to avoid:" $BAD_IP
        COUNTER=0
        fi    # End of the REFRESH counter increment

    return 1
}

kaboom() { 
    echo "KABOOM!"
    /sbin/shutdown -h now
    /sbin/poweroff
    exit 1
}

the_end() {
    echo "Looks like network stop was successful."
    echo "Bye!"
    /bin/date
    exit 1
}

net_stop() {
#    Uncomment one of the below lines if you want to use email notifications (see comments at the top).
#    echo $EMAILBODY | /bin/mail -s "$SUBJECT" "$TOADDR" & # Only works locally unless the system has MTA configured.
#    /usr/bin/sendEmail -f $FROMADDR -t $TOADDR -u "$SUBJECT" -m "$EMAILBODY" -s $GMAILSRV -o tls=$USETLS -xu $GMAILUSER -xp $GMAILPASS & # TLS email.
#    /usr/bin/sendEmail -f $FROMADDR -t $TOADDR -u "$SUBJECT" -m "$EMAILBODY" -s $SMTPSRV & # Sends SMTP mail to a relay.
#    /usr/bin/paplay /usr/share/sounds/KDE-Sys-App-Error-Serious-Very.ogg & # Uncomment for alert sound (uses pulseaudio).
    echo "Network stop being attempted!"
    /bin/sleep $KILLDELAY
    /sbin/service network stop # Stops the network. Change it to '/etc/init.d/networking stop' for Debian style distros.
    /bin/sleep $KILLDELAY
    /bin/ping -c1 $TEST_HOST &>/dev/null # This pings the TEST_HOST defined at the top.
    if [ $? -ne 0 ]; then the_end
    else return 0
    fi
}

die_die_die() {
        /bin/date
    net_stop
    echo "Problem stopping the network!"
    /usr/bin/logger Network shutdown attempt failed. Stopping Server.
    # STILL NOT DEAD!!
    kaboom
}

hot_or_not() { # This function checks if the BAD_IP variable conforms to what an IP address should look like.
    if [ `echo $BAD_IP | /bin/grep -o '\.' | /usr/bin/wc -l` -ne 3 ]; then
        echo " "
            echo "BAD_IP isn't an IP Address (doesn't contain three periods)!"
        echo " "
            ninety_nine_problems
    elif [ `echo $BAD_IP | /usr/bin/tr '.' ' ' | /usr/bin/wc -w` -ne 4 ]; then
        echo " "
            echo "BAD_IP isn't an IP Address (doesn't contain four octets)!"
        echo " "
            ninety_nine_problems
    else
            for OCTET in `echo $BAD_IP | /usr/bin/tr '.' ' '`; do
                    if ! [[ $OCTET =~ ^[0-9]+$ ]]; then
            echo " "
                        echo "BAD_IP isn't an IP Address (octet '$OCTET' isn't a number)!"
            echo " "
                        ninety_nine_problems;
                elif [[ $OCTET -lt 0 || $OCTET -gt 255 ]]; then
            echo " "
                        echo "BAD_IP isn't an IP Address (octet '$OCTET' isn't in range of an IPv4 address)!"
            echo " "
                        ninety_nine_problems
                fi
            done
    fi
return 0;
}

zero_byte_file() {
    echo "Warning: BAD_IP refresh failed (zero byte file was returned)."
    echo "Number of times the refresh has failed:" $ZBYTE_COUNT
    echo "Number of times it is allowed to fail:" $ZBYTE_TOLERANCE
#    /usr/bin/paplay /usr/share/sounds/KDE-Sys-App-Error-Serious-Very.ogg & # Uncomment for alert sound (uses pulseaudio).
    if [ "$ZBYTE_COUNT" = "$ZBYTE_TOLERANCE" ]; then
        echo "Failure limit has been reached!"
        ninety_nine_problems
    else return 0
    fi
}

ninety_nine_problems() {
    echo "IP address information could not be determined!"
    echo "Size of the BAD_IP_FILE: "`stat -c %s "$BAD_IP_FILE"`" kilobytes" # Debugging for most common issue, zero byte file.
    echo 
    net_stop
    echo "Problem stopping the network!"
    /usr/bin/logger Network shutdown attempt failed. Stopping Server.
    # STILL NOT DEAD!!
    kaboom
}

first_adapter_check() { # This checks for the existance of an adapter based on TUNNEL_NAME.
    export TUNNEL_IP=`ifconfig $TUNNEL_NAME | grep inet | awk '{ print $2 }' | sed 's/^.....//'`
    export TUNNEL_IP=`echo -n $TUNNEL_IP`
        if [ -z "$TUNNEL_IP" ]; then
        echo "No tunnel adapter found."
        else
        echo "VPN adapter found! Tunnel IP:" $TUNNEL_IP
        export TUNNEL_FOUND=1
        fi
    export LAST_TUNNEL_IP=$TUNNEL_IP
}

throbber() {    # Progress indicator and tunnel adapter checker. Note: This checks the TUNNEL_NAME adapter ONCE PER SECOND.
    for THROB in $(eval echo "{$LOOPSTART..$LOOPDELAY}") # Routine runs once per second up to the LOOPDELAY variable.
    do
        printf "\b\b\b\b [${THROBBER:THR++%${#THROBBER}:1}]" # Progress indicator to make things a bit more snazzy.
        if [ $TUNNEL_FOUND = "1" ]; then
        export TUNNEL_IP=`ifconfig $TUNNEL_NAME | grep inet | awk '{ print $2 }' | sed 's/^.....//'` 
        export TUNNEL_IP=`echo -n $TUNNEL_IP`
        fi
        if [ "$TUNNEL_IP" = "$LAST_TUNNEL_IP" ]; then 
        sleep 1
        export LAST_TUNNEL_IP=$TUNNEL_IP
        else echo "Tunnel adapter changed!"
        die_die_die
        fi
    done
    return 0 
}    

# start
# If an argument is supplied, use as BAD_IP. CAUTION, this is overwritten when the IP is refreshed in the ip_is_bad function. Disable the refresh mechanism to change this behavior.
[ "$1" ] && BAD_IP="$1"

/usr/bin/clear
echo $SVERSION
echo "Press CTRL+C to exit."
echo -n "Starting up ..."
/bin/date

/usr/bin/curl -s $DIFF_HOST_BAD_IP_FILE > $BAD_IP_FILE # Gets public IP from another LOCAL server.
export BAD_IP=`/bin/cat $BAD_IP_FILE` # Gets the BAD_IP variable when initially ran.
export BAD_IP=`echo -n $BAD_IP` # Remove EOL and makes sure a bad IP address was determined.
    hot_or_not # Checks to see if the BAD_IP variable looks like an IP address.
    if [ -z "$BAD_IP" ]; then ninety_nine_problems # Checks to see if the BAD_IP variable is empty.
    else echo "Bad IP file found!"
    fi
export CURRENT_IP=`curl -s "$IP_CHECK_URL"` # Gets the current public IP info.
export CURRENT_IP=`echo -n $CURRENT_IP`        # Removes EOL.
    if [ -z "$CURRENT_IP" ]; then ninety_nine_problems
    else echo "Current IP determined!"
    fi
    
    if [ "$TUNNEL_STATUS" = "1" ]; then
    first_adapter_check
    fi

echo "Bad IP to avoid:" $BAD_IP
echo "Public IP in use:" $CURRENT_IP
echo "Time between checks:" $LOOPDELAY "seconds"
echo "Time before Bad IP refresh:" "$(($REFRESH * $LOOPDELAY / 60))" "minutes"

while true; do
    ip_is_bad && die_die_die
    throbber
done
