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

# main part
ask_installation_device DISK; echo
ask_custom_input "Enter a user name (sudo system user)" SYS_USER; echo

get_partition_names ${DISK} EFI_PARTITION ROOT_PARTITION

ask_yes_no "ATTENTION: ${DISK} will be wiped" Q; echo
if [ "${Q}" != "Y" ]; then echo "${WARN} Installation aborted."; return -1; fi; echo

wipe_disk ${DISK}
format_partitions ${EFI_PARTITION} ${ROOT_PARTITION}
setup_subvolumes ${ROOT_PARTITION}
mount_partitions ${EFI_PARTITION} ${ROOT_PARTITION}
setup_swapfile
setup_default_subvolume
setup_default_zypper_repos
installroot_base_packages


# .. mount_additional_dirs
for dir in sys dev proc run; do sudo mount --rbind /$dir /mnt/$dir/ && sudo mount --make-rslave /mnt/$dir; done

# .. setup_etc
sudo rm /mnt/etc/resolv.conf 2>/dev/null
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
