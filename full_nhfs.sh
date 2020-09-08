#!/usr/bin/bash
echo 'Upgrading your system and installing FULL NetHunter Filesystem';
apt update && apt full-upgrade -y && apt install kali-linux-nethunter -y && apt autoremove -y;
exit 0
