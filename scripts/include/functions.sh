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
  
  while true; do
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
    else
	  eval "$response_var='${devices[$choice]}'"
	  echo "${devices[$choice]}"
	  return 0
    fi
  done
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
  
  sudo wipefs -a ${disk} -f
  sudo wipefs --all -t btrfs ${disk} -f
  sudo dd if=/dev/zero of=${disk} bs=4M count=1
  echo -e "g\nn\n1\n\n+512M\nn\n2\n\n\nt\n1\n1\nw\n" | sudo fdisk -w always -W always ${disk}
  return 0
}

format_partitions() {
  local efipart="$1"
  local rootpart="$2"

  sudo mkfs.fat -F32 ${efipart}
  sudo mkfs.btrfs -f ${rootpart}
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
  
  cmd_inst="zypper -v -n"
  if "$installroot"; then cmd_inst="$cmd_inst --installroot /mnt"; fi
  cmd_inst="$cmd_inst --gpg-auto-import-keys install --download-in-advance -l -y"
  if "$norecommends"; then cmd_inst="$cmd_inst --no-recommends"; fi
  if "$ispattern"; then cmd_inst="$cmd_inst -t pattern"; fi

  cmd_chk="zypper -v -n"
  if "$installroot"; then cmd_chk="$cmd_chk --installroot /mnt"; fi
  cmd_chk="$cmd_chk se --match-exact -i"
    
  if sudo $cmd_chk "$pkg" &>> /dev/null ; then
    echo -e "${OK} $pkg is already installed. Skipping..."
  else
    echo -e "${NOTE} Installing $pkg ..."
    sudo $cmd_inst "$pkg"
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
    opi
	grub2-x86_64-efi
	kernel-default
    btrfsprogs
    xfsprogs
    zypper
	systemd-coredump
	systemd-network
	systemd-portable
	system-group-wheel
	system-user-mail
	vim
	rng-tools
	lvm2
	ntfs-3g
	mdadm
	cifs-utils
	rpcbind
	nvme-cli
	nvme-cli-bash-completion
	nvme-cli-zsh-completion
	openssh
	biosdevname
	dbus-broker
    util-linux
    nano
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
	shadow
  )
  
  for p in "${pkgs[@]}"; do
    install_package "$p" false true true
  done
  return 0
}

mount_additional_dirs() {
  for dir in sys dev proc run; do sudo mount --rbind /$dir /mnt/$dir/ && sudo mount --make-rslave /mnt/$dir; done
}

setup_etc() {
  sudo rm /mnt/etc/resolv.conf 2>/dev/null
  sudo cp /etc/resolv.conf /mnt/etc/
}

setup_firstboot() {
  sudo systemd-firstboot --root=/mnt \
    --keymap="de-latin1" \
    --locale-messages="de_DE.UTF-8" \
    --timezone="Europe/Berlin" \
    --hostname="zero" \
    --locale="de_DE.UTF-8" \
    --setup-machine-id \
    --welcome=false
}

setup_fstab() {
  local efipart="$1"
  local rootpart="$2"

  rootpart_uuid="$(sudo blkid -o value -s UUID ${rootpart})"
  efipart_uuid="$(sudo blkid -o value -s UUID ${efipart})"
  sudo tee /mnt/etc/fstab <<EOF
UUID=$efipart_uuid   /boot             vfat   rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro  0  2
UUID=$rootpart_uuid  /                 btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@           0  0
UUID=$rootpart_uuid  /home             btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home       0  0
UUID=$rootpart_uuid  /.snapshots       btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@snapshots  0  0
UUID=$rootpart_uuid  /.swap            btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@swap       0  0

tmpfs            /tmp              tmpfs  rw,nosuid,nodev,inode64  0  0
/.swap/swapfile  none              swap   defaults                 0  0
EOF
}

setup_grub_config() {
  KERNEL="$(sudo ls /mnt/lib/modules)"
  sudo sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="splash=verbose loglevel=3"/' /mnt/etc/default/grub
  sudo sed -i -e 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=4/' /mnt/etc/default/grub
  sudo bash -c 'echo "GRUB_DISABLE_OS_PROBER=false" >> /mnt/etc/default/grub'
}

setup_grub() {
  local disk="$1"

  sudo chroot /mnt /bin/bash << EOF
dracut --regenerate-all --force
grub2-install $disk
grub2-mkconfig -o /boot/grub2/grub.cfg
shim-install --config-file=/boot/grub2/grub.cfg
efibootmgr
echo ':wq' | visudo 2>/dev/null
sed -i -e 's/^#.*%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo 'Defaults !targetpw' >/etc/sudoers.d/userpw
EOF
}

setup_root_user() {
  sudo chroot /mnt /bin/bash << EOF
echo 'Setting root passphrase ...'
echo 'root:root' | chpasswd
EOF
}

setup_common_services() {
  sudo chroot /mnt /bin/bash << EOF
echo 'Enabling services ...'
systemctl enable sshd
systemctl enable NetworkManager
EOF
}

setup_locale_de() {
  sudo chroot /mnt /bin/bash << EOF
echo 'Setting locale ...'
zypper -v -n addlocale de_DE
localectl set-locale LANG=de_DE.UTF-8
EOF
}

setup_system_user() {
  local sys_user="$1"
  
  sudo chroot /mnt /bin/bash << EOF
echo 'Add user ...'
useradd ${sys_user} -m
echo "$sys_user:$sys_user" | chpasswd
usermod -a -G wheel $sys_user
EOF
}

finish_script() {
  sudo swapoff /mnt/.swap/swapfile
  sudo umount -R /mnt
  echo "${GREEN}Finished.$(tput sgr0)"; echo
}

reboot_system() {
  echo "${GREEN}Rebooting after <ENTER>.$(tput sgr0)"; echo
  press_enter_and_continue
  sudo reboot
}

setup_desktop_zypper_repos() {
  printf "\n%s - Adding additional repository (Globally) for desktop use... \n" "${NOTE}"
  sudo zypper -n --quiet ar --refresh -Gfp 70 https://ftp.fau.de/packman/suse/openSUSE_Tumbleweed/ packman
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.nvidia.com/opensuse/tumbleweed/ Nvidia
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/Emulators:/Wine/openSUSE_Tumbleweed/Emulators:Wine.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/filesystems/openSUSE_Tumbleweed/filesystems.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/graphics/openSUSE_Tumbleweed/graphics.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/home:/ahjolinna/openSUSE_Tumbleweed/home:ahjolinna.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/home:/ithod:/signal/openSUSE_Tumbleweed/home:ithod:signal.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/home:/nuklly/openSUSE_Tumbleweed/home:nuklly.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/home:/strycore/openSUSE_Tumbleweed/ Lutris
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/multimedia:/apps/openSUSE_Tumbleweed/multimedia:apps.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://download.opensuse.org/repositories/multimedia:/libs/openSUSE_Tumbleweed/multimedia:libs.repo
  sudo zypper -n --quiet ar --refresh -Gfp 80 https://packages.microsoft.com/yumrepos/vscode vscode
  sudo zypper -n --quiet ar --refresh -Gfp 80 obs://network:vpn:wireguard wireguard
  sudo zypper --gpg-auto-import-keys ref -f
  sudo zypper -n dup --from packman --allow-vendor-change
}

install_hypr_dependencies() {
  printf "\n%s - Installing dependencies... \n" "${NOTE}"
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
