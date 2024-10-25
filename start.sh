#!/bin/bash

cat <<EOF
Willkommen bei meinem Installations Script.
Ziel des Scriptes: Den Installations Prozess des Base Systems zu automatisieren.
Im Base System kann das Script dann nochmals gestartet werden um ein GUI zu installieren.

Bei der Installation werden einige Daten gebraucht, bitte Hilf mir da aus: 
EOF
read -p "Computername: " HOSTNAME
read -p "Admin/Root Passwort: " ROOTPASSWD
read -p "Benutzername: " USERNAME
read -p "Benutzerpasswort: " USERPASSWD
cat <<EOF

Das Script speichert keine der Daten
Installation startet...
EOF
for i in {3..1};do
    echo "...$i..."
    sleep 1
done

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
echo "$HOSTNAME" >/etc/hostname
echo "root:$ROOTPASSWD" | chpasswd
pacman -S --noconfirm grub efibootmgr networkmanager openssh
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
systemctl enable sshd
useradd -mG wheel $USERNAME
echo fenix:$USERPASSWD | chpasswd
cp /etc/sudoers /tmp/sudoers.tmp
sed -i 's/^# \(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /tmp/sudoers.tmp
visudo -cf /tmp/sudoers.tmp
cp /tmp/sudoers.tmp /etc/sudoers
EOF
    # Installations Script noch in das HOME Dir des Users kopieren
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TARGET_DIR="/mnt/home/$USERNAME"
    cp -r "$SCRIPT_DIR" "$TARGET_DIR"
    echo "Script wurde nach $TARGET_DIR kopiert."
    # Abschluss
    umount -R /mnt
    echo "Arch Linux Installation abgeschlossen! Bitte neu starten."
else
    # Im Live System das Script verwenden um weitergehende Programme zu installieren
    # YAY (AUR Helper) Installation
    install_yay() {
            cd /tmp || exit
            git clone https://aur.archlinux.org/yay.git
            cd yay || exit
            makepkg -si --noconfirm
            echo "YAY wurde erfolgreich installiert."
    }

    if ! command -v yay &> /dev/null; then
        if pacman -Q base-devel git &> /dev/null; then
            install_yay
        else
            pacman -Syu base-devel git
            install_yay
        fi
    fi

    # Grafikkarte erkennen und den passenden Treiber installieren
    gpu_info=$(lspci | grep -E "VGA|3D")
    if echo "$gpu_info" | grep -iq "NVIDIA"; then
        GPU="sudo pacman -Syu nvidia"
    elif echo "$gpu_info" | grep -iq "AMD"; then
        GPU="sudo pacman -Syu amd"
    elif echo "$gpu_info" | grep -iq "Intel"; then
        GPU="sudo pacman -Syu intel"
    else
        GPU="sudo pacman -Syu"
    fi

    cat <<EOF
    Willkommen beim Pre-Installskript
    Welches DE oder welcher WM soll installiert werden?
    Dieses Script hat folgende Configs:
    
    plasma
    gnome
    cinnamon
    bspwm
    qtile
    hyprland

    EOF

    read -p "Welche davon soll installiert werden? " desktop

    if [ $desktop == "plasma" ]; then
        echo "PLASMA"
        $GPU
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
