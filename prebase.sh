#!/bin/bash

config_user() {
    if [ -z "$1" ]; then
        dialog --no-cancel --inputbox "Please enter your user name." 10 60 2> user
    else
        echo "$1" > user
    fi
    dialog --no-cancel --passwordbox "Enter your password." 10 60 2> pass1
    dialog --no-cancel --passwordbox "Confirm your password." 10 60 2> pass2
    while [ "$(cat pass1)" != "$(cat pass2)" ]
    do
        dialog --no-cancel --passwordbox "The passwords do not match.\n\nEnter your password again." 10 60 2> pass1
        dialog --no-cancel --passwordbox "Retype your password." 10 60 2> pass2
    done
    user=$(cat user)
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
dialog --title "Root password" --msgbox "It's time to add a password for the root user" 10 60
config_user root
dialog --title "Add user" --msgbox "Let's create another user." 10 60
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

rm env swap
