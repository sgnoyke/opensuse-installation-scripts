#!/usr/bin/env bash

if [ $EUID -eq 0 ]; then echo -e "${ERROR} This script should not be executed as root! Exiting ..."; exit 1; fi

echo
echo "${GREEN}Welcome to OpenSUSE (Tumbleweed) - Setup Hyprland Script!$(tput sgr0)"
echo

read -p "${BLUE}Would you like to proceed? (y/n): $(tput sgr0)" proceed

if [ "$proceed" != "y" ]; then echo "${WARN} Installation aborted."; return -1; fi; echo

# variables
Q_NVIDIA="N"
Q_BLUETOOTH="N"
Q_SDDM="N"

# main part
ask_yes_no "-Do you have nvidia gpu?" Q_NVIDIA; echo
ask_yes_no "-Do you want to configure Bluetooth?" Q_BLUETOOTH; echo
ask_yes_no "-Install and configure SDDM log-in Manager?" Q_SDDM; echo

#execute_script "00-packman.sh"
#execute_script "01-dependencies.sh"
#execute_script "02-hypr-pkgs.sh"
#execute_script "fonts.sh"
#execute_script "nwg-look.sh"
#execute_script "swaylock-effects.sh"
#execute_script "cliphist.sh"
#execute_script "wlogout.sh"

#setup_desktop_zypper_repos
#install_hypr_dependencies
