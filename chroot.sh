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

timezones=$(timedatectl list-timezones)
while [ -z $filtered_timezones ]; do
    search_term=$(dialog --inputbox "Geben Sie einen Suchbegriff für die Zeitzone ein (z.B. 'Europe' oder 'Berlin'):" 10 60 3>&1 1>&2 2>&3 )
    filtered_timezones=$(echo "$timezones" | grep -i "$search_term")
    if [ -z "$filtered_timezones" ]; then
        dialog --msgbox "Keine Zeitzonen gefunden, die '$search_term' entsprechen." 10 50
    fi
done

options=()
while IFS= read -r timezone; do
    options+=("$timezone" "$timezone")
done <<< "$filtered_timezones"

SELECTED_TIMEZONE=$(dialog --clear --title "Zeitzone auswählen" --menu "Bitte wählen Sie eine Zeitzone aus:" 20 60 15 "${options[@]}" 3>&1 1>&2 2>&3 )
ln -sf /usr/share/zoneinfo/$SELECTED_TIMEZONE /etc/localtime
hwclock --systohc
LOCALE=$(dialog --clear --title "Lokalizierung angeben" --msgbox "Bitte nennen die zu verwendete Lokalizierung\nFormatbeispiel: en_US oder de_DE" 15 60)
echo "${LOCALE}.UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}.UTF-8" >/etc/locale.conf
dialog --no-cancel --inputbox "Bitte gib deinem Rechner einen Namen." 10 60 2> /etc/hostname
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
dialog --clear --title "Installation abgeschlossen" --msgbox "Alles hat super geklappt und das Base System wurde erfolgreich installiert.\nWeitere Individualisierungen (Keyboard Einstellugen, erweiterte Locale Config, weitere Benutzer hinzufuegen) sind bitte manuell und selbststaendig durchzufuehren\n\nViel Spass mit deinem neuen Arch Linux" 20 60
