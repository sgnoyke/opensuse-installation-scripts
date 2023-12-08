#!/usr/bin/env bash

if [ $EUID -eq 0 ]; then echo "This script should not be executed as root! Exiting..."; exit 1; fi

# Welcome message
echo "$(tput setaf 6)Welcome to OpenSUSE (Tumbleweed) - Minimal Bootstrap Script!$(tput sgr0)"
echo
echo "$(tput setaf 166)ATTENTION: All data on hardrive will be wiped!! $(tput sgr0)"
echo

read -p "$(tput setaf 6)Would you like to proceed? (y/n): $(tput sgr0)" proceed

if [ "$proceed" != "y" ]; then echo "Installation aborted."; exit 1; fi
