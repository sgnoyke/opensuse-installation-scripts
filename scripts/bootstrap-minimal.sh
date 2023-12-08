#!/usr/bin/env bash

if [ $EUID -eq 0 ]; then echo -e "${ERROR} This script should not be executed as root! Exiting ..."; exit 1; fi

echo
echo "${GREEN}Welcome to OpenSUSE (Tumbleweed) - Minimal Bootstrap Script!$(tput sgr0)"
echo
echo "${WARN} ATTENTION: All data on hardrive will be wiped!! $(tput sgr0)"
echo

read -p "${BLUE}Would you like to proceed? (y/n): $(tput sgr0)" proceed

if [ "$proceed" != "y" ]; then echo "${WARN} Installation aborted."; return -1; fi

# functions
function select_installation_device {
  echo "${NOTE} Available devices in /dev/:"
  devices=($(lsblk -rno NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}'))

  if [ ${#devices[@]} -eq 0 ]; then
    echo "${WARN} No devices found."
    exit 1
  fi
  
  for ((i=0; i<${#devices[@]}; i++)); do
    echo "$i: ${devices[$i]}"
  done

  read -p "$(colorize_prompt "$CAT"  "Choose a device (enter a number): ")" choice

  if [[ ! $choice =~ ^[0-9]+$ ]] || ((choice < 0)) || ((choice >= ${#devices[@]})); then
    echo "${WARN} Not valid number. Please choose a valid number."
    select_installation_device
  else
    selected_device=${devices[$choice]}
    echo "$selected_device"
  fi
}

# main part
selected_device=$(select_installation_device)



echo $selected_device




















return 0