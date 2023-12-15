#!/bin/bash
# Velocty proxy stop script - primarily called by the Minecraft service
# but can be ran manually with ./vstop.sh

# This script is a combination of several sources and are credited here in no order of priority.
# GitHub Repository: https://github.com/TheRemote/RaspberryPiMinecraft

# Check to make sure we aren't running as root
if [[ $(id -u) = 0 ]]; then
  echo "This script is not meant to run as root or sudo.  Please run as a normal user with ./stop.sh.  Exiting..."
  exit 1
fi

# Check if server is running
if ! screen -list | grep -q "\.velocity"; then
  echo "Proxy is not currently running!"
  exit 1
fi

echo "Sending server stop request to proxy...."

# Sending warning messages to the console.
#screen -Rd velocity -X stuff "say Stop sequence activated. Server will stop in 30 seconds! $(printf '\r')"
#echo "Stop sequence activated. Server will stop in 30 seconds!"
#sleep 23s
#screen -Rd velocity -X stuff "say Stop sequence activated. Server will stop in 7 seconds! $(printf '\r')"
#echo "Stop sequence activated. Server will stop in 7 seconds!"
#sleep 1s
#screen -Rd velocity -X stuff "say Stop sequence activated. Server will stop in 6 seconds!! $(printf '\r')"
#echo "Stop sequence activated. Server will stop in 6 seconds!"
#sleep 1s
#screen -Rd velocityt -X stuff "say Server will stop in 5 seconds! $(printf '\r')"
#echo "Server will stop in 5 seconds!"
#sleep 1s
#screen -Rd velocity -X stuff "say Server will stop in 4 seconds! $(printf '\r')"
#echo "Server will stop in 4 seconds!"
#sleep 1s
#screen -Rd velocity -X stuff "say Server will stop in 3 seconds! $(printf '\r')"
#echo "Server will stop in 3 seconds!"
#sleep 1s
#screen -Rd velocity -X stuff "say Server will stop in 2 seconds! $(printf '\r')"
#echo "Server will stop in 2 seconds!"
#sleep 1s
#screen -Rd velocity -X stuff "say Server will stop in 1 second! $(printf '\r')"
#echo "Proxy will stop in 1 second!"
#sleep 1s
#screen -Rd velocity -X stuff "say Closing server...$(printf '\r')"
screen -Rd velocity -X stuff "stop$(printf '\r')"

# Wait up to 60 seconds for server to close
echo "Closing proxy..."
echo "This could take up to 60 seconds."
StopChecks=0
while [ $StopChecks -lt 60 ]; do
  if ! screen -list | grep -q "\.velocity"; then
    break
  fi
  sleep 1;
  StopChecks=$((StopChecks+1))
done

# Force quit if server is still open
if screen -list | grep -q "\.velocity"; then
  echo "Velocity proxy still hasn't closed after 60 seconds, closing screen manually"
  screen -S velocity -X quit
fi

echo "Velocity proxy stopped."

# Sync all filesystem changes out of temporary RAM
sync
