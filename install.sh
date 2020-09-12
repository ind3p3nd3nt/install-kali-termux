#!/bin/bash
# This repository has been forked from https://www.kali.org/docs/nethunter/nethunter-rootless/
# This script is to install NetHunter on other Linux devices than an Android (on CentOS for example) 
# It's currently in BETA stage and under developpment use at your own risk it might contain bugs
VERSION=2020030908
BASE_URL=https://build.nethunter.com/kalifs/kalifs-latest/
USERNAME=kalilinux
PKGMAN=$(if [ -f "/usr/bin/apt" ]; then echo "apt"; else echo "yum"; fi)

if [ -f "/usr/bin/getprop" ]; then getprop="1"; fi
if [ ! -z "$getprop" ]; then archcase=$(getprop ro.product.cpu.abi); fi
if [ -z "$archcase" ]; then archcase=$(uname -m); fi	
function unsupported_arch() {
	printf "${red}"
	echo "[*] Unsupported Architecture\n\n"
	printf "${reset}"
	exit
}
function get_arch() {
    printf "${blue}[*] Checking device architecture ..."
    case $archcase in
        arm64-v8a)
            SYS_ARCH=arm64
            ;;
        armeabi|armeabi-v7a)
            SYS_ARCH=armhf
            ;;
        x86_64|amd64)
            SYS_ARCH=amd64
            ;;
        i386|i686|x86)
            SYS_ARCH=i386
            ;;
        *)
            unsupported_arch
            ;;
    esac
}
get_arch;
	

if [ "$PKGMAN" = "apt" ]; then 
	echo "Backing up sources.list"
	cp /etc/apt/sources.list sources.list.bak -r
	echo "Adding Termux & Kali Sources"
	echo deb https://dl.bintray.com/termux/termux-packages-24/ stable main >/etc/apt/sources.list.d/termux.sources.list
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 5A897D96E57CF20C;
	echo deb http://http.kali.org/kali kali-rolling main contrib non-free >/etc/apt/sources.list
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ED444FF07D8D0BF6;
	apt install net-tools -y;
else
	yum install wget curl epel-release axel -y
	cd /etc/yum.repos.d/
	curl -O https://copr.fedorainfracloud.org/coprs/jlaska/proot/repo/epel-7/jlaska-proot-epel-7.repo
	yum install proot -y
	cd ~;
	curl -O https://build.nethunter.com/kalifs/kalifs-latest//kalifs-${SYS_ARCH}-minimal.tar.xz
	curl -O https://build.nethunter.com/kalifs/kalifs-latest//kalifs-${SYS_ARCH}-minimal.sha512sum
fi


function ask() {
    # http://djm.me/ask
    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question
        printf "${light_cyan}\n[?] "
        read -p "$1 [$prompt] " REPLY

        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi

        printf "${reset}"

        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}


function set_strings() {
    CHROOT=kali-${SYS_ARCH}
    IMAGE_NAME=kalifs-${SYS_ARCH}-minimal.tar.xz
    SHA_NAME=kalifs-${SYS_ARCH}-minimal.sha512sum
}    

function prepare_fs() {
    unset KEEP_CHROOT
    if [ -d ${CHROOT} ]; then
        if ask "Existing rootfs directory found. Delete and create a new one?" "N"; then
            rm -rf ${CHROOT}
        else
            KEEP_CHROOT=1
        fi
    fi
} 

function cleanup() {
    if [ -f ${IMAGE_NAME} ]; then
        if ask "Delete downloaded rootfs file?" "N"; then
        if [ -f ${IMAGE_NAME} ]; then
                rm -f ${IMAGE_NAME}
        fi
        if [ -f ${SHA_NAME} ]; then
                rm -f ${SHA_NAME}
        fi
        fi
    fi
} 

function check_dependencies() {
    printf "${blue}\n[*] Checking package dependencies ***REQUIRES ROOT***${reset}\n"
    ${PKGMAN} update -y &> /dev/null

    for i in proot tar axel; do
        if [ -e $PREFIX/bin/$i ]; then
            echo "  $i is OK"
        else
            printf "Installing ${i}...\n"
            ${PKGMAN} install -y $i || {
                printf "${red}ERROR: Failed to install packages.\n Exiting.\n${reset}"
            exit
            }
        fi
    done
    cp -r sources.list.bak /etc/apt/sources.list;
}


function get_url() {
    ROOTFS_URL="${BASE_URL}/${IMAGE_NAME}"
    SHA_URL="${BASE_URL}/${SHA_NAME}"
}

function get_rootfs() {
    unset KEEP_IMAGE
    if [ -f ${IMAGE_NAME} ]; then
        if ask "Existing image file found. Delete and download a new one?" "N"; then
            rm -f ${IMAGE_NAME}
        else
            printf "${yellow}[!] Using existing rootfs archive${reset}\n"
            KEEP_IMAGE=1
            return
        fi
    fi
    printf "${blue}[*] Downloading rootfs...${reset}\n\n"
    get_url
    axel ${EXTRA_ARGS} --alternate "$ROOTFS_URL"
}

function get_sha() {
    if [ -z $KEEP_IMAGE ]; then
        printf "\n${blue}[*] Getting SHA ... ${reset}\n\n"
        get_url
        if [ -f ${SHA_NAME} ]; then
            rm -f ${SHA_NAME}
        fi
        axel ${EXTRA_ARGS} --alternate "${SHA_URL}"
    fi
}

function verify_sha() {
    if [ -z $KEEP_IMAGE ]; then
        printf "\n${blue}[*] Verifying integrity of rootfs...${reset}\n\n"
        sha512sum -c $SHA_NAME || {
            printf "${red} Rootfs corrupted. Please run this installer again or download the file manually\n${reset}"
            exit 1
        }
    fi
}

function extract_rootfs() {
    if [ -z $KEEP_CHROOT ]; then
        printf "\n${blue}[*] Extracting rootfs... ${reset}\n\n"
        if [ ! -d "$CHROOT" ]; then mkdir $CHROOT; fi
        $(if [ ! -z "$getprop" ]; then echo "proot --link2symlink"; fi) tar vxfJ $IMAGE_NAME $(if [ -z "$getprop" ]; then echo "--keep-directory-symlink"; fi) 2> /dev/null || :
    else        
        printf "${yellow}[!] Using existing rootfs directory${reset}\n"
    fi
}

function update() {
    NH_UPDATE=${PREFIX}/bin/upd
    cat > $NH_UPDATE <<- EOF
#!/bin/bash
unset LD_PRELOAD
user="root"
home="/root"
cmd1="apt update"
cmd2="apt-get install busybox sudo kali-menu kali-tools. -y"
cmd3="apt full-upgrade -y"
cmd4="apt auto-remove -y"
nh -r \$cmd1;
nh -r \$cmd2;
nh -r \$cmd3;
nh -r \$cmd4;
exit 0
EOF
    chmod +x $NH_UPDATE  
}

function webd() {
    NH_WEBD=${PREFIX}/bin/webd
    cat > $NH_WEBD <<- EOF
#!/bin/bash
cd \${HOME}
unset LD_PRELOAD
user="root"
home="/\$user"
cmd1="apt update"
cmd2="apt install apache2 wget sudo git -y"
cmd3="/bin/git clone https://github.com/independentcod/mollyweb"
cmd4="/bin/sh mollyweb/bootstrap.sh"
cmd5="service apache2 start"
nh -r \$cmd1;
nh -r \$cmd2;
nh -r \$cmd3;
if [ -d "\${CHROOT}/root/mollyweb" ]; then rm -rf \${CHROOT}/root/mollyweb; fi
nh -r \$cmd4;
myip=\$(ifconfig | grep inet) 
echo "\${myip} port 8088 http and https port 8443";
echo "Listen 8088" > $CHROOT/etc/apache2/ports.conf;
echo "Listen 8443 ssl" >> $CHROOT/etc/apache2/ports.conf;
nh -r \$cmd5 &
exit 0
EOF
    chmod +x $NH_WEBD  
}


function sexywall() {
    NH_SEXY=${PREFIX}/bin/sexywall
    cat > $NH_SEXY <<- EOF
#!/bin/bash
cd \${HOME}
unset LD_PRELOAD
user="root"
home="/\$user"
cmd1="apt update"
cmd2="apt install git pcmanfm -y"
cmd3="git clone https://github.com/independentcod/lxde-wallpaperchanger.git"
cmd4="sh lxde-wallpaperchanger/install.sh"
nh -r \$cmd1;
nh -r \$cmd2;
nh -r \$cmd3;
nh -r \$cmd4;
EOF
    chmod +x $NH_SEXY  
}


function remote() {
    NH_REMOTE=${PREFIX}/bin/remote
    cat > $NH_REMOTE <<- EOF
#!/bin/bash
cd \${HOME}
unset LD_PRELOAD
nh -r apt update && nh -r apt install tigervnc-standalone-server lxde-core kali-menu net-tools lxterminal -y;
user="kalilinux"
home="/home/\$user"
if [ -f "$CHROOT/tmp/.X3-lock" ]; then rm -rf $CHROOT/tmp/.X3-lock && nh -r /bin/vncserver -kill :3; fi
echo 'VNC Server listening on 0.0.0.0:5903 you can remotely connect another device to that display with a vnc viewer';
myip=\$(ifconfig | grep inet) 
echo "\$myip";
nh -r /bin/vncserver :3 -localhost no&
exit 0
EOF
    chmod +x $NH_REMOTE  
}



function create_launcher() {
    NH_LAUNCHER=${PREFIX}/bin/nethunter
    NH_SHORTCUT=${PREFIX}/bin/nh
    cat > $NH_LAUNCHER <<- EOF
#!/bin/bash
cd \${HOME}
## termux-exec sets LD_PRELOAD so let's unset it before continuing
unset LD_PRELOAD
## Workaround for Libreoffice, also needs to bind a fake /proc/version
if [ ! -f $CHROOT/root/.version ]; then
    if [ ! -d $CHROOT/root/ ]; then mkdir $CHROOT/root/; fi
    touch $CHROOT/root/.version
fi

## Default user is "kalilinux"
user="kalilinux"
home="/home/kalilinux"
start="sudo -u $USERNAME /bin/bash --login"

## NH can be launched as root with the "-r" cmd attribute
## Also check if user $USERNAME exists, if not start as root
if grep -q "$USERNAME" ${CHROOT}/etc/passwd; then
    KALIUSR="1";
else
    KALIUSR="0";
fi
if [[ \$KALIUSR == "0" || ("\$#" != "0" && ("\$1" == "-r" || "\$1" == "-R")) ]]; then
    user="root"
    home="/\$user"

    start="/bin/bash --login"
    if [[ "\$#" != "0" && ("\$1" == "-r" || "\$1" == "-R") ]]; then
        shift
    fi
fi

cmdline="proot \\
		$(if [ ! -z "$getprop" ]; then echo "--link2symlink \\\\"; fi)
        -0 \\
        -r $CHROOT \\
        -b /dev \\
        -b /proc \\
        -b $CHROOT\$home:/dev/shm \\
        -w \$home \\
           /usr/bin/env -i \\
           HOME=\$home \\
           PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin \\
           TERM=\$TERM \\
           LANG=C.UTF-8 \\
           \$start"

cmd="\$@"
if [ "\$#" == "0" ]; then
    exec \$cmdline
else
    \$cmdline -c "\$cmd"
fi
EOF

    chmod 700 $NH_LAUNCHER
    if [ -L ${NH_SHORTCUT} ]; then
        rm -f ${NH_SHORTCUT}
    fi
    if [ ! -f ${NH_SHORTCUT} ]; then
        ln -s ${NH_LAUNCHER} ${NH_SHORTCUT} >/dev/null
    fi
   
}


function fix_profile_bash() {
    ## Prevent attempt to create links in read only filesystem
    if [ -f ${CHROOT}/root/.bash_profile ]; then
        sed -i '/if/,/fi/d' "${CHROOT}/root/.bash_profile"
    fi
}

function fix_sudo() {
    ## fix sudo & su on start
    if [ -f "$CHROOT/usr/bin/sudo" ]; then chmod +s $CHROOT/usr/bin/sudo; else nh -r apt update && nh -r apt install sudo busybox -y && chmod +s $CHROOT/usr/bin/sudo; fi
    if [ -f "$CHROOT/usr/bin/su" ]; then chmod +s $CHROOT/usr/bin/su; fi
    echo "root    ALL=(ALL:ALL) ALL" > $CHROOT/etc/sudoers
    echo "%sudo    ALL=(ALL:ALL) NOPASSWD:ALL" >> $CHROOT/etc/sudoers
    # https://bugzilla.redhat.com/show_bug.cgi?id=1773148
    echo "Set disable_coredump false" > $CHROOT/etc/sudo.conf
}

function fix_uid() {
    ## Change $USERNAME uid and gid to match that of the termux user
    GRPID=$(id -g)
    chmod 440 $CHROOT/etc/sudoers $CHROOT/etc/sudo.conf $CHROOT/usr/bin/sudo $CHROOT/etc/hosts 
    chmod 777 /bin/nh /bin/nethunter /bin/remote /bin/webd /bin/upd /bin/sexywall ${CHROOT}/home/${USERNAME} -R
    nh -r usermod -g sudo $USERNAME 2>/dev/null
    nh -r groupmod -g $GRPID $USERNAME 2>/dev/null
    if [ -f "/usr/sbin/ifconfig" ]; then mv -f /usr/sbin/ifconfig /usr/bin/ifconfig; fi
    chmod 777 /usr/bin/ifconfig;
}

function print_banner() {
    clear
    printf "${blue}##################################################\n"
    printf "${blue}##                                              ##\n"
    printf "${blue}##  88      a8P         db        88        88  ##\n"
    printf "${blue}##  88    .88'         d88b       88        88  ##\n"
    printf "${blue}##  88   88'          d8''8b      88        88  ##\n"
    printf "${blue}##  88 d88           d8'  '8b     88        88  ##\n"
    printf "${blue}##  8888'88.        d8YaaaaY8b    88        88  ##\n"
    printf "${blue}##  88P   Y8b      d8''''''''8b   88        88  ##\n"
    printf "${blue}##  88     '88.   d8'        '8b  88        88  ##\n"
    printf "${blue}##  88       Y8b d8'          '8b 888888888 88  ##\n"
    printf "${blue}##            Forked by @independentcod         ##\n"
    printf "${blue}################### NetHunter ####################${reset}\n\n"
}

##################################
##              Main            ##

# Add some colours
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
light_cyan='\033[1;96m'
reset='\033[0m'

EXTRA_ARGS=""
if [[ ! -z $1 ]]; then
    EXTRA_ARGS=$1
    if [[ $EXTRA_ARGS != "--insecure" ]]; then
        EXTRA_ARGS=""
    fi
fi

cd $HOME
print_banner
get_arch
set_strings
prepare_fs
check_dependencies
get_rootfs
get_sha
verify_sha
extract_rootfs
printf "\n${blue}[*] Configuring NetHunter for $(uname -a) ...\n"
create_launcher
update
remote
webd
sexywall
if [ ! -d ${CHROOT}/home/${USERNAME} ]; then nh -r /sbin/useradd -m $USERNAME; fi
if [ ! -d ${CHROOT}/home/${USERNAME} ]; then nh /bin/mkdir /home/${USERNAME}; fi
if [ ! -d ${CHROOT}/root/Desktop/ ]; then nh -r /bin/mkdir /root/Desktop/; fi
if [ ! -d ${CHROOT}/root/Desktop/Wallpapers ]; then nh -r /bin/mkdir /root/Desktop/Wallpapers; fi
if [ ! -d ${CHROOT}/root/.vnc ]; then nh -r /bin/mkdir /root/.vnc; fi
echo 'lxsession &' > ${CHROOT}/root/.vnc/xstartup;
echo 'lxterminal &' >> ${CHROOT}/root/.vnc/xstartup;
echo "127.0.0.1   OffensiveSecurity OffensiveSecurity.localdomain OffensiveSecurity OffensiveSecurity.localdomain4" > $CHROOT/etc/hosts
echo "::1         OffensiveSecurity OffensiveSecurity.localdomain OffensiveSecurity OffensiveSecurity.localdomain6" >> $CHROOT/etc/hosts
cleanup
fix_profile_bash
fix_sudo
fix_uid
print_banner
printf "${green}[=] NetHunter for Termux installed successfully${reset}\n\n"
printf "${green}[+] To start NetHunter, type:${reset}\n"
printf "${green}[+] nethunter             # To start NetHunter cli${reset}\n"
printf "${green}[+] nethunter -r          # To run NetHunter as root${reset}\n"
printf "${green}[+] nh                    # Shortcut for nethunter${reset}\n\n"
printf "${green}[+] upd                   # To update everything and install ALL Kali Linux tools${reset}\n\n"
printf "${green}[+] remote                # To install a LXDE Display Manager on port 5903 reachable by other devices and set password${reset}\n\n"
printf "${green}[+] remote &              # To start the VNC server${reset}\n\n"
printf "${green}[+] sexywall &            # To install a sexy wallpaper rotator in LXDE for remote sessions${reset}\n\n"
printf "${green}[+] webd &                # To install an SSL Website www.mollyeskam.net as template${reset}\n\n"
