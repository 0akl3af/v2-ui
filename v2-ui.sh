#!/bin/bash

#======================================================
#   System Required: CentOS 7+ / Debian 8+ / Ubuntu 16+
#   Description: Manage v2-ui
#   Author: sprov
#   Blog: https://blog.sprov.xyz
#   Github - v2-ui: https://github.com/sprov065/v2-ui
#======================================================

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.1"

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

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "restart panel" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow} press enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://blog.sprov.xyz/v2-ui.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force the latest version to be reinstalled without losing data. Do you want to continue?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red} canceled ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://blog.sprov.xyz/v2-ui.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green} update completed, the panel has been automatically restarted ${plain}"
        exit
        # if [[ $# == 0 ]]; then
        # restart
        # else
        # restart 0
        # fi
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop v2-ui
    systemctl disable v2-ui
    rm /etc/systemd/system/v2-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/v2-ui/ -rf
    rm /usr/local/v2-ui/ -rf

    echo ""
    echo -e "Uninstallation succeeded, if you want to delete this script, run ${green}rm /usr/bin/v2-ui -f${plain} to delete it after exiting the script"
    echo ""
    echo -e "Telegram group: ${green}https://t.me/sprov_blog${plain}"
    echo -e "Github issues: ${green}https://github.com/sprov065/v2-ui/issues${plain}"
    echo -e "Blog: ${green}https://blog.sprov.xyz/v2-ui${plain}"

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset username and password to admin" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/v2-ui/v2-ui resetuser
    echo -e "Username and password have been reset to ${green}admin${plain}, please restart the panel now"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all panel settings, account data will not be lost, username and password will not be changed" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/v2-ui/v2-ui resetconfig
    echo -e "All panels have been reset to defaults, please restart the panels now and use the default ${green}65432${plain} port to access the panels"
    confirm_restart
}

set_port() {
    echo && echo -n -e "input port number [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow} canceled ${plain}"
        before_show_menu
    else
        /usr/local/v2-ui/v2-ui setport ${port}
        echo -e "The port is set, now please restart the panel and use the newly set port ${green}${port}${plain} to access the panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green} panel is already running, no need to restart, if you want to restart, please choose restart ${plain}"
    else
        systemctl start v2-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}v2-ui started successfully ${plain}"
        else
            echo -e "The ${red} panel failed to start, probably because the startup time exceeded two seconds, please check the log information later ${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        echo -e "${green} panel has stopped, no need to stop ${plain} again"
    else
        systemctl stop v2-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}v2-ui stopped successfully ${plain}"
        else
            echo -e "${red} panel failed to stop, maybe because the stop time exceeded two seconds, please check the log information later ${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart v2-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui restarted successfully ${plain}"
    else
        echo -e "${red} panel failed to restart, maybe because the startup time exceeded two seconds, please check the log information later ${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status v2-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable v2-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui set boot auto-start successfully ${plain}"
    else
        echo -e "${red}v2-ui failed to set boot auto-start ${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable v2-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui canceled boot auto-start successfully ${plain}"
    else
        echo -e "${red}v2-ui failed to cancel boot auto-start ${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    echo && echo -n -e "A lot of WARNING logs may be output during the use of the panel. If there is no problem with the use of the panel, then there is no problem, press Enter to continue: " && read temp
    tail -f /etc/v2-ui/v2-ui.log
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.com/sprov065/blog/raw/master/bbr.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green} install bbr successfully ${plain}"
    else
        echo ""
        echo -e "${red} failed to download bbr installation script, please check if the machine can connect to Github${plain}"
    fi

    before_show_menu
}

update_shell() {
    wget -O /usr/bin/v2-ui -N --no-check-certificate https://github.com/sprov065/v2-ui/raw/master/v2-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red} failed to download the script, please check whether the machine can connect to Github${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/v2-ui
        echo -e "${green} upgrade script succeeded, please rerun script ${plain}" && exit 0
    fi
}

update_v2ray() {
    bash <(curl -L -s https://install.direct/go.sh)
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red} failed to update v2ray, please check the error message by yourself ${plain}"
        echo ""
    else
        echo ""
        echo -e "${green} update v2ray successfully ${plain}"
        echo ""
    fi
    before_show_menu
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/v2-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status v2-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled v2-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red} panel is installed, please do not install ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red} please install the panel first ${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Panel Status: ${green} has run ${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Panel Status: ${yellow} is not running ${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Panel Status: ${red} not installed ${plain}"
        ;;
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether it starts automatically at boot: ${green} is ${plain}"
    else
        echo -e "Whether it starts automatically at boot: ${red}No ${plain}"
    fi
}

show_usage() {
    echo "How to use the v2-ui management script: "
    echo "------------------------------------------"
    echo "v2-ui             - show admin menu (more features)"
    echo "v2-ui start       - start v2-ui panel"
    echo "v2-ui stop        - stop the v2-ui panel"
    echo "v2-ui restart     - restart the v2-ui panel"
    echo "v2-ui status      - view v2-ui status"
    echo "v2-ui enable      - set v2-ui to boot automatically"
    echo "v2-ui disable     - cancel v2-ui auto-start"
    echo "v2-ui log         - view v2-ui log"
    echo "v2-ui update      - update v2-ui panel"
    echo "v2-ui install     - install v2-ui panel"
    echo "v2-ui uninstall   - uninstall v2-ui panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}v2-ui panel management script${plain} ${red}${version}${plain}
--- https://blog.sprov.xyz/v2-ui ---
  ${green}0.${plain} exit script
———————————————
  ${green}1.${plain} install v2-ui
  ${green}2.${plain} update v2-ui
  ${green}3.${plain} uninstall v2-ui
———————————————
  ${green}4.${plain} reset username and password
  ${green}5.${plain} reset panel settings
  ${green}6.${plain} set panel port
———————————————
  ${green}7.${plain} start v2-ui
  ${green}8.${plain} stop v2-ui
  ${green}9.${plain} restart v2-ui
 ${green}10.${plain} View v2-ui status
 ${green}11.${plain} View v2-ui log
———————————————
 ${green}12.${plain} set v2-ui to start automatically
 ${green}13.${plain} Cancel v2-ui auto-start
———————————————
 ${green}14.${plain} One-click install bbr (latest kernel)
 ${green}15.${plain} update v2ray
 "
    show_status
    echo && read -p "Please enter selection [0-14]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && start
        ;;
    8)
        check_install && stop
        ;;
    9)
        check_install && restart
        ;;
    10)
        check_install && status
        ;;
    11)
        check_install && show_log
        ;;
    12)
        check_install && enable
        ;;
    13)
        check_install && disable
        ;;
    14)
        install_bbr
        ;;
    15)
        update_v2ray
        ;;
    *)
        echo -e "${red}Please enter the correct number [0-15]${plain}"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
