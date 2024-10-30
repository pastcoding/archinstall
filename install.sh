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
INSTALL_DISK=""
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

# NVME Check
nvme_check(){
    echo "$INSTALL_DISK" | grep -E 'nvme' &> /dev/null && INSTALL_DISK="${INSTALL_DISK}p"
}

# Funktion zum Erkennen der RAM-Größe und Festlegen der Swap-Größe
get_ram_size() {
    RAM_SIZE=$(free --giga | awk '/Mem:/ {print $2}')
    if [ "$RAM_SIZE" -eq 0 ]; then
        RAM_SIZE=$(free --mega | awk '/Mem:/ {print $2}')
        RAM_SIZE=$(echo "($RAM_SIZE / 1024) + 1" | bc) # Auf volle GB runden
    fi
    SWAP_SIZE=${RAM_SIZE}
}

# Funktion um die Festplatte zu partitionieren
drive_partition(){
    parted -s "$INSTALL_DISK" mklabel gpt
    parted -s "$INSTALL_DISK" mkpart primary fat32 1MiB 1GiB
    parted -s "$INSTALL_DISK" set 1 esp on
    if [[ "$SWAP" == "true" ]]; then
        parted -s "$INSTALL_DISK" mkpart primary linux-swap 1GiB $((1 + RAM_SIZE))GiB
        parted -s "$INSTALL_DISK" mkpart primary ext4 $((1 + RAM_SIZE))GiB 100%
    else
        parted -s "$INSTALL_DISK" mkpart primary ext4 1GiB 100%
    fi
}
# Formatieren der Partitionen
drive_format(){
    mkfs.fat -F32 "${INSTALL_DISK}1"
    if [[ "$SWAP" == "true" ]]; then
        mkswap -q "${INSTALL_DISK}2" # Swap-Partition formatieren
        mkfs.ext4 -F "${INSTALL_DISK}3"
    else
        mkfs.ext4 -F "${INSTALL_DISK}2"
    fi
}
# Einbinden der Partitionen
drive_mount(){
    if [[ "$SWAP" == "true" ]]; then
        mount "${INSTALL_DISK}3" /mnt
        mount --mkdir "${INSTALL_DISK}1" /mnt/boot
        swapon "${INSTALL_DISK}2" # Swap aktivieren
    else
        mount "${INSTALL_DISK}2" /mnt
        mount --mkdir "${INSTALL_DISK}1" /mnt/boot
    fi
}
###############################
### Hauptscript beginnt hier###
###############################
get_session_type
if [[ $(cat env) == "install" ]];then
    timedatectl set-ntp true
    pacman -S --noconfirm dialog
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
                0) SWAP="true"
                    get_ram_size
                    drive_partition
                    echo "Ja" ;;
                1) SWAP="false"
                    drive_partition
                    echo "Nein" ;;
            esac
            nvme_check
            drive_format
            drive_mount
    pacstrap /mnt base base-devel linux linux-firmware linux-headers neovim git dialog exfatprogs e2fsprogs man-db $UCODE
    genfstab -U /mnt >>/mnt/etc/fstab

fi
