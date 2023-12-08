#!/usr/bin/env bash

Reset='\033[0m'           # Text Reset

Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow
On_Blue='\033[44m'        # Blue
On_Purple='\033[45m'      # Purple
On_Cyan='\033[46m'        # Cyan
On_White='\033[47m'       # White

IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

On_IBlack='\033[0;100m'   # Black
On_IRed='\033[0;101m'     # Red
On_IGreen='\033[0;102m'   # Green
On_IYellow='\033[0;103m'  # Yellow
On_IBlue='\033[0;104m'    # Blue
On_IPurple='\033[0;105m'  # Purple
On_ICyan='\033[0;106m'    # Cyan
On_IWhite='\033[0;107m'   # White

LBlue='\033[36m'
LYellow='\033[33m'

menu=( bootstrap configs )
bootstrap=( minimal minimal-server minimal-laptop minimal-desktop )
configs=( repos-dev repos-full adduser )

progressbar() {
    local duration
    local columns
    local space_available
    local fit_to_screen
    local space_reserved
    
    space_reserved=6
    duration=20
    columns=$(tput cols)
    space_available=$(( columns-space_reserved ))
    
    if (( duration < space_available )); then
        fit_to_screen=1;
    else
        fit_to_screen=$(( duration / space_available ));
        fit_to_screen=$((fit_to_screen+1));
    fi
    
    already_done() { for ((done=0; done<(elapsed / fit_to_screen) ; done=done+1 )); do printf "▇"; done }
    remaining() { for (( remain=(elapsed/fit_to_screen) ; remain<(duration/fit_to_screen) ; remain=remain+1 )); do printf " "; done }
    percentage() { printf "| %s%%" $(( ((elapsed)*100)/(duration)*100/100 )); }
    clean_line() { printf "\r"; }
    
    for (( elapsed=1; elapsed<=duration; elapsed=elapsed+1 )); do
        already_done; remaining; percentage
        sleep 0.1
        clean_line
    done
    clean_line
}

countdown() {
    secs=$1
    shift
    msg=$@
    while [ $secs -gt 0 ]
    do
        printf "\r\033[K${IRed}$msg in %.d seconds" $((secs--))
        sleep 1
    done
}

quit(){
    echo -e "${BGreen}Please star this repo if you found this script usefull"
    echo -e "${BGreen}Quiting ..."
    echo "Bye"
    exit;
}

displayInfo(){
    echo -e "${IGreen}"
    echo "---------------------------------"
    echo "      Distro Information         "
    echo "---------------------------------"
    echo ""
    
    if [[ $1 -eq 0 ]]
    then
        cat $2
    else
        $2
    fi
    
    echo -e "${Reset}"
    countdown 3 Installation starting
    main_menu $3 ${menu[@]}
}

helpme(){
    case $1 in
        1)
            echo -e "${IRed}Your OS isn't supported yet."
            echo -e "${Reset}"
        ;;
        
        2)
            echo -e "${IRed}Sorry! Couldn't recognize your OS."
            echo -e "${Reset}"
        ;;
        
        3)
            echo -e "${IRed}This installation isn't supported yet."
            echo -e "${Reset}"
        ;;
        
        4)
            echo -e "${IRed}Something went wrong."
            echo -e "${Reset}"
        ;;
        
        *) echo "Wow! You have reached a new milestone."
    esac
}

start(){
    echo ""
    echo -e "${IGreen} Installing $1 for $2 ${Reset}"
    echo ""
}

check(){
    echo ""
    if [ $1 -eq 0 ]; then
        echo -e "${IGreen}Installation complete."
    else
        echo -e "${IRed}Installation failed!"
        echo "Some error occurred during installation or installation was aborted manually."
    fi
    echo ""
    sleep 3
}

suse(){
    start $1 "openSuSe"
    case $1 in
        minimal) helpme 3 ;;
        minimal-server) helpme 3 ;;
        minimal-laptop) helpme 3 ;;
        minimal-desktop) helpme 3 ;;
        repos-dev) helpme 3 ;;
        repos-full) helpme 3 ;;
        *) helpme 4
    esac
}

sub_menu(){
    array=("$@")
    total=${#array[*]}
    while :
    do
        
        clear
        
        for (( i=1; i<=$(( $total - 1 )); i++ ))
        do
            echo -e "${LYellow}$i) ${LBlue}${array[$i]^}"
        done
        echo -e "${Red}.) ${LBlue}Back"
        echo -e "${Red}q) ${LBlue}Quit"
        read -p "Enter your choice [1-$(($total - 1))] : " input
        
        for elem in ${input[@]}
        do
            if [[ "$elem" -ge 1 && "$elem" -lt $total ]] ; then ${array[0]} ${array[$elem]};
                elif [[ $elem = "q" ]] || [[ $elem = "Q" ]] ; then quit
                elif [[ $elem = "." ]] ; then main_menu ${array[0]} ${menu[@]}
            else clear ;
            fi
            
        done
        
    done
}

main_menu(){
    array=("$@")
    total=${#array[*]}
    while :
    do
        clear
        for (( i=1; i<=$(( $total - 1 )); i++ ))
        do
            echo -e "${LYellow}$i) ${LBlue}${array[$i]^}"
        done
        echo -e "${Red}q) ${LBlue}Quit"
        read -r -p "Enter your choice [1-$(($total - 1))] : " input
        if [[ "$input" -ge 1 && "$input" -lt $total ]] ; then sub=${array[$input]}[@]; sub_menu ${array[0]} ${!sub};
            elif [[ $input = "q" ]] || [[ $input = "Q" ]] ; then quit
        else clear ;
        fi
        
    done
}

echo -e "${ICyan}"
echo " ========================================================= "
echo " |                                                       | "
echo " |           Installation Script v 0.1                   | "
echo " |                                                       | "
echo " ========================================================= "
echo ""
echo -e "${UGreen}https://github.com/sgnoyke/opensuse-installation-scripts"
echo ""
echo -e "${BYellow}Detecting System Configuration${Reset}"
echo ""
progressbar
echo ""

os=$(which zypper 1>/dev/null 2>/dev/null && echo "openSUSE")
if [ $? -eq 0 ]; then displayInfo 0 $( if [ -f "/etc/SuSE-release" ]; then "/etc/SuSE-release"; else "/etc/os-release"; fi) suse; else helpme 2; fi