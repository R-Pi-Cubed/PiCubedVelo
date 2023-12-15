#!/bin/bash

# This script is an installation aid to help install a Velocity proxy on a Raspberry Pi.
# For detailed instrustions please visit https://docs.picubed.me
# Note - This script will NOT fetch any version of Velocity. The user is responsible for transfering a copy of the latest
# Velocity proxy *.jar file to the Pi in the proper directory. Please visit https://docs.picubed.me

# Parts of this script have been pulled from other sources and are credited here in no order of priority.
# GitHub Repository: https://gist.github.com/Prof-Bloodstone/6367eb4016eaf9d1646a88772cdbbac5
# GitHub Repository: https://github.com/TheRemote/RaspberryPiMinecraft
# GitHub Repository: https://github.com/Cat5TV/pinecraft

# PiCubed server version - not currently used for anything
Version="0.9"

# The minimum Java version required for the version on Minecraft you want to install
MinJavaVer=17

# Terminal colors using ANSI escape
# Foreground
fgBLACK=$(tput setaf 0)
fgRED=$(tput setaf 1)
fgGREEN=$(tput setaf 2)
fgYELLOW=$(tput setaf 3)
fgBLUE=$(tput setaf 4)
fgMAGENTA=$(tput setaf 5)
fgCYAN=$(tput setaf 6)
fgWHITE=$(tput setaf 7)
#Text formatting options
txMOVEUP=$(tput cuu 1)
txCLEARLINE=$(tput el 1)
txBOLD=$(tput bold)
txRESET=$(tput sgr0)
txREVERSE=$(tput smso)
txUNDERLINE=$(tput smul)

# apt update counter to not update more than once
Updated=0

# Get the current system user
UserName=$(whoami)

# Prints a line with color using terminal codes
Print_Style() {
  printf "%s\n" "${2}$1${txRESET}"
}

# Configure how much memory to use for Velocity proxy
Get_ServerMemory() {
  sync

  Print_Style " " "$fgCYAN"
  Print_Style "Checking the total system memory..." "$fgCYAN"
  TotalMemory=$(awk '/MemTotal/ { printf "%.0f\n", $2/1024 }' /proc/meminfo)
  AvailableMemory=$(awk '/MemAvailable/ { printf "%.0f\n", $2/1024 }' /proc/meminfo)

  sleep 1s

  Print_Style "Total system memory: $TotalMemory" "$fgCYAN"
  Print_Style "Total available memory: $AvailableMemory" "$fgCYAN"

  if [ $AvailableMemory -lt 1024 ]; then
    Print_Style " " "$fgCYAN"
    Print_Style "WARNING:  There is less than 1Gb of available system memory. This will impact performance and stability." "$fgRED"
    Print_Style "You may be able to increase the available memory by closing other processes." "$fgYELLOW"
    Print_Style "If nothing else is running your operating system may be using all available memory." "$fgYELLOW"
    Print_Style "Please be sure that you are using a headless (no GUI) operating system." "$fgYELLOW"
    Print_Style "Installation aborted." "$fgRED"
    exit 1
  elif [ "$AvailableMemory" -lt 3072 ]; then
    Print_Style " " "$fgCYAN"
    Print_Style "CAUTION: There is a limited amount of RAM available." "$fgYELLOW"
    Print_Style "The Operating system and background processes require some ram to function properly." "$fgYELLOW"
    Print_Style "With $AvailableMemory you may experience performance issues." "$fgYELLOW"
  fi
    
  Print_Style " " "$fgCYAN"
  Print_Style "Please enter the amount of memory you want to dedicate to the proxy." "$fgCYAN"
  Print_Style "You must leave enough left over memory for the system to run background processes." "$fgCYAN"
  Print_Style "If the system is not left with enough ram it will crash." "$fgCYAN"
  Print_Style "NOTE: For optimal performance this ram will always be reserved for the server while the server is running." "$fgYELLOW"

  MemSelected=0

  RecommendedMemory=$(($AvailableMemory - 1024))

  while [[ $MemSelected -lt 1024 || $MemSelected -ge $AvailableMemory ]]; do
    Print_Style " " "$fgCYAN"
    Print_Style "Enter the amount of memory in megabytes to dedicate to the proxy (recommended: $RecommendedMemory):" "$fgCYAN"
    read MemSelected < /dev/tty
    if [[ $MemSelected -lt 1024 ]]; then
      Print_Style "Please enter a minimum of 1024mb" "$fgRED"
      MemSelected=0
    elif [[ $MemSelected -gt $AvailableMemory ]]; then
      Print_Style "Please enter an amount less than the available system memory: ($AvailableMemory)" "$fgRED"
      MemSelected=0
    fi
  done
  Print_Style " " "$fgCYAN"
  Print_Style "Velocity proxy will be allocated $MemSelected MB of ram." "$fgGREEN"
  sleep 1s
}

# Updates all scripts
Update_Scripts() {
  cd "$DirName/velocity"

  # Upsate vstart.sh
  Print_Style "Updating vstart.sh ..." "$fgYELLOW"
  sudo chmod +x vstart.sh
  sed -i "s:dirname:$DirName:g" vstart.sh
  sed -i "s:memselect:$MemSelected:g" vstart.sh
  sed -i "s:userxname:$UserName:g" vstart.sh
  sleep 1

  # Update vstop.sh
  Print_Style "Updating vstop.sh ..." "$fgYELLOW"
  sudo chmod +x vstop.sh
  sed -i "s:dirname:$DirName:g" vstop.sh
  sleep 1

  # Update restart.sh
  #Print_Style "Updating restart.sh ..." "$fgYELLOW"
  #sudo chmod +x restart.sh
  #sed -i "s:dirname:$DirName:g" restart.sh
  #sleep 1

  # Update backup.sh
  #Print_Style "Updating backup.sh ..." "$fgYELLOW"
  #sudo chmod +x backup.sh
  #sed -i "s:dirname:$DirName:g" backup.sh
  #sleep 1
}

# Update systemd files to create a Velocity service.
Update_Service() {
  sudo cp "$DirName"/PiCubedVelo/velocity.service /etc/systemd/system/
  sudo sed -i "s:userxname:$UserName:g" /etc/systemd/system/velocity.service
  sudo sed -i "s:dirname:$DirName:g" /etc/systemd/system/velocity.service
  sudo systemctl daemon-reload
  Print_Style " " "$fgCYAN"
  Print_Style "Velocity proxy can start automatically at boot if enabled." "$fgCYAN"
  Print_Style "Start the proxy automatically at boot? (y/n)?" "$fgYELLOW"
  read answer < /dev/tty
  if [ "$answer" != "${answer#[Yy]}" ]; then
    sudo systemctl enable velocity.service
  fi
}

# Configure a CRON job to reboot the system daily
# Minecraft servers benefit from a daily reboot in off hours
# It's also a good time to do the daily backup
Configure_Reboot() {
  # Automatic reboot at 4am configuration
  TimeZone=$(cat /etc/timezone)
  CurrentTime=$(date)
  Print_Style " " "$fgCYAN"
  Print_Style "Your time zone is currently set to $TimeZone." "$fgCYAN"
  Print_Style "Current system time: $CurrentTime" "$fgCYAN"
  Print_Style " " "$fgCYAN"
  sleep 1s
  Print_Style "It is recommended to reboot your Velocity proxy regularly." "$fgCYAN"
  #Print_Style "During a reboot is also a good time to do a server backup." "$fgCYAN"
  #Print_Style "Server backups will automatically be cycled and only the most recent 10 backups will be kept." "$fgCYAN"
  Print_Style "You can adjust/remove the selected reboot & backup time later by typing crontab -e" "$fgCYAN"
  Print_Style "Enable automatic daily reboot and server at 4am (y/n)?" "$fgYELLOW"
  read answer < /dev/tty
  if [ "$answer" != "${answer#[Yy]}" ]; then
    croncmd="$DirName/velocity/vrestart.sh"
    cronjob="0 4 * * * $croncmd 2>&1"
    (
      crontab -l | grep -v -F "$croncmd"
      echo "$cronjob"
    ) | crontab -
    Print_Style "Daily reboot scheduled.  To change time or remove automatic reboot type crontab -e" "$fgGREEN"
    sleep 1
  fi
}

Set_Permissions() {
  Print_Style " " "$fgCYAN"
  Print_Style "Setting proxy file permissions..." "$fgCYAN"
  sleep 1s
  #sudo ./setperm.sh -a > /dev/null
  sudo chown -Rv "$UserName $DirName/velocity"
  sudo chmod -Rv 755 "$DirName/velocity/*.sh"

}

Java_Check() {
  Print_Style "Checking Java..." "$fgCYAN"
  if [[ $Updated == 0 ]]; then
    sudo apt update > /dev/null 2>&1
    Updated=1
  fi

  # Java installed?
  if type -p java > /dev/null; then
    _java=java
  elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
      _java="$JAVA_HOME/bin/java"
  else
    Print_Style "No version of Java detected. Please install the latest JRE first and try again." "$fgRED"
    Print_Style " " "$fgCYAN"
    Print_Style "Install aborted." "$fgRED"
    Print_Style " " "$fgCYAN"
    exit 0
  fi

  # Detect the version of Java installed
  javaver=0
  if [[ "$_java" ]]; then
    javaver=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
  fi

  ver=0
  for i in $(echo $javaver | tr "." "\n")
  do
    if [[ $ver == 0 ]]; then
      ver=$i
    else
      subver=$i
      break
    fi
  done

  # minimum version of Java supported by Minecraft Server
  if [[ $ver -ge $MinJavaVer ]]; then
    Print_Style "The installed Java is version ${javaver}. You are good to go." "$fgGREEN"
    sleep 1s
  else
    Print_Style "The installed Java is version ${javaver}. You'll need a newer version of Java to continue." "$fgRED"
    exit 0
  fi
}


Dependancy_Check(){

  CPUArch=$(uname -m)

  Print_Style "Doing a dependancy check." "$fgCYAN"
  sleep 1s

  if [[ "$CPUArch" == *"aarch64"* || "$CPUArch" == *"arm64"* ]]; then
    Print_Style "You are running a 64 bit operating system." "$fgGREEN"
    sleep 1s
  else
    if [[ "$CPUArch" == *"armv7"* || "$CPUArch" == *"armhf"* ]]; then
      Print_Style "You are running a 32 bit operating system." "$fgRED"
      Print_Style "This script does not support 32 bit operating systems. Please upgrade your base os to a 64 bit system." "$fgYellow"
      Print_Style "In the near future Minecraft Java will no longer support a 32 bit OS." "$fgYellow"
      exit 1
    else
      Print_Style "Unable to verify your operating system." "$fgRED"
      Print_Style "Please ensure that you are running a 64 bit operating system." "$fgYellow"
      exit 1
    fi
  fi

  # Verify the directory path
  if [ -d "$HOME/PiCubedVelo" ]; then
    Print_Style "The Home directory has been verified." "$fgGREEN"
    DirName=$HOME
    sleep 1s
  else
    Print_Style "Failed to find the PiCubed directory." "$fgRED"
    Print_Style "Exiting." "$fgRED"
    exit 1
  fi

  if [ $(dpkg-query -W -f='${Status}' screen 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    Print_Style "Installing the latest version of screen.... Not your screen, the program known as screen." "$fgYELLOW"
    if [[ $Updated == 0 ]]; then
      sudo apt update > /dev/null 2>&1
      Updated=1
    fi
    sudo apt -y install screen > /dev/null 2>&1
  else
    Print_Style "The latest version of screen has been detected.... Not your screen, the program known as screen." "$fgGREEN"
    sleep 1s
  fi

}

Cleanup(){

  #placeholder
  rm -rf "$DirName/PiCubedVelo"

}

Build_System(){

  cd ~

  ServerFile="$DirName/PiCubedVelo/velocity.jar"

  if [ -f "$ServerFile" ]; then
    Print_Style "Located the velocity.jar file." "$fgGREEN"
    sleep 1s
  else 
    Print_Style "Unable to locate the $ServerFile file." "$fgRED"
    Print_Style "Please be sure that you have uploaded the latest velocity.jar file to the PiCubedVelo directory." "$fgYELLOW"
    Print_Style "Also be sure that it is named velocity.jar." "$fgYELLOW"
    exit 1
  fi

  # Check to see if the Minecraft directory already exists.
  if [ -d "$DirName/velocity" ]; then
    Print_Style "An existing Velocity directory has been found." "$fgRED"
    Print_Style "Please remove the directory before continuing." "$fgRED"
    exit 1
  else
    Print_Style "Creating the Velocity directory." "$fgCYAN"
    mkdir velocity
    sleep 1s
  fi

  # Verify if the directory was created correctly
  if [ -d "$DirName/velocity" ]; then
    Print_Style "Moving into the Velocity directory." "$fgCYAN"
    cd "$DirName/velocity"
    sleep 1s
  else
    Print_Style "Failed to create the velocity directory." "$fgRED"
    Print_Style "Exiting." "$fgRED"
    exit 1
  fi

  # Create the backup directory
  #Print_Style "Creating the backups directory." "$fgCYAN"
  #mkdir backups
  #sleep 1s

  Print_Style "Copying files." "$fgCYAN"
  sudo cp "$DirName"/PiCubedVelo/{vstart.sh,vstop.sh,vrestart.sh,velocity.jar} "$DirName"/velocity/

  cd ~
}

Init_proxy(){
  
  cd "$DirName/velocity"

  Print_Style " " "$fgCYAN"
  Print_Style "Now running the proxy for the first time." "$fgYELLOW"
  sleep 1s
  Print_Style "This will initialize the proxy. Please wait." "$fgYELLOW"
  sleep 1s
  Print_Style "Errors at this stage are normal and expected." "$fgYELLOW"
  sleep 1s
  Print_Style "Please wait." "$fgYELLOW$txREVERSE"
  Print_Style " " "$fgCYAN"
  java -jar -Xms1000M -Xmx1000M velocity.jar --nogui
  
  cd ~

}

Start_proxy(){
  sudo systemctl start velocity.service

  # Wait up to 30 seconds for server to start
  StartChecks=0
  while [ $StartChecks -lt 30 ]; do
    if screen -list | grep -q "\.velocity"; then
      Print_Style "Your Velocity proxy is now starting on $IP" "$fgCYAN"
      break
    fi
    sleep 1s
    StartChecks=$((StartChecks + 1))
  done

  if [[ $StartChecks == 30 ]]; then
    Print_Style "Server has failed to start after 30 seconds." "$fgRED"
    exit 1
  fi

}
#################################################################################################

clear

Print_Style "PiCubed Velocity proxy installation script" "$txREVERSE$fgCYAN"
Print_Style " " "$fgCYAN"
Print_Style "The latest version is available at https://github.com/R-Pi-Cubed" "$fgCYAN"

# Check to make sure we aren't running as root
if [[ $(id -u) = 0 ]]; then
   Print_Style "This script is not meant to run as root or sudo.  Please run as a normal user with ./PiCubedVelo.sh  Exiting..." "$fgRED"
   exit 1
fi

sleep 1s

# Verify the assumed dependancies
Dependancy_Check

#Check that Java is installed and it's a recent enough version
Java_Check

# Build the system structure
Build_System

# Get total system memory
Get_ServerMemory

# Run the Minecraft server for the first time which will build the server and exit saying the EULA needs to be accepted.
#Init_Server

# Update Minecraft server scripts
Update_Scripts

# Service configuration
Update_Service

# Configure automatic start on boot
Configure_Reboot

# Sudoers configuration
#Update_Sudoers

# Fix server files/folders permissions
#Set_Permissions

# Update Server configuration
#if [[ -e $DirName/minecraft/server.properties ]]; then
#  Configure_Server
#fi

# Basic server installed
Print_Style "Setup is complete." "$txBOLD$fgGREEN"
Print_Style "Your proxy will now be started for the first time to test the service created for autostart." "$fgCYAN"
#Print_Style "NOTE: World generation can take several minutes. Please be patient." "$fgYELLOW"
sleep 5
Start_Server

#Offer semi-auto optimization
#Print_Style " " "$fgCYAN"
#Print_Style "This script can optionally update your server configuration files" "$fgCYAN"
#Print_Style "for the most common performance adjustements." "$fgCyan"
#sleep 1s
#Print_Style " " "$fgCYAN"
#Print_Style "Do you want to optimize? (y/n)?" "$fgYELLOW"
#read answer < /dev/tty
#if [ "$answer" != "${answer#[Yy]}" ]; then
#  Optimize_Server
#fi

Print_Style " " "$fgCYAN"
Print_Style "Server installation complete." "$fgGREEN$txBOLD"
Print_Style "To view the screen that your proxy is running in type...  screen -r velocity" "$fgYELLOW"
Print_Style "To exit the screen and let the server run in the background, press Ctrl+A then Ctrl+D" "$fgYELLOW"
Print_Style "For the full documentation: https://docs.picubed.me" "$fgCYAN"
exit 0