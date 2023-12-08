#!/usr/bin/env bash

OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
WARN="$(tput setaf 166)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
ORANGE=$(tput setaf 166)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

colorize_prompt() {
    local color="$1"
    local message="$2"
    echo -n "${color}${message}$(tput sgr0)"
}

ask_yes_no() {
    local response
    while true; do
        read -p "$(colorize_prompt "$CAT" "$1 (Y/N): ")" -r response
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
        read -p "$(colorize_prompt "$CAT"  "$prompt ($valid_options): ")" choice
        if [[ " $valid_options " == *" $choice "* ]]; then
            eval "$response_var='$choice'"
            return 0
        else
            echo "Please choose one of the provided options: $valid_options"
        fi
    done
}

source_script() {
    local script="$1"
	source <(curl -s https://raw.githubusercontent.com/sgnoyke/opensuse-installation-scripts/main/${script})
}

execute_script() {
    local script="$1"
	bash <(curl -s https://raw.githubusercontent.com/sgnoyke/opensuse-installation-scripts/main/${script})
}

countdown() {
    secs=$1
    shift
    msg=$@
    while [ $secs -gt 0 ]
    do
        printf "\r\033[K${NOTE}$msg in %.d seconds" $((secs--))
        sleep 1
    done
}

quit(){
    echo -e "${NOTE}Quiting ..."
    echo "Bye"
    exit;
}
