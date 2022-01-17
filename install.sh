#!/usr/bin/env bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} must be root to run this script!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red} no system version detected, please contact the script author! ${plain}\n" && exit 1
fi

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit system (x86), please use 64-bit system (x86_64), if the detection is wrong, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later! ${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later! ${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar unzip -y
    else
        apt install wget curl tar unzip -y
    fi
}

install_v2ray() {
    echo -e "${green} start installing or upgrading v2ray ${plain}"
    bash <(curl -L -s https://install.direct/go.sh)
    if [[ $? -ne 0 ]]; then
        echo -e "${red}v2ray failed to install or upgrade, please check the error message ${plain}"
        echo -e "${yellow} Most of the reasons may be because the region where your current server is located cannot download the v2ray installation package. This is more common on domestic machines. The solution is to manually install v2ray. Please refer to the above for the specific reasons. Error message ${plain}"
        exit 1
    fi
    systemctl enable v2ray
    systemctl start v2ray
}

close_firewall() {
    if [[ x"${release}" == x"centos" ]]; then
        systemctl stop firewalld
        systemctl disable firewalld
    elif [[ x"${release}" == x"ubuntu" ]]; then
        ufw disable
    elif [[ x"${release}" == x"debian" ]]; then
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -F
    fi
}

install_v2-ui() {
    systemctl stop v2-ui
    cd /usr/local/
    if [[ -e /usr/local/v2-ui/ ]]; then
        rm /usr/local/v2-ui/ -rf
    fi
    last_version=$(curl -Ls "https://api.github.com/repos/sprov065/v2-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([ ^"]+)".*/\1/')
    echo -e "Detected the latest version of v2-ui: ${last_version}, start installation"
    wget -N --no-check-certificate -O /usr/local/v2-ui-linux.tar.gz https://github.com/sprov065/v2-ui/releases/download/${last_version}/v2 -ui-linux.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${red} failed to download v2-ui, please make sure your server can download Github files. If the installation fails for many times, please refer to the manual installation tutorial ${plain}"
        exit 1
    fi
    tar zxvf v2-ui-linux.tar.gz
    rm v2-ui-linux.tar.gz -f
    cd v2-ui
    chmod +x v2-ui
    cp -f v2-ui.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable v2-ui
    systemctl start v2-ui
    echo -e "${green}v2-ui v${last_version}${plain} installation completed, panel started,"
    echo -e ""
    echo -e "If it is a fresh installation, the default web port is ${green}65432${plain}, and the default username and password are ${green}admin${plain}"
    echo -e "Please make sure this port is not occupied by other programs, ${yellow} and make sure port 65432 has been released ${plain}"
    echo -e "If you want to modify 65432 to another port, enter the v2-ui command to modify it, and also make sure that the port you modify is also allowed"
    echo -e ""
    echo -e "If updating the panel, access the panel as you did before"
    echo -e ""
    curl -o /usr/bin/v2-ui -Ls https://raw.githubusercontent.com/sprov065/v2-ui/master/v2-ui.sh
    chmod +x /usr/bin/v2-ui
    echo -e "How to use the v2-ui management script: "
    echo -e "-------------------------------------------------------- "
    echo -e "v2-ui              - show admin menu (more features)"
    echo -e "v2-ui start        - start v2-ui panel"
    echo -e "v2-ui stop         - stop the v2-ui panel"
    echo -e "v2-ui restart      - restart v2-ui panel"
    echo -e "v2-ui status       - view v2-ui status"
    echo -e "v2-ui enable       - set v2-ui to start automatically"
    echo -e "v2-ui disable      - cancel v2-ui auto-start"
    echo -e "v2-ui log          - view v2-ui log"
    echo -e "v2-ui update       - update v2-ui panel"
    echo -e "v2-ui install      - install v2-ui panel"
    echo -e "v2-ui uninstall    - uninstall v2-ui panel"
    echo -e "-------------------------------------------------------- "
}

echo -e "${green} starts installing ${plain}"
install_base
install_v2ray
close_firewall
install_v2-ui
