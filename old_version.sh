#!/bin/bash

# OLD VERSION OF THE SCRIPT
# HERE FOR REFRENCE
# DONT USE IT

clear

# Check ob wir uns im Live System befinden oder im Install System
if cat /proc/cmdline | grep -q "archiso"; then
    cat <<EOF
Willkommen bei meinem Installations Script.
Ziel des Scriptes: Den Installations Prozess des Base Systems zu automatisieren.
Im Base System kann das Script dann nochmals gestartet werden um ein GUI zu installieren.

EOF
    # Installations Prozess beginnen
    echo "Bei der Installation werden einige Daten gebraucht, bitte Hilf mir da aus :)"
    echo "Das Script speichert keine Daten/Passwoerter!!!"
    read -p "Computername: " HOSTNAME
    read -p "Admin/Root Passwort: " ROOTPASSWD
    read -p "Benutzername: " USERNAME
    read -p "Benutzerpasswort: " USERPASSWD
    echo "Installation startet..."
    for i in {5..1};do
        echo "...$i..."
        sleep 1
    done
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
echo $USERNAME:$USERPASSWD | chpasswd
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
    read -r "Arch Linux Installation abgeschlossen! Bitte neu starten mit ENTER"
    systemctl reboot
else
    # Im Live System das Script verwenden um weitergehende Programme zu installieren
    # Im Live System muss das Script mit root Rechten gestartet werden (Installieren von Apps und editieren von Systemdateien)
	if [[ $EUID -ne 0 ]]; then
	   echo "Dieses Skript muss mit sudo oder als Root-Benutzer ausgeführt werden."
	   exit 1
	fi
    # Da wir spaeter YAY verwenden, brauchen wir auch den normalen Usernamen (yay mit root wird nicht empfohlen)
    USER="${SUDO_USER:-$(whoami)}"
    # Wir legen hier an dieser Stelle fest, welche Programme in den "Paketen" enthalten sind.
    # Es kann jederzeit auch angepasst werden hier im Script und eigene Programme hinzugefuegt oder andere entfernt werden

    DEFAULT="zsh zsh-autosuggestions zsh-completions zsh-syntax-highlighting xdg-user-dirs reflector pacman-contrib firefox zathura zathura-pdf-poppler poppler poppler-glib pipewire pipewire-alsa pipewire-jack pipewire-pulse pipewire-zeroconf wireplumber pamixer playerctl xdg-desktop-portal-gtk dosfstools gvfs gvfs-mtp gvfs-nfs gvfs-smb gvfs-wsdd nfs-utils bluez bluez-tools bluez-utils mpv kitty"
    CONSOLE_APPS="tmux zoxide eza yazi ffmpegthumbnailer ffmpeg libheif vkd3d libva-mesa-driver btop bat aria2 duf tealdeer trash-cli unrar unzip zip yt-dlp dust ytfzf"
    FONTS="noto-fonts-cjk noto-fonts-emoji ttf-iosevka-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono ttf-ubuntu-nerd ttf-noto-nerd ttf-meslo-nerd ttf-liberation"
    DEVELOPMENT="tree-sitter-cli nodejs npm python yarn ripgrep fd fzf diff-so-fancy lazygit glow luarocks qmk wget"
    WM_DEFAULT_X11="sxhkd kitty dunst picom feh polybar thunar thunar-archive-plugin thunar-volman tumbler arandr rofi unclutter xarchiver xclip xfce-polkit udiskie pavucontrol scrot mpv xorg-server"
    THEME_GTK="bibata-cursor-theme kora-icon-theme lxappearance-gtk3 orchis-theme"
    GAMING="steam mangohud goverlay mesa-utils vulkan-tools xpadneo-dkms protonup-qt prismlauncher jdk-openjdk piper"
    YAY_PKG="mkinitcpio-firmware ueberzugpp"

    cat <<EOF
Willkommen bei Pre Install Teil des Scripts
Es wird nun das multilib repo aktiviert und danach wird ein AUR Helper (yay) installiert.

Die Installation wird dann mit der DE/WM Auswahl fortgesetzt.

Um zu beginnen, ENTER
Zum beenden, CTRL+C
EOF
    read -r
    # Multilib aktivieren 
	PACMAN_CONF="/etc/pacman.conf"
	if grep -q "^\[multilib\]" "$PACMAN_CONF" && grep -A 1 "^\[multilib\]" "$PACMAN_CONF" | grep -q "^Include = /etc/pacman.d/mirrorlist"; then
	    echo "Das multilib-Repository ist bereits aktiviert."
        sleep 1
	else
	    echo "Aktiviere das multilib-Repository..."
	    sudo sed -i '/#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ {s/^#//}' "$PACMAN_CONF"
	    echo "Das multilib-Repository wurde aktiviert."
	    echo "Aktualisiere die Pacman-Datenbank..."
        sleep 1
	    sudo pacman -Sy
	fi

    # YAY (AUR Helper) Installation
    install_yay() {
            cd /tmp
            git clone https://aur.archlinux.org/yay.git
            cd yay
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
    else 
        echo "YAY ist bereits installiert."
        sleep 1
    fi

    # Grafikkarte erkennen und den passenden Treiber installieren
    gpu_info=$(lspci | grep -E "VGA|3D")
    echo "Grafikkarten Check"
    sleep 1
    if echo "$gpu_info" | grep -iq "NVIDIA"; then
        echo "Welche Nvidia Karte welchen Treiber braucht, kann man im Wiki oder bei Nvidia nachlesen."
        echo "https://github.com/NVIDIA/open-gpu-kernel-modules?tab=readme-ov-file#compatible-gpus"
        echo "https://wiki.archlinux.org/title/NVIDIA#Installation"
        read -p "Brauchst du die Proprietary Open Source Treiber von NVIDIA? (j/n)" answer_nvidia_driver
        if [ $answer_nvidia_driver == "j" || $answer_nvidia_driver == "y" ]; then
            GPU="nvidia-open nvidia-utils lib32-nvidia-utils nvidia-settings"
        elif [ $answer_nvidia_driver == "n" ]; then
            GPU="nvidia nvidia-utils lib32-nvidia-utils nvidia-settings"
        else
            echo "Keine korrekte Antwort. Es wird kein NVIDIA Treiber installiert"
            GPU=""
        fi
    elif echo "$gpu_info" | grep -iq "AMD"; then
        GPU="mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon"
    elif echo "$gpu_info" | grep -iq "Intel"; then
        GPU="mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel"
    elif echo "$gpu_info" | grep -iq "VMware"; then
        GPU="virtualbox-guest-utils"
    else
        echo "Keine passende Grafikkarte im System entdeckt!!!"
        GPU=""
    fi

    cat <<EOF
Welches DE oder welcher WM soll installiert werden?
Dieses Script hat folgende Configs:

(p)lasma
(g)nome
(c)innamon
(b)spwm
(q)tile

EOF

    read -p "Welche davon soll installiert werden? (p/g/c/b/q)" desktop

    if [ $desktop == "p" ]; then
        pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU plasma
        sudo -u $USER yay -S --noconfirm --needed $YAY_PKG
        systemctl enable sddm
    elif [ $desktop == "g" ]; then
        pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU gnome
        sudo -u $USER yay -S --noconfirm --needed $YAY_PKG
        systemctl enable gdm
    elif [ $desktop == "c" ]; then
        pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU gdm cinnamon
        sudo -u $USER yay -S --noconfirm --needed $YAY_PKG
        systemctl enable gdm
    elif [ $desktop == "b" ]; then
        pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU $WM_DEFAULT_X11 sddm bspwm
        sudo -u $USER yay -S --noconfirm --needed $YAY_PKG
        systemctl enable sddm
    elif [ $desktop == "q" ]; then
        pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU $WM_DEFAULT_X11 sddm qtile
        sudo -u $USER yay -S --noconfirm --needed $YAY_PKG
        systemctl enable sddm
    else
        echo "Keine korrekte Auswahl getroffen, es wird nichts installiert"
        echo "Script wird beendet, da es nichts mehr zu tun gibt"
        sleep 1
        exit 0
    fi
    echo "Installation des GUI abgeschlossen"
    sleep 1
    #Abfrage ob das System Bluetooth hat und ob es aktiviert werden soll
    read -p "Hat das System Bluetooth und soll es aktiviert werden? (j/n) " answer_bluetooth
    if [ $answer_bluetooth == "j" || $answer_bluetooth == "y" ]; then
        systemctl enable bluetooth
    fi

    echo "Installation abgeschlossen"
    read -r "Neustart erforderlich. Bitte ENTER druecken"
    systemctl reboot

fi
