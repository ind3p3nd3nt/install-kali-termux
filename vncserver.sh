#!/usr/bin/bash
mkdir ~/.vnc;
echo 'lxsession &' >~/.vnc/xstartup;
echo 'lxterminal &' >>~/.vnc/xstartup;
apt update && apt install tigervnc-standalone-server lxde-core net-tools lxterminal -y;
myip=$(ifconfig wlan0 | grep inet)
rm -rf /tmp/.X*;
vncserver -kill :3;
vncserver :3 -localhost no;
echo 'VNC Server listening on 0.0.0.0:5903 you can remotely connect another device to that display with a vnc viewer';
echo "Your Phone IP address: $myip";
