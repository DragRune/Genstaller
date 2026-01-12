#!/bin/bash

set -euo pipefail

# Root Check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   echo "Please become root and try again."
   echo "Exiting immediately without change."
   exit 1
fi

# Networking Test
echo "Testing Networking"
# Testing gentoo.org domain
if ping -c 3 -W 5 gentoo.org >/dev/null 2>&1; then
	# Connected to gentoo.org
	echo "Passed network test!"
else
	# Didn't reach gentoo.org, test google.com
	echo "WARNING: Could not reach gentoo.org"
	echo "In a rare case, the domain might be down."
	echo "Testing a different domain!"
	# Testing 1.1.1.1 domain
	if ping -c 3 -W 5 1.1.1.1 >/dev/null 2>&1; then
		# Internet, but gentoo.org is down
		echo "You have a connection! HOWEVER,"
		echo "gentoo.org is offline."
		echo "Please re-run this script when you have a connection."
		echo "The installer will now exit."
		exit 1
	else
		# No internet connection.
		echo "You do NOT have a connection!"
		echo "Please ensure you are connected,"
		echo "then re-run this script!"
		echo "The insaller will now exit."
		exit 1
	fi
fi

echo "What is the current time?"
while true; do
	read -r -p "Please use MMDDhhmmYYYY format: " time_set
	date "$time_set"
	echo "You have chosen the time to be: "(date)
	echo "Is this time correct?"
	read -r -p "Please answer Y/N: " time_conf
	if [ "$time_conf" = "y" ]; then
		echo "Got it, proceeding"
		break
	elif [ "$time_conf" = "Y" ]; then
		echo "Got it, proceeding"
		break
	elif [ "$time_conf" = "n" ]; then
		echo "Understood, perhaps the time was entered incorrectly."
		echo "Running it back..."
	elif [ "$time_conf" = "N" ]; then
		echo "Understood, perhaps the time was entered incorrectly."
		echo "Running it back..."
	else
		echo "Invalid input"
	fi
done

# Drive wiping
echo "Next is your drive. Review this to find the drive you want to partition:"
lsblk
read -r -p "Please firmly state the end of your drive (example: nvme0 ) in lowercase: " disk_choice
DISK=/dev/"$disk_choice"
echo Preparing to wipe your "$disk_choice" drive
echo "CTRL + C to cancel..."
sleep 1
echo "In 3..."
sleep 1
echo "In 2..."
sleep 1
echo "In 1..."
sleep 1
echo "Wiping drive!"
sleep 1
wipefs -af "$DISK"
sgdisk --zap-all "$DISK"
echo "Done!"
lsblk

# Partitioning
fdisk "$DISK" <<'EOF'
g
n


+512M
n


+8G
n



w
EOF
lsblk

# Telling kernel about the partitions
partprobe "$DISK"
udevadm settle
echo "Done!"

# Modifying the partition's filesystem
if [ "$disk_choice" = "nvme0" ]; then
	PART1="$DISK"n1
	PART2="$DISK"n2
	PART3="$DISK"n3
elif [ "$disk_choice" = "nvme1" ]; then
	PART1="$DISK"n1
	PART2="$DISK"n2
	PART3="$DISK"n3
elif [ "$disk_choice" = "nvme2" ]; then
	PART1="$DISK"n1
	PART2="$DISK"n2
	PART3="$DISK"n3
else
	PART1="$DISK"1
	PART2="$DISK"2
	PART3="$DISK"3
fi
echo "Changing partition filesystem"
mkfs.ext4 "$PART3"
mkfs.fat -F 32 "$PART1"
mkswap "$PART2"
echo "Done!"
lsblk

# Mounting Partitions + Making /mnt/gentoo
GEN=/mnt/gentoo
mkdir -p "$GEN"
mount "$PART3" "$GEN"
swapon "$PART2"
lsblk

# Stage file
echo "Would you like to use OpenRC or SystemD?"
while true; do
	read -r -p 'Please state "openrc" or "systemd" in lowercase: ' init_choice
	if [ "$init_choice" = "openrc" ]; then
		echo "Acquiring stage file"
		wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/latest-stage3-amd64-openrc.txt
		STAGE_FILE="$(awk '/stage3/ {print $1}' latest-stage3-amd64-openrc.txt)"
		wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/"$STAGE_FILE"
		echo "Stage file acquired"
		echo "Extracting stage file"
		tar xpvf "$STAGE_FILE" --xattrs-include='*.*' --numeric-owner -C "$GEN"
		echo "Stage file has finished extracting!"
		echo "Writing make.conf"
		echo 'USE="-systemd elogind dbus"' | tee -a "$GEN"/etc/portage/make.conf
		echo "Done!"
	elif [ "$init_choice" = "systemd" ]; then
		echo "Acquiring stage file"
		wget https://gentoo.osuosl.org/releases/amd64/autobuilds/current-stage3-amd64-systemd/latest-stage3-amd64-systemd.txt
		STAGE_FILE="$(awk '/stage3/ {print $1}' latest-stage3-amd64-systemd.txt)"
		wget https://gentoo.osuosl.org/releases/amd64/autobuilds/current-stage3-amd64-systemd/"$STAGE_FILE"
		echo "Stage file acquired"
		echo "Extracting stage file"
		tar xpvf "$STAGE_FILE" --xattrs-include='*.*' --numeric-owner -C "$GEN"
		echo "Stage file has finished extracting!"
		echo "Writing make.conf"
		echo 'USE="systemd elogind dbus"' | tee -a "$GEN"/etc/portage/make.conf
		echo "Done!"
	else
		echo "Invalid input."
	fi
done
echo 'MAKEOPTS="-j8 -l9"' | tee -a "$GEN"/etc/portage/make.conf

# Chrooting
echo "Mounting needed things for a proper chroot environment."
cp --dereference /etc/resolv.conf "$GEN"/etc
mount --types proc /proc "$GEN"/proc
mount --rbind /sys "$GEN"/sys
mount --make-rslave "$GEN"/sys
mount --rbind /dev "$GEN"/dev
mount --make-rslave "$GEN"/dev
mount --bind /run "$GEN"/run
mount --make-slave "$GEN"/run
echo "Done!"
echo "Chrooting..."
chroot "$GEN" /bin/bash << 'EOF'
echo "Chrooted!"

# =====BEGINNING OF CHROOT ENVIRONMENT=====

# First Chroot Commands
echo "Sourcing /etc/profile"
source /etc/profile
export PS1="(Gentoo Chroot) ${PS1}"
echo "Mounting Boot"
mount --mkdir /dev/sda1 /boot/efi
echo "Running emerge-webrsync"
emerge-webrsync
echo "Done!"

# Eselect profile & Emerge syncing
echo "Setting eselect profile"
eselect profile set "default/linux/amd64/23.0"
EOF

# @world preference
echo "Would you like to emerge @world?"
echo "This is optional, but HIGHLY recommended."
echo "Note: The time this command takes varies."
while true; do
	read -r -p "Please answer [Y/N]: " world_choice
	if [ "$world_choice" = "y" ]; then
chroot "$GEN" /bin/bash << 'EOF'
echo "emerging @world"
emerge --verbose --update --changed-use --with-bdeps=y --deep @world
EOF
		break
	elif [ "$world_choice" = "Y" ]; then
chroot "$GEN" /bin/bash << 'EOF'
echo "emerging @world"
emerge --verbose --update --changed-use --with-bdeps=y --deep @world
EOF
		break
	elif [ "$world_choice" = "n" ]; then
		echo "Will not emerge @world"
		break
	elif [ "$world_choice" = "N" ]; then
		echo "Will not emerge @world"
		break
	else
		echo "Invalid input."
	fi
done
chroot "$GEN" /bin/bash << 'EOF'
eselect news read
echo "Done!"
EOF

#Text Editors
echo "You have the choice of 4 popular text editors"
echo 'if your prefered option is not listed, please firmly state "none"'
echo "- nano"
echo "- vim"
echo "- neovim"
echo "- emacs"
while true; do
	read -r -p "Please cleanly state your choice in lowercase for your selection: " text_choice
	if [ "$text_choice" = "neovim" ]; then
		echo "Neovim selected, emerging"
chroot "$GEN" /bin/bash << 'EOF'
emerge --verbose app-editors/neovim
EOF
		break
	elif [ "$text_choice" = "vim" ]; then
		echo "Vim selected, emerging"
chroot "$GEN" /bin/bash << 'EOF'
emerge --verbose app-editors/vim
EOF
		break
	elif [ "$text_choice" = "nano" ]; then
		echo "Nano selected, emerging"
chroot "$GEN" /bin/bash << 'EOF'
emerge --verbose app-editors/nano
EOF
		break
	elif [ "$text_choice" = "emacs" ]; then
		echo "Emacs selected, emerging"
chroot "$GEN" /bin/bash << 'EOF'
emerge --verbose app-editors/emacs
EOF
		break
	elif [ "$text_choice" = "none" ]; then
		break
	else
		echo "Invalid input. Your choices must be one of the following choices:"
		echo "- nano"
		echo "- vim"
		echo "- neovim"
		echo "- emacs"
		echo "- none"
	fi
done
chroot "$GEN" /bin/bash << 'EOF'

# Locale Generation
echo "Linking timezone information"
ln -sf /usr/share/zoneinfo/America/Indiana/Indianapolis /etc/localtime
echo "Setting locale"
grep -q '^en_US.UTF-8 UTF-8$' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
TARGET_LOCALE="en_US.UTF-8"
eselect locale set "$TARGET_LOCALE"
echo "Done!"

# Environment Update
echo "Updating environment"
sleep 1
env-update && source /etc/profile && export PS1="(Gentoo Chroot) $PS1"
echo "Done!"

# Firmware compilation
echo "Preparing for firmware compilation"
echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" | tee -a /etc/portage/package.license
echo "Done! Compiling firmware"
emerge --verbose sys-kernel/linux-firmware
eselect news read
echo "Done!"
EOF

# Kernel compilation
echo "Do you wish to use your own kernel? Or the gentoo-bin kernel?"
while true; do
	read -r -p 'Please state "1" for your own kernel, or "2" for the gentoo-bin kernel: ' kernel_choice
	if [ "$kernel_choice" = "2" ]; then
chroot "$GEN" /bin/bash << 'EOF'
echo "Preparing for gentoo-bin kernel compilation"
echo "sys-kernel/installkernel dracut grub" >> /etc/portage/package.use/installkernel
emerge --verbose sys-kernel/installkernel
eselect news read
echo "Note: This command can take an excessive amount of time."
echo "That being said, please have no concern if it's lengthy."
echo "Beginning gentoo-bin kernel compilation now"
emerge --quiet sys-kernel/gentoo-kernel-bin
eselect news read
echo "Done!"
echo "Compiling grub bootloader"
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge --verbose sys-boot/grub efibootmgr
grub-install --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
EOF
		break
	elif [ "$kernel_choice" = "1" ]; then
		echo "Understood, own kernel. Emerging necessary tools"
chroot "$GEN" /bin/bash << 'EOF'
emerge --verbose sys-kernel/modprobed-db
echo "REMINDER: /usr/src/linux is where you usually build your own kernel."
EOF
		echo "Seeing as you are building your own kernel,"
		echo "would you like for grub to be installed but unconfigured?"
		read -r -p "Please answer Y/N: " own_kernel_choice
		if [ "$own_kernel_choice" = "y" ]; then
			echo "Got it, emerging grub bootloader"
chroot "$GEN" /bin/bash << 'EOF'
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge --verbose sys-boot/grub efibootmgr
grub-install --efi-directory=/boot/efi
EOF
			break
		elif [ "$own_kernel_choice" = "Y" ]; then
			echo "Got it, emerging grub bootloader"
chroot "$GEN" /bin/bash << 'EOF'
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge --verbose sys-boot/grub efibootmgr
grub-install --efi-directory=/boot/efi
EOF
			break
		elif [ "$own_kernel_choice" = "n" ]; then
			echo "Got it. A bootloader will NOT be installed"
			break
		elif [ "$own_kernel_choice" = "N" ]; then
			echo "Got it. A bootloader will NOT be installed"
			break
		fi
	else
		echo "Please only specify 1 or 2"
	fi
done

# Fstab configuration
echo "Did you partition sda or nvme?"
while true; do
	read -r -p 'Please state "sda" or "nvme": ' fstab_drive
	if [ "$fstab_drive" = "sda" ]; then
chroot "$GEN" /bin/bash << 'EOF'
echo "Setting up Fstab"
echo "/dev/sda1		/boot/efi	vfat		defaults	0 2" | tee -a /etc/fstab
echo "/dev/sda2		none		swap		sw		0 0" | tee -a /etc/fstab
echo "/dev/sda3		/		ext4		noatime		0 1" | tee -a /etc/fstab
echo "Done!"
EOF
	break
	elif [ "$fstab_drive" = "nvme" ]; then
chroot "$GEN" /bin/bash << 'EOF'
echo "Setting up Fstab"
echo "/dev/nvme0n1	/boot/efi	vfat		defaults	0 2" | tee -a /etc/fstab
echo "/dev/nvme0n2	none		swap		sw		0 0" | tee -a /etc/fstab
echo "/dev/nvme0n3	/		ext4		noatime		0 1" | tee -a /etc/fstab
echo "Done!"
EOF
	break
	else
		echo 'Please only enter "sda" or "nvme"'
	fi
done

# Hostname configuration
read -r -p "Please state your preferred hostname: " hname_choice
echo You have chosen the hostname "$hname_choice"
chroot "$GEN" /bin/bash << 'EOF'
echo hostname="$hname_choice" | tee -a /etc/conf.d/hostname
echo "Done!"

# Networking compilation
echo "Setting up networking"
echo 127.0.0.1 "$hname_choice" | tee -a /etc/hosts
emerge --verbose net-misc/dhcpcd
eselect news read
emerge --verbose --noreplace net-misc/netirc
eselect news read
net_name="$(ip route get 8.8.8.8 | awk '{print $5}')"
echo config_"$net_name"='"dhcp"' | tee -a /etc/conf.d/net
ln -s /etc/init.d/net.lo /etc/init.d/net."$net_name"
rc-update add net."$net_name" default
echo "Done!"
EOF

# Sudo or Doas
echo "What is your preferred privilege escalation tool?"
echo "Do you prefer Doas, or Sudo?"
while true; do
	read -r -p "Please cleanly state doas or sudo in lowercase for your selection: " sudo_choice
	if [ "$sudo_choice" = "sudo" ]; then
chroot "$GEN" /bin/bash << 'EOF'
echo "Emerging sudo"
emerge --verbose app-admin/sudo
echo "Configuring sudo"
echo "%wheel ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers
EOF
		break
	elif [ "$sudo_choice" = "doas" ]; then
chroot "$GEN" /bin/bash << 'EOF'
echo "Emerging doas"
emerge --verbose app-admin/doas
echo "Configuring doas"
echo "permit :wheel" | tee -a /etc/doas.conf
EOF
		break
	else
		echo "Invalid input. Please enter sudo or doas."
	fi
done
chroot "$GEN" /bin/bash << 'EOF'

# Grub boot loader config
if [ "$kernel_choice" = "2" ]; then
grub-mkconfig -o /boot/grub/grub.cfg
fi
EOF

# User configuration
read -r -p "Please create a username for the user: " NEWUSER
echo Adding user "$NEWUSER" with the following groups
echo "users,wheel,video,audio,input"
chroot "$GEN" /bin/bash << 'EOF'
useradd -m -G users,wheel,video,audio,input -s /bin/bash "$NEWUSER"
EOF

# GPU
echo "What kind of GPU do you have?"
while true; do
	read -r -p 'Please state "nvidia" or "amd" in lowercase: ' gpu_choice
	if [ "$gpu_choice" = "nvidia" ]; then
		echo "Got it. Emerging necessary drivers"
chroot "$GEN" /bin/bash << 'EOF'
emerge --verbose x11-drivers/nvidia-drivers
EOF
		echo "Done"
		break
	elif [ "$gpu_choice" = "amd" ]; then
		echo "Got it. proceeding"
		break
	else
		echo "Invalid input."
	fi
done

echo "Leaving Chroot environment"
# =====END OF CHROOT ENVIRONMENT=====

echo "Done!"
lsblk
ls "$GEN"

echo "The installer has finished!
Please let it be known passwords have not been set!
Please feel free to reboot when ready!
Thank you for choosing Genstaller!
===== Created by DragRune =====
Questions? Contact me on Discord:
real_djkevin"
