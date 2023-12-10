#!/usr/bin/env bash

if [ $EUID -eq 0 ]; then echo -e "${ERROR} This script should not be executed as root! Exiting ..."; exit 1; fi

echo
echo "${GREEN}Welcome to OpenSUSE (Tumbleweed) - Setup ZSH Script!$(tput sgr0)"
echo

read -p "${BLUE}Would you like to proceed? (y/n): $(tput sgr0)" proceed

if [ "$proceed" != "y" ]; then echo "${WARN} Installation aborted."; return -1; fi; echo

# variables
Q_OHMYZSH="N"

# functions
install_zsh_packages() {
  printf "\n%s - Installing zsh packages... \n" "${NOTE}"
  pkgs_extras=(
  )
  
  pkgs=(
    wget
    zsh
  )
  
  for p in "${pkgs[@]}" "${pkgs_extras[@]}"; do
    install_package "$p" false false false
  done
  return 0
}

install_ohmyzsh_packages() {
  printf "\n%s - Installing oh-my-zsh packages... \n" "${NOTE}"
  sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  return 0
}

# main part
ask_yes_no "-Would you like to install oh-my-zsh?" Q_OHMYZSH; echo

install_zsh_packages
[ "$Q_OHMYZSH" == "Y" ] && install_ohmyzsh_packages

finish_script
press_enter_and_continue
