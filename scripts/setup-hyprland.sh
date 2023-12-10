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

# functions
install_hypr_dependencies() {
  printf "\n%s - Installing basic dependencies... \n" "${NOTE}"
  pkgs=(
    devel_basis
  )
  
  opi_pkgs=(
    opi
	go
  )
  
  for p in "${pkgs[@]}"; do
    install_package "$p" true false false
  done
  for p in "${opi_pkgs[@]}"; do
    install_package "$p" false false false
  done
  return 0
}

install_hypr_packages() {
  printf "\n%s - Installing hyprland packages... \n" "${NOTE}"
  pkgs_extras=(
  )
  
  pkgs=(
    curl
    dunst
    git
    go
    grim
    gvfs
    gvfs-backends
    ImageMagick
    jq
    kitty
    kvantum-qt6
    kvantum-themes
    kvantum-manager
    libnotify-tools
    nano
    openssl
    pamixer
    pavucontrol
    playerctl  
    polkit-gnome
    python311-requests
    python311-pip
    python311-pywal
    qt5ct
    qt6ct
    qt6-svg
    rofi-wayland
    slurp
    swappy
    swayidle
    swww
    wget
    wayland-protocols-devel
    wl-clipboard
    xdg-user-dirs
    xwayland
    brightnessctl
    btop
    cava
    mousepad
    mpv
    mpv-mpris
    nvtop
    vim
    wlsunset
    yad
  )
  
  pkgs_no_recommends=(
    waybar
    eog
    gnome-system-monitor
    NetworkManager-applet
  )
  
  for p in "${pkgs[@]}" "${pkgs_extras[@]}"; do
    install_package "$p" false false false
  done
  for p in "${pkgs_no_recommends[@]}"; do
    install_package "$p" false false true
  done
  return 0
}

# main part
ask_yes_no "-Do you have nvidia gpu?" Q_NVIDIA; echo
ask_yes_no "-Do you want to configure Bluetooth?" Q_BLUETOOTH; echo
ask_yes_no "-Install and configure SDDM log-in Manager?" Q_SDDM; echo

#execute_script "fonts.sh"
#execute_script "nwg-look.sh"
#execute_script "swaylock-effects.sh"
#execute_script "cliphist.sh"
#execute_script "wlogout.sh"

setup_desktop_zypper_repos
install_hypr_dependencies
install_hypr_packages
xdg-user-dirs-update 
finish_script
press_enter_and_continue