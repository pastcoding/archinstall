#!/bin/bash

# Dieses Script dient dazu, sowohl ein Base System zu installieren,
# als auch im spateren Live System ein DE oder einen WM zu installieren.
# Selbstverstaendlich uebernimmt das Script auch die Installation von einigen, 
# vor allem fuer mich relevanten Apps (zu diesen kommen wir noch)

# Das Script ist in mehrere Teile aufgeteilt - jedoch wird immer ueber das "install.sh" gearbeitet.
# Dieses wird dann entsprechend die jeweils anderen aufrufen.

# Es wird als Filesystem EXT4 verwendet (99% der User kommen damit komplett aus)
# SWAP Partition + Hibernation ist optional
# SWAP File + Hibernation wird spaeter implementiert

# Ein paar Variablen werden in Files geschrieben und anschliessend wieder geloescht.
# Grund, so kann ich ein und die selbe Varaible in den unterschiedlichen Teilen verwenden.

# Pre-Base Install Varaiblen
CPU_VENDOR=""
HARDDRIVES=""
SWAP=""
RAM_SIZE=""
SWAP_SIZE=""

# Check ob wir uns im Installations ISO befinden, oder im Live System
get_session_type(){
    if cat /proc/cmdline | grep -q "archiso"; then
        echo "install" > env
    else
        echo "live" > env
    fi
}

# Check welche CPU verbaut ist im System
get_cpu_vendor(){
    VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
    if [ "$VENDOR" == "GenuineIntel" ]; then
        CPU_VENDOR="intel"
    elif [ "$VENDOR" == "AuthenticAMD" ]; then
        CPU_VENDOR="amd"
    fi
}

# Auslesen saemtlicher Festplatten im System (Return ist ein Array)
get_disks(){
    # mapfile -t HARDDRIVES < <(lsblk -d | awk '{print "/dev/" $1 " " $4}' | grep -E 'sd|hd|vd|nvme|mmcblk')
    HARDDRIVES=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' | grep -E 'sd|hd|vd|nvme|mmcblk'))
}


# Funktion zum Erkennen der RAM-Größe und Festlegen der Swap-Größe
get_ram_size() {
    RAM_SIZE=$(free --giga | awk '/Mem:/ {print $2}')
    if [ "$RAM_SIZE" -eq 0 ]; then
        RAM_SIZE=$(free --mega | awk '/Mem:/ {print $2}')
        RAM_SIZE=$(echo "($RAM_SIZE / 1024) + 1" | bc) # Auf volle GB runden
    fi
    echo "Erkannte RAM-Größe: ${RAM_SIZE}G"
    SWAP_SIZE=${RAM_SIZE}
    echo "Swap-Größe wird auf ${SWAP_SIZE}G gesetzt."
}

###############################
### Hauptscript beginnt hier###
###############################
get_session_type
if [[ $(cat env) == "live" ]];then
    echo "timedatectl set-ntp true"
    get_cpu_vendor
    get_disks
    INSTALL_DISK=$(dialog --title "Installations Ziel aussuchen" --no-cancel --radiolist \
        "Auf welche Festplatte soll installiert werden? \n\n\
        Auswahl mit SPACE, bestaetigen mit ENTER. \n\n\
        ACHTUNG: Es wird ALLES GELOESCHT auf der Platte!" 15 60 4 "${HARDDRIVES[@]}" 3>&1 1>&2 2>&3)
    
    dialog --title "Mit SWAP Partition?" --yesno \
        "Soll eine SWAP Partition eingerichtet werden?\n\n" 5 60
    response=$?
    case $response in
        0) get_ram_size
            echo "Ja" ;;
        1) echo "Nein" ;;
    esac
fi
