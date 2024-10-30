#!/bin/bash

config_user() {
    if [ -z "$1" ]; then
        dialog --no-cancel --inputbox "Bitte gib deinen Benutzernamen ein." 10 60 2> user
    else
        echo "$1" > user
    fi
    dialog --no-cancel --passwordbox "Bitte gib dein Passwort ein" 10 60 2> pass1
    dialog --no-cancel --passwordbox "Bitte wiederhole dein Passwort" 10 60 2> pass2
    while [ "$(cat pass1)" != "$(cat pass2)" ]
    do
        dialog --no-cancel --passwordbox "Eingaben stimmen nicht ueberein.\n\nBitte gib dein Passwort ein" 10 60 2> pass1
        dialog --no-cancel --passwordbox "Bitte wiederhole dein Passwort" 10 60 2> pass2
    done
    user=$(cat user) && rm user
    pass1=$(cat pass1) && rm pass1 pass2
    # Create user if doesn't exist
    if [[ ! "$(id -u "$user" 2> /dev/null)" ]]; then
        useradd -m -g wheel -s /bin/bash "$user"
    fi
    # Add password to user
    echo "$user:$pass1" | chpasswd
}

echo "Willkommen im neuen System"

ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
hwclock --systohc
sed -i '127s/.//' /etc/locale.gen
sed -i '171s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
echo "archvm" >> /etc/hostname
dialog --title "Root Passwort" --msgbox "Bitte gib ein Passwort fuer ROOT ein" 10 60
config_user root
dialog --title "Benutzer hinzufuegen" --msgbox "Lass uns einen Benuzter erstellen" 10 60
config_user
pacman -S --noconfirm grub efibootmgr networkmanager openssh
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable NetworkManager
systemctl enable sshd
cp /etc/sudoers /tmp/sudoers.tmp
sed -i 's/^# \(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /tmp/sudoers.tmp
visudo -cf /tmp/sudoers.tmp
cp /tmp/sudoers.tmp /etc/sudoers
