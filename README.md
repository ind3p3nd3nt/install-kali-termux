# install-kali-termux
### Custom Kali installation in termux without the need of having your device rooted. 
### Open termux and paste this code:

##### pkg install wget -y && wget -O install_kali https://github.com/independentcod/install-kali-termux/raw/master/install.sh && chmod +x install_kali && ./install_kali

#### To remotely connect to your phone with a computer paste this code in termux:
##### nh -r
##### apt update && apt install wget -y && wget -O vncserver.sh https://github.com/independentcod/install-kali-termux/raw/master/vncserver.sh && sh vncserver.sh

#### After the first installation use this piece of code to do a full upgrade of your system and install a full kali-linux-nethunter filesystem automatically!
##### apt update && apt install wget -y && wget -O full_nhfs.sh https://github.com/independentcod/install-kali-termux/raw/master/full_nhfs.sh && sh full_nhfs.sh

#### Use this shorturl in your android browser to come to this page directly: 
https://is.gd/kalitermux
