#!/bin/sh

# Check ob wir uns im Live System befinden oder im Install System
if cat /proc/cmdline | grep -q "archiso"; then
    # Installations Prozess beginnen
    # NetworkTime aktivieren
    timedatectl set-ntp true

    get_cpu_vendor(){
        VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')
	if [ "$VENDOR" == "GenuineIntel" ]; then
	    UCODE="intel-ucode"
	elif [ "$VENDOR" == "AuthenticAMD" ]; then
	    UCODE="amd-ucode"
	fi
    }
    get_cpu_vendor

    # Funktion zum Scannen der Festplatten und Auswahl der Ziel-Festplatte
    select_disk() {
        echo "Erkannte Festplatten:"
        lsblk -d -o NAME,SIZE,MODEL | grep -E 'sd|nvme|vd'
        echo
        read -p "Bitte wähle die Festplatte für die Installation (z.B. sda, nvme0n1): " disk
        DISK="/dev/$disk"

        if [ ! -b "$DISK" ]; then
            echo "Ungültige Festplatte ausgewählt. Bitte erneut versuchen."
            select_disk
        else
            echo "Festplatte $DISK ausgewählt."
        fi
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

    # Festplattenscan und -auswahl
    select_disk

    # RAM-Größe ermitteln
    get_ram_size

    # Partitionierung der ausgewählten Festplatte
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart primary fat32 1MiB 1GiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary linux-swap 1GiB $((1 + RAM_SIZE))GiB
    parted -s "$DISK" mkpart primary ext4 $((1 + RAM_SIZE))GiB 100%

    # Formatieren der Partitionen
    mkfs.fat -F32 "${DISK}1"
    mkswap "${DISK}2" # Swap-Partition formatieren
    mkfs.ext4 "${DISK}3"

    # Einbinden der Partitionen
    mount "${DISK}3" /mnt
    mount --mkdir "${DISK}1" /mnt/boot
    swapon "${DISK}2" # Swap aktivieren

    # Installation der Basispakete
    pacstrap /mnt base base-devel linux linux-firmware linux-headers neovim git exfatprogs e2fsprogs man-db $UCODE

    # Generiere die fstab-Datei
    genfstab -U /mnt >>/mnt/etc/fstab

    # Wechsel in das neue System (chroot)
    arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
hwclock --systohc
sed -i '127s/.//' /etc/locale.gen
sed -i '171s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
echo "olymp" >/etc/hostname
echo "root:passwd" | chpasswd
pacman -S --noconfirm grub efibootmgr networkmanager openssh
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
systemctl enable sshd
useradd -mG wheel fenix
echo fenix:pwd4root | chpasswd
cp /etc/sudoers /tmp/sudoers.tmp
sed -i '/^root.*/a user ALL=(ALL) NOPASSWD:ALL' /tmp/sudoers.tmp
visudo -cf /tmp/sudoers.tmp
cp /tmp/sudoers.tmp /etc/sudoers
EOF

    # Abschluss
    umount -R /mnt
    echo "Arch Linux Installation abgeschlossen! Bitte neu starten."
else
    # Wenn im Live System wird das Script verwendet um weitergehende Programme zu installieren
    # YAY (AUR Helper) Installation
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si && cd && rm -rf yay
    git clone https://github.com/pastcoding/archinstall.git && bash archinstall/start.sh

    echo "Willkommen beim Pre-Installskript"
    echo "Welches DE oder welcher WM soll installiert werden?"
    read -p "plasma, gnome, cinnamon, bspwm, qtile, hyprland" desktop
    if [ $desktop == "plasma" ]; then
        echo "PLASMA"
    elif [ $desktop == "gnome" ]; then
        echo "GNOME"
    elif [ $desktop == "cinnamon" ]; then
        echo "CINNAMON"
    elif [ $desktop == "bspwm" ]; then
        echo "BSPWM"
    elif [ $desktop == "qtile" ]; then
        echo "QTILE"
    elif [ $desktop == "hyprland" ]; then
        echo "HYPRLAND"
    else
        echo "Keine korrekte Auswahl getroffen, es wird nichts installiert"
    fi
fi
