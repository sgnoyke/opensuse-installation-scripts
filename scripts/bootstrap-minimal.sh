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
SYS_USER=""
Q="N"
EFI_PARTITION=""
ROOT_PARTITION=""

# functions

# main part
ask_installation_device DISK; echo
ask_custom_input "Enter a user name (sudo system user)" SYS_USER; echo

get_partition_names ${DISK} EFI_PARTITION ROOT_PARTITION

ask_yes_no "ATTENTION: ${DISK} will be wiped"  Q; echo
if [ "${Q}" != "Y" ]; then echo "${WARN} Installation aborted."; return -1; fi; echo

wipe_disk ${DISK}

# .. format_partitions
sudo mkfs.fat -F32 ${EFI_PARTITION}
sudo mkfs.btrfs ${ROOT_PARTITION}

# .. setup_subvolumes
sudo mount ${ROOT_PARTITION} /mnt
sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@snapshots
sudo btrfs subvolume create /mnt/@swap
sudo umount /mnt

# .. mount_partitions
sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@ ${ROOT_PARTITION} /mnt
sudo mkdir -p /mnt/{home,.snapshots,.swap,boot/efi}
sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@home ${ROOT_PARTITION} /mnt/home
sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@snapshots ${ROOT_PARTITION} /mnt/.snapshots
sudo mount -t btrfs -o rw,noatime,ssd,discard=async,space_cache=v2,compress=zstd,subvol=@swap ${ROOT_PARTITION} /mnt/.swap
sudo mount ${EFI_PARTITION} /mnt/boot/efi

# .. setup_swapfile
TOTAL_MEM="$(awk '/MemTotal/ {printf( "%d\n", $2 / 1024 )}' /proc/meminfo)"
SWAPFILE_SIZE="$((${TOTAL_MEM} + 2048))"
sudo chattr +C /mnt/.swap/
sudo truncate -s 0 /mnt/.swap/swapfile
sudo dd if=/dev/zero of=/mnt/.swap/swapfile bs=1M count=${SWAPFILE_SIZE} status=progress
sudo chmod 600 /mnt/.swap/swapfile
sudo mkswap /mnt/.swap/swapfile
sudo swapon /mnt/.swap/swapfile

# .. setup_default_subvolume
sudo btrfs subvolume set-default $(sudo btrfs subvolume list /mnt | sudo grep "@snapshots" | sudo grep -oP '(?<=ID )[0-9]+') /mnt

# .. setup_default_repos
sudo zypper --root /mnt ar -Gfp 99 --refresh https://download.opensuse.org/tumbleweed/repo/non-oss/ tumbleweed-non-oss
sudo zypper --root /mnt ar -Gfp 99 --refresh https://download.opensuse.org/tumbleweed/repo/oss/ tumbleweed-oss
sudo zypper --root /mnt ar -Gfp 99 --refresh https://download.opensuse.org/update/tumbleweed/ tumbleweed-updates
sudo zypper --gpg-auto-import-keys --root /mnt ref -f

# .. install_common_software
sudo zypper -v -n --installroot /mnt --gpg-auto-import-keys install --download-in-advance -l -y --no-recommends \
  btrfsprogs \
  xfsprogs \
  kernel-default \
  grub2-x86_64-efi \
  zypper \
  nano \
  shadow \
  util-linux \
  wicked iputils \
  openssh-server \
  dmraid \
  ca-certificates-mozilla \
  ca-certificates \
  ca-certificates-cacert \
  lsof \
  shim \
  git \
  NetworkManager \
  aaa_base \
  aaa_base-extras \
  iproute2 \
  net-tools \
  procps less \
  psmisc \
  timezone \
  curl \
  sudo \
  zip \
  unzip \
  openssl \
  pciutils \
  usbutils \
  zsh \
  tmux \
  iptables \
  nftables \
  tcpdump \
  xz \
  7zip \
  sops \
  jq \
  hwdata \
  psmisc \
  opi

# .. setup_additionals_dirs
for dir in sys dev proc run; do sudo mount --rbind /$dir /mnt/$dir/ && sudo mount --make-rslave /mnt/$dir; done
sudo rm /mnt/etc/resolv.conf 2>/dev/null

# .. setup_etc
sudo cp /etc/resolv.conf /mnt/etc/

# .. setup_firstboot
sudo systemd-firstboot --root=/mnt \
  --keymap="de-latin1" \
  --locale-messages="de_DE.UTF-8" \
  --timezone="Europe/Berlin" \
  --hostname="susedev" \
  --locale=de_DE.UTF-8 \
  --setup-machine-id \
  --welcome=false

# .. setup_fstab
ROOT_UUID="$(sudo blkid -o value -s UUID ${ROOT_PARTITION})"
EFI_UUID="$(sudo blkid -o value -s UUID ${EFI_PARTITION})"
sudo tee /mnt/etc/fstab <<EOF
UUID=$EFI_UUID   /boot             vfat   rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro  0  2
UUID=$ROOT_UUID  /                 btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@           0  0
UUID=$ROOT_UUID  /home             btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home       0  0
UUID=$ROOT_UUID  /.snapshots       btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@snapshots  0  0
UUID=$ROOT_UUID  /.swap            btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@swap       0  0

tmpfs            /tmp              tmpfs  rw,nosuid,nodev,inode64  0  0
/.swap/swapfile  none              swap   defaults                 0  0
EOF

# .. setup_grub_config
KERNEL="$(sudo ls /mnt/lib/modules)"
sudo sed -i -e 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="splash=verbose loglevel=3"/' /mnt/etc/default/grub
sudo sed -i -e 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=4/' /mnt/etc/default/grub
sudo bash -c 'echo "GRUB_DISABLE_OS_PROBER=false" >> /mnt/etc/default/grub'

# .. setup_grub
sudo chroot /mnt <<EOS
dracut --regenerate-all --force
grub2-install $DISK
grub2-mkconfig -o /boot/grub2/grub.cfg
shim-install --config-file=/boot/grub2/grub.cfg
efibootmgr
EOS

# .. setup_root_user
sudo chroot /mnt <<EOS
echo 'Setting root passphrase ...'
echo 'root:root' | chpasswd
EOS

# .. setup_services
sudo chroot /mnt <<EOS
echo 'Enabling services ...'
systemctl enable sshd
systemctl enable NetworkManager
EOS

# .. setup_locale
sudo chroot /mnt <<EOS
echo 'Setting locale ...'
zypper -v -n addlocale de_DE
localectl set-locale LANG=de_DE.UTF-8
EOS

# .. setup_system_user
sudo chroot /mnt <<EOS
echo 'Add user ...'
useradd ${SYS_USER} -m
echo "$SYS_USER:$SYS_USER" | chpasswd
adduser ${SYS_USER} sudo
EOS

# .. finish_script
sudo swapoff /mnt/.swap/swapfile
sudo umount -R /mnt
echo "${GREEN}Installation finished.$(tput sgr0)"; echo

# .. reboot_system
echo "${GREEN}Rebooting after <ENTER>.$(tput sgr0)"; echo
press_enter_and_continue
sudo reboot
