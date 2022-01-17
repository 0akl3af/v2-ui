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

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} This script must be run with the root user!\n" && exit 1

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
    echo -e "${red}No system version detected, please contact the script author!${plain}\n" && exit 1
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
        echo -e "${red}Please use CentOS 7 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or higher!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or higher!${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [Default$2]: " temp
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
    confirm "Whether to restart the panel, restarting the panel will also restart v2ray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to the main menu: ${plain}" && read temp
    show_menu
}

install() {
    # bash <(curl -Ls https://blog.sprov.xyz/v2-ui.sh)
    bash <(curl -Ls https://raw.githubusercontent.com/0akl3af/v2-ui/master/v2-ui.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "This function will force reinstallation of the current latest version without data loss, does it continue?" "n"
    if [[ $? != 0 ]]; then
        echo -e "${red}已取消${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    # bash <(curl -Ls https://blog.sprov.xyz/v2-ui.sh)
    bash <(curl -Ls https://raw.githubusercontent.com/0akl3af/v2-ui/master/v2-ui.sh)
    if [[ $? == 0 ]]; then
        echo -e "${green}The update is complete and the panel has been automatically restarted${plain}"
        exit
#        if [[ $# == 0 ]]; then
#            restart
#        else
#            restart 0
#        fi
    fi
}

uninstall() {
    confirm "Are you sure you want to uninstall the panel, v2ray will uninstall it too?" "n"
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
    echo -e "Uninstall successfully, if you want to delete this script, exit the script and run ${green}rm /usr/bin/v2-ui -f${plain} Perform deletion"
    echo ""
    echo -e "Telegram Groups: ${green}https://t.me/sprov_blog${plain}"
    echo -e "Github issues: ${green}https://github.com/sprov065/v2-ui/issues${plain}"
    echo -e "Blog: ${green}https://blog.sprov.xyz/v2-ui${plain}"

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "Are you sure you want to reset the username and password to admin?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/v2-ui/v2-ui resetuser
    echo -e "Username and password have been reset to ${green}admin${plain}，Now please restart the panel"
    confirm_restart
}

reset_config() {
    confirm "Are you sure you want to reset all the panel settings, the account data will not be lost, the username and password will not be changed" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/v2-ui/v2-ui resetconfig
    echo -e "All panels have been reset to their default values, now please restart the panels and use the default ${green}65432${plain} Port Access Panel"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Enter the port number[1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        echo -e "${yellow}Canceled${plain}"
        before_show_menu
    else
        /usr/local/v2-ui/v2-ui setport ${port}
        echo -e "After setting the port, now please restart the panel and use the newly set port ${green}${port}${plain} Access Panel"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}panel is running, no need to start again, if you want to restart please select restart${plain}"
    else
        systemctl start v2-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}v2-ui started successfully${plain}"
        else
            echo -e "${red}panel failed to start, probably because it took more than two seconds to start, please check the log message later${plain}"
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
        echo -e "${green}panel is stopped, no need to stop${plain}"
    else
        systemctl stop v2-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            echo -e "${green}v2-ui and v2ray stopped successfully${plain}"
        else
            echo -e "${red}panel failed to stop, probably because it took more than two seconds to stop, please check the log message later${plain}"
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
        echo -e "${green}v2-ui and v2ray restarted successfully${plain}"
    else
        echo -e "${red}panel reboot failed, probably because it took more than two seconds to start, please check the logs later${plain}"
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
        echo -e "${green}v2-ui set to boot successfully${plain}"
    else
        echo -e "${red}v2-ui failed to boot${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable v2-ui
    if [[ $? == 0 ]]; then
        echo -e "${green}v2-ui Disable boot success${plain}"
    else
        echo -e "${red}v2-ui unboot failed${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    echo && echo -n -e "The panel may output many WARNING logs during use, if there is nothing wrong with the panel, then there is no problem, press Enter to continue: " && read temp
    tail -500f /etc/v2-ui/v2-ui.log
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    # bash <(curl -L -s https://raw.githubusercontent.com/sprov065/blog/master/bbr.sh)
    bash <(curl -L -s https://raw.githubusercontent.com/0akl3af/BBR/master/bbr.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Install bbr successfully${plain}"
    else
        echo ""
        echo -e "${red}Downloading bbr installation script failed, please check if your local machine can connect to Github${plain}"
    fi

    before_show_menu
}

update_shell() {
    # wget -O /usr/bin/v2-ui -N --no-check-certificate https://github.com/sprov065/v2-ui/raw/master/v2-ui.sh
    wget -O /usr/bin/v2-ui -N --no-check-certificate https://raw.githubusercontent.com/0akl3af/v2-ui/master/v2-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Download script failed, please check if you can connect to Github on your local computer${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/v2-ui
        echo -e "${green}Upgrade script successfully, please re-run the script${plain}" && exit 0
    fi
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
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Panel is already installed, please do not repeat the installation${plain}"
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
        echo -e "${red}Please install the panel first${plain}"
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
            echo -e "Panel Status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Panel Status: ${yellow}Not running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Panel Status: ${red}Not installed${plain}"
    esac
    show_v2ray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Whether to boot up or not: ${green}Yes${plain}"
    else
        echo -e "Whether to boot up or not: ${red}No${plain}"
    fi
}

check_v2ray_status() {
    count=$(ps -ef | grep "v2ray-v2-ui" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_v2ray_status() {
    check_v2ray_status
    if [[ $? == 0 ]]; then
        echo -e "v2ray Status: ${green}Run${plain}"
    else
        echo -e "v2ray Status: ${red}Not running${plain}"
    fi
}

show_usage() {
    echo "How to use v2-ui administration script: "
    echo "------------------------------------------"
    echo "v2-ui              - Show Admin Menu (more functions)"
    echo "v2-ui start        - Launch v2-ui Panel"
    echo "v2-ui stop         - Stop v2-ui Panel"
    echo "v2-ui restart      - Restart v2-ui panel"
    echo "v2-ui status       - View v2-ui Status"
    echo "v2-ui enable       - Set v2-ui to boot up automatically"
    echo "v2-ui disable      - Cancel v2-ui boot-up"
    echo "v2-ui log          - View v2-ui logs"
    echo "v2-ui update       - Update v2-ui Panel"
    echo "v2-ui install      - Installing the v2-ui Panel"
    echo "v2-ui uninstall    - Uninstall v2-ui Panel"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}v2-ui Panel Management Script${plain}
--- https://blog.sprov.xyz/v2-ui ---
  ${green}0.${plain} Exit Script
————————————————
  ${green}1.${plain} Install v2-ui
  ${green}2.${plain} Update v2-ui
  ${green}3.${plain} Uninstall v2-ui
————————————————
  ${green}4.${plain} Reset username password
  ${green}5.${plain} Reset Panel Settings
  ${green}6.${plain} Setting the panel port
————————————————
  ${green}7.${plain} Start v2-ui
  ${green}8.${plain} Stop v2-ui
  ${green}9.${plain} Restart v2-ui
 ${green}10.${plain} View v2-ui Status
 ${green}11.${plain} View v2-ui Logs
————————————————
 ${green}12.${plain} Set v2-ui to boot up automatically
 ${green}13.${plain} Cancel v2-ui boot-up
————————————————
 ${green}14.${plain} One-click installation of bbr (latest kernel)
 "
    show_status
    echo && read -p "Please enter your choice [0-14]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && reset_user
        ;;
        5) check_install && reset_config
        ;;
        6) check_install && set_port
        ;;
        7) check_install && start
        ;;
        8) check_install && stop
        ;;
        9) check_install && restart
        ;;
        10) check_install && status
        ;;
        11) check_install && show_log
        ;;
        12) check_install && enable
        ;;
        13) check_install && disable
        ;;
        14) install_bbr
        ;;
        *) echo -e "${red}Please enter the correct number [0-14]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi
