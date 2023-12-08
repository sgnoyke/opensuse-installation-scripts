#!/usr/bin/env bash

if [ $EUID -eq 0 ]; then echo -e "${ERROR} This script should not be executed as root! Exiting ..."; exit 1; fi

echo
echo "${GREEN}Welcome to OpenSUSE (Tumbleweed) - Minimal Bootstrap Script!$(tput sgr0)"
echo
echo "${WARN} ATTENTION: All data on hardrive will be wiped!! $(tput sgr0)"
echo

read -p "${BLUE}Would you like to proceed? (y/n): $(tput sgr0)" proceed

if [ "$proceed" != "y" ]; then echo "${WARN} Installation aborted."; return -1; fi; echo

# variables
DISK=""
USER=""

# functions

# main part
select_installation_device DISK
ask_custom_input "Enter a user name (sudo system user)" USER


echo "$DISK $USER"






press_enter_and_continue





















return 0