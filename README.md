# install-kali-termux
### Custom Kali installation based on the minimal file-system of the official nethunter repositories from Offensive Security, in termux without the need of having your device rooted. 
### Open termux and paste this code:
```bash
pkg install wget -y && wget -O install_kali https://git.io/JUnAD && chmod +x install_kali && ./install_kali
```
#### To remotely connect to your phone with a computer paste this code in termux:
```bash
nh -r
apt update && apt install wget -y && wget -O vncserver.sh https://git.io/JUnA7 && sh vncserver.sh
```
#### After the first installation use this piece of code to do a full upgrade of your system and install a full kali-linux-nethunter filesystem automatically!
```bash
nh -r
apt update && apt install wget -y && wget -O full_nhfs.sh https://git.io/JUnAN && sh full_nhfs.sh
```
#### Use this shorturl in your android browser to come to this page directly: 
https://is.gd/kalitermux
