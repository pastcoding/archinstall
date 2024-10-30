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

# Entfernen moeglicher alter Daten von anderen Installationen
rm env swap user

# Pre-Base Install Varaiblen
CPU_VENDOR=""
HARDDRIVES=""
INSTALL_DISK=""
RAM_SIZE=""

get_session_type(){
    if cat /proc/cmdline | grep -q "archiso"; then
        echo "install" > env
    else
        echo "live" > env
    fi
}

get_cpu_vendor(){
    VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
    if [ "$VENDOR" == "GenuineIntel" ]; then
        CPU_VENDOR="intel"
    elif [ "$VENDOR" == "AuthenticAMD" ]; then
        CPU_VENDOR="amd"
    fi
}

get_disks(){
    HARDDRIVES=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' | grep -E 'sd|hd|vd|nvme|mmcblk'))
}

nvme_check(){
    echo "$INSTALL_DISK" | grep -E 'nvme' &> /dev/null && INSTALL_DISK="${INSTALL_DISK}p"
}

get_ram_size() {
    RAM_SIZE=$(free --giga | awk '/Mem:/ {print $2}')
    if [ "$RAM_SIZE" -eq 0 ]; then
        RAM_SIZE=$(free --mega | awk '/Mem:/ {print $2}')
        RAM_SIZE=$(echo "($RAM_SIZE / 1024) + 1" | bc) # Auf volle GB runden
    fi
}

drive_partition(){
    parted -s "$INSTALL_DISK" mklabel gpt
    parted -s "$INSTALL_DISK" mkpart primary fat32 1MiB 1GiB
    parted -s "$INSTALL_DISK" set 1 esp on
    if [[ $(cat swap) == "true" ]]; then
        parted -s "$INSTALL_DISK" mkpart primary linux-swap 1GiB $((1 + RAM_SIZE))GiB
        parted -s "$INSTALL_DISK" mkpart primary ext4 $((1 + RAM_SIZE))GiB 100%
    else
        parted -s "$INSTALL_DISK" mkpart primary ext4 1GiB 100%
    fi
}
drive_format(){
    mkfs.fat -F32 "${INSTALL_DISK}1"
    if [[ $(cat swap) == "true" ]]; then
        mkswap -q "${INSTALL_DISK}2" # Swap-Partition formatieren
        mkfs.ext4 -F "${INSTALL_DISK}3"
    else
        mkfs.ext4 -F "${INSTALL_DISK}2"
    fi
}
drive_mount(){
    if [[ $(cat swap) == "true" ]]; then
        mount "${INSTALL_DISK}3" /mnt
        mount --mkdir "${INSTALL_DISK}1" /mnt/boot
        swapon "${INSTALL_DISK}2" # Swap aktivieren
    else
        mount "${INSTALL_DISK}2" /mnt
        mount --mkdir "${INSTALL_DISK}1" /mnt/boot
    fi
}
copy_script(){    # Installations Script noch in das HOME Dir des Users kopieren
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TARGET_DIR="$1"
    cp -r "$SCRIPT_DIR" "$TARGET_DIR"
    echo "Script wurde nach $TARGET_DIR kopiert."
}

###############################
### Hauptscript beginnt hier###
###############################
get_session_type
dialog --title "Sicher?" --yesno \
    "Sollen wir mit der Installation beginnen?\n\n
    Etwaige Daten auf der gewaehleten Festplatte werden geloescht!!!\n\n" 10 60
    response=$?
    case $response in
        0) ;;
        1) exit 0 ;;
    esac
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
        "Soll eine SWAP Partition eingerichtet werden?\n\n" 10 60
                response=$?
                case $response in
                    0) echo "true" > swap
                        get_ram_size
                        drive_partition ;;
                    1) echo "false" > swap
                        drive_partition ;;
                esac
    nvme_check
    drive_format
    drive_mount
    pacstrap /mnt base base-devel linux linux-firmware linux-headers neovim git dialog exfatprogs e2fsprogs man-db $UCODE
    genfstab -U /mnt >>/mnt/etc/fstab
    copy_script /mnt
    arch-chroot /mnt <<EOF
bash archinstall/prebase.sh
EOF

copy_script "$/mnt/home/$(cat /mnt/archinstall/user)"
rm -rf /mnt/archinstall

if [[ $(cat swap) == "true" ]]; then
    swapoff "${INSTALL_DISK}2"
fi
umount -R /mnt
fi

dialog --msgbox "Installaton abgeschlossen\n
Bitte neustarten :)" 10 60
