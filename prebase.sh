#!/bin/bash

# Im Live System das Script verwenden um weitergehende Programme zu installieren
USER="$(whoami)"
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
        sudo pacman -Syu base-devel git
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
    sudo pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU plasma
    yay -S --noconfirm --needed $YAY_PKG
    sudo systemctl enable sddm
elif [ $desktop == "g" ]; then
    sudo pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU gnome
    yay -S --noconfirm --needed $YAY_PKG
    sudo systemctl enable gdm
elif [ $desktop == "c" ]; then
    sudo pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU sddm cinnamon
    yay -S --noconfirm --needed $YAY_PKG
    sudo systemctl enable sddm
elif [ $desktop == "b" ]; then
    sudo pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU $WM_DEFAULT_X11 sddm bspwm
    yay -S --noconfirm --needed $YAY_PKG
    sudo systemctl enable sddm
elif [ $desktop == "q" ]; then
    sudo pacman -Syu --noconfirm --needed $DEFAULT $CONSOLE_APPS $FONTS $DEVELOPMENT $GPU $WM_DEFAULT_X11 sddm qtile
    yay -S --noconfirm --needed $YAY_PKG
    sudo systemctl enable sddm
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
    sudo systemctl enable bluetooth
fi

rm env
echo "Installation abgeschlossen"
read -r "Neustart erforderlich. Bitte ENTER druecken"
systemctl reboot
