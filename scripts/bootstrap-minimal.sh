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
mount_additional_dirs
setup_etc
setup_firstboot
setup_fstab ${EFI_PARTITION} ${ROOT_PARTITION}
exit 1
setup_grub_config
setup_grub ${DISK}
setup_root_user
setup_common_services
setup_locale_de
setup_system_user ${SYS_USER}
finish_script
reboot_system
