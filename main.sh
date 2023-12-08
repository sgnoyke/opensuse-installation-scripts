#!/usr/bin/env bash

source <(curl -s https://raw.githubusercontent.com/sgnoyke/opensuse-installation-scripts/main/scripts/include/functions.sh)

menu=( bootstrap configs )
bootstrap=( minimal minimal-server minimal-laptop minimal-desktop )
configs=( repos-dev repos-full adduser )

displayInfo(){
    echo -e "${IGreen}"
    echo "----------------------------------"
    echo "     Distribution Information     "
    echo "----------------------------------"
    echo ""
    
    if [[ $1 -eq 0 ]]
    then
        cat $2
    else
        $2
    fi
    
    echo -e "${RESET}"
    read -p "Press enter to continue"
    main_menu $3 ${menu[@]}
}

helpme(){
    case $1 in
        1)
            echo -e "${WARN}Your OS isn't supported yet."
            echo -e "${RESET}"
        ;;
        
        2)
            echo -e "${WARN}Sorry! Couldn't recognize your OS."
            echo -e "${RESET}"
        ;;
        
        3)
            echo -e "${WARN}This installation isn't supported yet."
            echo -e "${RESET}"
        ;;
        
        4)
            echo -e "${WARN}Something went wrong."
            echo -e "${RESET}"
        ;;
        
        *) echo "Wow! You have reached a new milestone."
    esac
}

start(){
    echo ""
    echo -e "${NOTE} Installing $1 for $2 ${Reset}"
    echo ""
}

check(){
    echo ""
    if [ $1 -eq 0 ]; then
        echo -e "${OK}Installation complete."
    else
        echo -e "${ERROR}Installation failed!"
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
            echo -e "${NOTE}$i) ${NOTE}${array[$i]^}"
        done
        echo -e "${NOTE}.) ${NOTE}Back"
        echo -e "${NOTE}q) ${NOTE}Quit"
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
            echo -e "${NOTE}$i) ${NOTE}${array[$i]^}"
        done
        echo -e "${NOTE}q) ${NOTE}Quit"
        read -r -p "Enter your choice [1-$(($total - 1))] : " input
        if [[ "$input" -ge 1 && "$input" -lt $total ]] ; then sub=${array[$input]}[@]; sub_menu ${array[0]} ${!sub};
            elif [[ $input = "q" ]] || [[ $input = "Q" ]] ; then quit
        else clear ;
        fi
        
    done
}

echo -e "${CAT}"
echo " ======================================================== "
echo " |                                                      | "
echo " |          OpenSUSE Installation Script v 0.1          | "
echo " |                                                      | "
echo " ======================================================== "
echo ""
echo -e "${NOTE}https://github.com/sgnoyke/opensuse-installation-scripts"
echo ""
echo -e "${NOTE}Detecting System Configuration${Reset}"
echo ""

if [ $EUID -eq 0 ]; then; echo "This script should not be executed as root! Exiting..."; exit 1; fi

os=$(which zypper 1>/dev/null 2>/dev/null && echo "openSUSE")
if [ $? -eq 0 ]; then displayInfo 0 $( if [ -f /etc/SuSE-release ]; then echo /etc/SuSE-release; else echo /etc/os-release; fi) suse; else helpme 2; fi