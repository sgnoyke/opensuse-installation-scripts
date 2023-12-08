#!/usr/bin/env bash

OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
WARN="$(tput setaf 5)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
ORANGE=$(tput setaf 166)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
BLUE=$(tput setaf 6)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

colorize_prompt() {
    local color="$1"
    local message="$2"
    echo -n "${color}${message}$(tput sgr0)"
}

press_enter_and_continue() {
	read -p "${RESET}Press enter to continue"
}

ask_yes_no() {
    local response
    while true; do
        read -p "$(colorize_prompt "$CAT " "$1 (Y/N): ")" -r response
        case "$response" in
            [Yy]* ) eval "$2='Y'"; return 0;;
            [Nn]* ) eval "$2='N'"; return 1;;
            * ) echo "Please answer with Y/y or N/n.";;
        esac
    done
}

ask_custom_option() {
    local prompt="$1"
    local valid_options="$2"
    local response_var="$3"

    while true; do
        read -p "$(colorize_prompt "$CAT "  "$prompt ($valid_options): ")" choice
        if [[ " $valid_options " == *" $choice "* ]]; then
            eval "$response_var='$choice'"
			echo "$choice"
            return 0
        else
            echo "Please choose one of the provided options: $valid_options"
        fi
    done
}

ask_custom_input() {
    local prompt="$1"
    local response_var="$2"

    while true; do
        read -p "$(colorize_prompt "$CAT "  "$prompt: ")" choice
		if [[ ! -z "$choice" ]]; then
		  eval "$response_var='$choice'"
		  return 0
        fi
		echo
    done
}

source_script() {
    local script="$1"
	source <(curl -H 'Cache-Control: no-cache' -s https://raw.githubusercontent.com/sgnoyke/opensuse-installation-scripts/main/${script})
}

countdown() {
    secs=$1
    shift
    msg=$@
    while [ $secs -gt 0 ]
    do
        printf "\r\033[K${NOTE} $msg in %.d seconds" $((secs--))
        sleep 1
    done
}

quit(){
    echo -e "${NOTE} Quiting ..."
    echo "Bye"
    exit;
}

ask_installation_device() {
  local response_var="$1"
  
  echo "${NOTE} Available devices in /dev/:"
  devices=($(lsblk -rno NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}'))

  if [ ${#devices[@]} -eq 0 ]; then
    echo "${WARN} No devices found."
    exit 1
  fi
  
  for ((i=0; i<${#devices[@]}; i++)); do
    echo "$i: ${devices[$i]}"
  done

  read -p "$(colorize_prompt "$CAT "  "Choose a device (enter a number): ")" choice

  if [[ ! $choice =~ ^[0-9]+$ ]] || ((choice < 0)) || ((choice >= ${#devices[@]})); then
    echo "${WARN} Not valid number. Please choose a valid number."; echo
    ask_installation_device
  else
	eval "$response_var='${devices[$choice]}'"
	echo "${devices[$choice]}"
	return 0
  fi
}

get_partition_names() {
  local disk="$1"
  local response_efi_var="$2"
  local response_root_var="$3"
  
  efipart="${disk}1"
  rootpart="${disk}2"
  [[ ${disk} =~ "nvme" ]] && efipart="${disk}p1" && rootpart="${disk}p2"
  eval "$response_efi_var='${efipart}'"
  eval "$response_root_var='${rootpart}'"
  return 0
}

wipe_disk() {
  local disk="$1"
  
  sudo wipefs -a ${disk}
  sudo dd if=/dev/zero of=${disk} bs=446 count=1
  echo -e "g\nn\n1\n\n+512M\nn\n2\n\n\nt\n1\n1\nw\n" | sudo fdisk -w always -W always ${disk}
  return 0
}

format_partitions() {
  local efipart="$1"
  local rootpart="$2"

  sudo mkfs.fat -F32 ${efipart}
  sudo mkfs.btrfs ${rootpart}
  return 0
}

setup_subvolumes() {
  local rootpart="$1"

  sudo mount ${rootpart} /mnt
  sudo btrfs subvolume create /mnt/@
  sudo btrfs subvolume create /mnt/@home
  sudo btrfs subvolume create /mnt/@snapshots
  sudo btrfs subvolume create /mnt/@swap
  sudo umount /mnt  
  return 0
}

mount_partitions() {
  local efipart="$1"
  local rootpart="$2"

  sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@ ${rootpart} /mnt
  sudo mkdir -p /mnt/{home,.snapshots,.swap,boot/efi}
  sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@home ${rootpart} /mnt/home
  sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@snapshots ${rootpart} /mnt/.snapshots
  sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@swap ${rootpart} /mnt/.swap
  sudo mount ${efipart} /mnt/boot/efi
  return 0
}

setup_swapfile() {
  total_mem="$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)"
  swapfile_size="$((${total_mem} + 2048))"
  
  sudo chattr +C /mnt/.swap/
  sudo truncate -s 0 /mnt/.swap/swapfile
  sudo dd if=/dev/zero of=/mnt/.swap/swapfile bs=1M count=${swapfile_size} status=progress
  sudo chmod 600 /mnt/.swap/swapfile
  sudo mkswap /mnt/.swap/swapfile
  sudo swapon /mnt/.swap/swapfile
}

setup_default_subvolume() {
  sudo btrfs subvolume set-default $(sudo btrfs subvolume list /mnt | sudo grep "@snapshots" | sudo grep -oP '(?<=ID )[0-9]+') /mnt
}

setup_default_zypper_repos() {
  sudo zypper --root /mnt ar -Gfp 90 --refresh https://download.opensuse.org/update/tumbleweed/ tumbleweed-updates
  sudo zypper --root /mnt ar -Gfp 99 --refresh https://download.opensuse.org/tumbleweed/repo/non-oss/ tumbleweed-non-oss
  sudo zypper --root /mnt ar -Gfp 99 --refresh https://download.opensuse.org/tumbleweed/repo/oss/ tumbleweed-oss
  sudo zypper --gpg-auto-import-keys --root /mnt ref -f
}

install_package() {
  local pkg="$1"
  local ispattern="${2:-false}"
  local installroot="${3:-false}"
  local norecommends="${4:-false}"
  
  cmd="zypper -v -n"
  if "$installroot"; then cmd="$cmd --installroot /mnt"; fi
  cmd="$cmd --gpg-auto-import-keys install --download-in-advance -l -y"
  if "$norecommends"; then cmd="$cmd --no-recommends"; fi
  if "$ispattern"; then cmd="$cmd -t pattern"; fi
  
  if sudo zypper se -i "$pkg" &>> /dev/null ; then
    echo -e "${OK} $pkg is already installed. Skipping..."
  else
    echo -e "${NOTE} Installing $pkg ..."
    sudo $cmd "$pkg"
    if [ $? -eq 0 ] ; then
      echo -e "\e[1A\e[K${OK} $pkg was installed."
    else
      echo -e "\e[1A\e[K${ERROR} $pkg failed to install!"
    fi
  fi
}

installroot_base_packages() {
  printf "\n%s - Installing base packages... \n" "${NOTE}"
  pkgs=(
    btrfsprogs
    xfsprogs
    kernel-default
    grub2-x86_64-efi
    zypper
	opi
    nano
    shadow
    util-linux
    wicked
	iputils
    openssh-server
    dmraid
    ca-certificates-mozilla
    ca-certificates
    ca-certificates-cacert
    lsof
    shim
    git
    NetworkManager
    aaa_base
    aaa_base-extras
    iproute2
    net-tools
    procps
	less
    psmisc
    timezone
    curl
    sudo
    zip
    unzip
    openssl
    pciutils
    usbutils
    zsh
    tmux
    iptables
    nftables
    tcpdump
    xz
    7zip
    sops
    jq
    hwdata
    psmisc
  )
  
  for p in "${pkgs[@]}"; do
    install_package "$p" false true true
  done
  return 0
}
