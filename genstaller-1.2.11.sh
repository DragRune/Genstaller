#!/usr/bin/env bash

set -euo pipefail

echo "This is Genstaller v1.2.11"

RootCheck() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root."
        echo "Please become root and try again."
        echo "Exiting immediately without change."
        exit 1
    fi
}

TestNetwork() {
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
}

DiskSetup() {
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
    mkdir -p "$GEN"
    mount "$PART3" "$GEN"
    swapon "$PART2"
    mkdir -p "$GEN"/boot/efi/
    mount "$PART1" "$GEN"/boot/efi/
    lsblk
}

OpenRC() {
    echo "Acquiring stage file"
    wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/latest-stage3-amd64-openrc.txt
    STAGE_FILE="$(awk '/stage3/ {print $1}' latest-stage3-amd64-openrc.txt)"
    wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/"$STAGE_FILE"
    echo "Stage file acquired"
    echo "Extracting stage file"
    tar xpvf "$STAGE_FILE" --xattrs-include='*.*' --numeric-owner -C "$GEN"
    echo "Stage file has finished extracting!"
    echo "Done!"
}

SystemD() {
    echo "Acquiring stage file"
    wget https://gentoo.osuosl.org/releases/amd64/autobuilds/current-stage3-amd64-systemd/latest-stage3-amd64-systemd.txt
    STAGE_FILE="$(awk '/stage3/ {print $1}' latest-stage3-amd64-systemd.txt)"
    wget https://gentoo.osuosl.org/releases/amd64/autobuilds/current-stage3-amd64-systemd/"$STAGE_FILE"
    echo "Stage file acquired"
    echo "Extracting stage file"
    tar xpvf "$STAGE_FILE" --xattrs-include='*.*' --numeric-owner -C "$GEN"
    echo "Stage file has finished extracting!"
    echo "Done!"
}

MakeConf() {
    cp ./configs/make.conf "$GEN"/etc/portage/make.conf
    echo "MAKEOPTS=\"-j$(nproc) -l$(nproc)\"" >>"$GEN"/etc/portage/make.conf
    if [ "$INIT" = "openrc" ]; then
        echo "USE=\"-systemd\"" >>"$GEN"/etc/portage/make.conf
    fi
}

BinHostSetup() {
    cp ./configs/gentoobinhost.conf "$GEN"/etc/portage/binrepos.conf/gentoobinhost.conf
    echo "FEATURES=\"\${FEATURES} getbinpkg binpkg-request-signature\"" >>"$GEN"/etc/portage/make.conf
}

SetProfile() {
    if [ "$INIT" = "openrc" ]; then
        chroot "$GEN" /bin/bash <<'EOF'
# Eselect profile & Emerge syncing
echo "Setting OpenRC Profile"
eselect profile set "$(eselect profile list | awk ' NR==2 { print $2 } ')"
EOF
    else
        chroot "$GEN" /bin/bash <<'EOF'
# Eselect profile & Emerge syncing
echo "Setting SystemD Profile"
eselect profile set "$(eselect profile list | awk ' NR==2 { print $2 } ')/systemd"
EOF
    fi
}

InitialChroot() {
    chroot "$GEN" /bin/bash <<'EOF'
echo "Chrooted!"

# =====BEGINNING OF CHROOT ENVIRONMENT=====

# First Chroot Commands
echo "Sourcing /etc/profile"
source /etc/profile
export PS1="(Gentoo Chroot) ${PS1}"
echo "Mounting Boot"
echo "Running emerge-webrsync"
emerge-webrsync
echo "Done!"
EOF
    SetProfile
}

GitConfig() {
    cp ./configs/gentoo.conf "$GEN"
    chroot "$GEN" /bin/bash <<'EOF'
echo "Setting Git Sync"
emerge -v dev-vcs/git
rm -rf /var/db/repos/gentoo/
mkdir -p /etc/portage/repos.conf/
mv /gentoo.conf /etc/portage/repos.conf/gentoo.conf
emerge --sync
EOF
}

EmergeWorld() {
    chroot "$GEN" /bin/bash <<'EOF'
echo "Emerging @world"
emerge -vuUD --with-bdeps=y @world
EOF
}

InstallVim() {
    chroot "$GEN" /bin/bash <<'EOF'
emerge -v app-editors/vim
EOF
}

InstallNeovim() {
    chroot "$GEN" /bin/bash <<'EOF'
emerge -v app-editors/neovim
EOF
}

InstallNano() {
    chroot "$GEN" /bin/bash <<'EOF'
emerge -v app-editors/nano
EOF
}

InstallEmacs() {
    chroot "$GEN" /bin/bash <<'EOF'
emerge -v app-editors/emacs
EOF
}

# TODO: Correct the Locale Gen so that it takes user input and then updates timezone
LocaleGeneration() {
    chroot "$GEN" /bin/bash <<'EOF'
# Locale Generation
echo "Linking timezone information"
ln -sf /usr/share/zoneinfo/America/Indiana/Indianapolis /etc/localtime
echo "Setting locale"
grep -q '^en_US.UTF-8 UTF-8$' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
TARGET_LOCALE="en_US.UTF-8"
eselect locale set "$TARGET_LOCALE"
echo "Done!"
EOF
}

UpdateEnv() {
    chroot "$GEN" /bin/bash <<'EOF'
# Environment Update
echo "Updating environment"
sleep 1
env-update && source /etc/profile && export PS1="(Gentoo Chroot) $PS1"
echo "Done"
EOF
}

Firmware() {
    chroot "$GEN" /bin/bash <<'EOF'
# Firmware compilation
echo "Preparing for firmware compilation"
echo "sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE" | tee -a /etc/portage/package.license
echo "Done! Compiling firmware"
emerge -v sys-kernel/linux-firmware
eselect news read
echo "Done!"
EOF
}

GrubBootLoader() {
    chroot "$GEN" /bin/bash <<'EOF'
echo "Compiling grub bootloader"
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge -v sys-boot/grub efibootmgr
grub-install --efi-directory=/boot/efi
EOF
}

BinKernel() {
    chroot "$GEN" /bin/bash <<'EOF'
echo "Preparing for gentoo-bin kernel compilation"
echo "sys-kernel/installkernel dracut grub" >> /etc/portage/package.use/installkernel
emerge -v sys-kernel/installkernel
eselect news read
echo "Note: This command can take an excessive amount of time."
echo "That being said, please have no concern if it's lengthy."
echo "Beginning gentoo-bin kernel compilation now"
emerge --quiet sys-kernel/gentoo-kernel-bin
eselect news read
echo "Done!"
EOF
    GrubBootLoader
    chroot "$GEN" /bin/bash <<'EOF'
grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

CustomKernel() {
    chroot "$GEN" /bin/bash <<'EOF'
emerge -v sys-kernel/modprobed-db
emerge -v sys-kernel/gentoo-sources
EOF
}

Configurefstab() {
    DISK1="${DISK}1"
    DISK2="${DISK}2"
    DISK3="${DISK}3"
    cat >/root/temp/fstab <<FSTAB
$DISK1 /boot/efi vfat defaults 0 2
$DISK2 none swap sw 0 0
$DISK3 / ext4 noatime 0 1
FSTAB
    cp /root/temp/fstab "$GEN"
    chroot "$GEN" /bin/bash <<'EOF'
echo "Setting up fstab"
mv /fstab /etc/fstab
echo "Done!"
EOF
}

SetHosts() {
    cat >/root/temp/hosts <<HOSTS
127.0.0.1 $HNAME"
HOSTS
    mv /root/temp/hosts "$GEN"
    chroot "$GEN" /bin/bash <<'EOF'
cat /hosts >> /etc/hosts
rm /hosts
EOF
}

# TODO: Modify the function to correctly symlink the internet
ConfigureNetifrc() {
    net_name="$(ip route get 8.8.8.8 | awk '{print $5}')"
    SetHosts
    cat >/root/temp/net <<NET
config_$net_name="dhcp"
NET
    mv /root/temp/net "$GEN"
    chroot "$GEN" /bin/bash <<'EOF'
emerge -v net-misc/dhcpcd
eselect news read
emerge -v --noreplace net-misc/netifrc
eselect news read
cat /net >> /etc/conf.d/net
ln -s /etc/init.d/net.lo /etc/init.d/net.${NET_IF}
rc-update add net.${NET_IF} default
EOF
}

EnableNetworkManager() {
    if [ "$INIT" = "openrc" ]; then
        chroot "$GEN" /bin/bash <<'EOF'
rc-update add NetworkManager default
EOF
    else
        chroot "$GEN" /bin/bash <<'EOF'
systemctl enable NetworkManager
EOF
    fi
}

ConfigureNetworkManager() {
    SetHosts
    chroot "$GEN" /bin/bash <<'EOF'
emerge -v net-misc/networkmanager
EOF
    EnableNetworkManager
}

ConfigureSudo() {
    chroot "$GEN" /bin/bash <<'EOF'
echo "Emerging sudo"
emerge -v app-admin/sudo
echo "Configuring sudo"
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
EOF
}

ConfigureDoas() {
    chroot "$GEN" /bin/bash <<'EOF'
echo "Emerging doas"
emerge -v app-admin/doas
echo "Configuring doas"
echo "permit :wheel" | tee -a /etc/doas.conf
EOF
}

AddUser() {
    echo Adding user "$NEWUSER" with the following groups
    echo "users,wheel,video,audio,input"
    chroot "$GEN" /bin/bash <<EOF
useradd -m -G users,wheel,video,audio,input -s /bin/bash "$NEWUSER"
passwd "$NEWUSER"
"$PASSWD"
"$PASSWD"
EOF
}

# TODO: Add the option of kernel-open for the blackwell series GPUs of Nvidia
NvidiaDriver() {
    chroot "$GEN" /bin/bash <<'EOF'
echo "VIDEO_CARDS=\"nvidia\"" >> /etc/portage/make.conf
echo "x11-drivers/nvidia-drivers NVIDIA-2025" >> /etc/portage/package.license
emerge -v x11-drivers/nvidia-drivers
EOF
}

RootCheck
TestNetwork

mkdir -p /root/temp

echo "What is the current time?"
while true; do
    read -r -p "Please use MMDDhhmmYYYY format: " time_set
    echo "You have chosen the time to be:"
    date "$time_set"
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

echo "Next is your drive. Review this to find the drive you want to partition:"
lsblk
read -r -p "Please firmly state the end of your drive (example: nvme0 ) in lowercase: " disk_choice
DISK=/dev/"$disk_choice"
GEN=/mnt/gentoo
DiskSetup
echo "Would you like to use OpenRC or SystemD?"
echo "1. openrc"
echo "2. systemd"
while true; do
    read -r -p 'Please select the between 1 and 2: ' init_choice
    if [ "$init_choice" = "1" ]; then
        INIT="openrc"
        OpenRC
        break
    elif [ "$init_choice" = "2" ]; then
        SystemD
        INIT="systemd"
        break
    else
        echo "Invalid Input"
    fi
done
MakeConf

echo "Would you like to have a binhost? : Reduces compile overhead by installed prebuilt binaries"
while true; do
    read -r -p 'Please answer Y/N: ' bin_host
    if [ "$bin_host" = "y" ] || [ "$bin_host" = "Y" ]; then
        BinHostSetup
        echo "Binhost setup successful"
        break
    elif [ "$bin_host" = "n" ] || [ "$bin_host" = "N" ]; then
        echo "Binhost not configured"
        break
    else
        echo "Invalid Input"
    fi
done

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
InitialChroot

echo "Would you like to sync via git instead of rsync?"
echo "Note: Some networks blocks rsync ports causing issues with syncing to portage tree."
echo "Note: git is sometimes faster than rsync"
while true; do
    read -r -p "Please answer [Y/N]: " sync_choice
    if [ "$sync_choice" = "y" ] || [ "$sync_choice" = "Y" ]; then
        GitConfig
        echo "Git Setup Successful"
        break
    elif [ "$sync_choice" = "n" ] || [ "$sync_choice" = "N" ]; then
        echo "Using Rsync for syncing"
        break
    else
        echo "Invalid Input"
    fi
done

echo "Would you like to emerge @world?"
echo "This is optional, but HIGHLY recommended."
echo "Note: The time this command takes varies."
while true; do
    read -r -p "Please answer [Y/N]: " world_choice
    if [ "$world_choice" = "y" ] || [ "$world_choice" = "Y" ]; then
        EmergeWorld
        break
    elif [ "$world_choice" = "n" ] || [ "$world_choice" = "N" ]; then
        echo "Will not emerge @world"
        break
    else
        echo "Invalid input."
    fi
done

chroot "$GEN" /bin/bash <<'EOF'
eselect news read
echo "Done!"
EOF

echo "You have the choice of 4 popular text editors"
echo 'if your prefered option is not listed, please firmly state "none"'
echo "1. nano"
echo "2. vim"
echo "3. neovim"
echo "4. emacs"
echo "5. none"
while true; do
    read -r -p "Please enter choice from 1 to 5: " text_choice
    if [ "$text_choice" = "3" ]; then
        InstallNeovim
        break
    elif [ "$text_choice" = "2" ]; then
        InstallVim
        break
    elif [ "$text_choice" = "1" ]; then
        InstallNano
        break
    elif [ "$text_choice" = "4" ]; then
        InstallEmacs
        break
    elif [ "$text_choice" = "5" ]; then
        break
    else
        echo "Invalid input. Your choices must be one of the following choices:"
        echo "1. nano"
        echo "2. vim"
        echo "3. neovim"
        echo "4. emacs"
        echo "5. none"
    fi
done

LocaleGeneration
UpdateEnv
Firmware

echo "Do you wish to use your own kernel? Or the gentoo-bin kernel?"
while true; do
    read -r -p 'Please state "1" for your own kernel, or "2" for the gentoo-bin kernel: ' kernel_choice
    if [ "$kernel_choice" = "2" ]; then
        BinKernel
        break
    elif [ "$kernel_choice" = "1" ]; then
        echo "Understood, own kernel. Emerging necessary tools"
        CustomKernel
        echo "Seeing as you are building your own kernel,"
        echo "would you like for grub to be installed but unconfigured?"
        read -r -p "Please answer Y/N: " own_kernel_choice
        if [ "$own_kernel_choice" = "y" ] || [ "$own_kernel_choice" = "Y" ]; then
            echo "Got it, emerging grub bootloader"
            GrubBootLoader
            break
        elif [ "$own_kernel_choice" = "n" ] || [ "$own_kernel_choice" = "N" ]; then
            echo "Got it. A bootloader will NOT be installed"
            break
        fi
    else
        echo "Invalid input."
    fi
done

Configurefstab
read -r -p "Please state your preferred hostname: " hname_choice
echo You have chosen the hostname "$hname_choice"
chroot "$GEN" /bin/bash <<EOF
echo hostname="$hname_choice" | tee -a /etc/conf.d/hostname
EOF
echo "Done!"
HNAME="$hname_choice"

if [ "$INIT" = "openrc" ]; then
    echo "Choose a Network Manager for your system"
    echo "1. Netifrc (Native)"
    echo "2. NetworkManager"
    while true; do
        read -r -p 'Please state your selection between 1 and 2: ' net_choice
        if [ "$net_choice" = "1" ]; then
            echo "Setting up Netifrc as Network Manager"
            ConfigureNetifrc
            echo "Done"
            break
        elif [ "$net_choice" = "2" ]; then
            echo "Setting up Network Manager"
            ConfigureNetworkManager
            echo "Done"
            break
        else
            echo "Invalid Input"
        fi
    done
else
    ConfigureNetworkManager
fi

echo "What is your preferred privilege escalation tool?"
echo "Do you prefer Doas, or Sudo?"
while true; do
    read -r -p "Please cleanly state doas or sudo in lowercase for your selection: " sudo_choice
    if [ "$sudo_choice" = "sudo" ]; then
        ConfigureSudo
        break
    elif [ "$sudo_choice" = "doas" ]; then
        ConfigureDoas
        break
    else
        echo "Invalid input. Please enter sudo or doas."
    fi
done

chroot "$GEN" /bin/bash <<'EOF'

# Grub boot loader config
if [ "$kernel_choice" = "2" ]; then
grub-mkconfig -o /boot/grub/grub.cfg
fi
EOF

read -r -p "Please create a username for the user: " NEWUSER
read -r -p "Please enter the password for the user: " PASSWD
AddUser

# TODO: Add the options of igpu
echo "What kind of GPU do you have?"
while true; do
    read -r -p 'Please state "nvidia" or "amd" in lowercase: ' gpu_choice
    if [ "$gpu_choice" = "nvidia" ]; then
        echo "Got it. Emerging necessary drivers"
        NvidiaDriver
        echo "Done"
        break
    elif [ "$gpu_choice" = "amd" ]; then
        # TODO: Add a function which adds the VIDEO_CARDS variable in the make.conf for better clarity to the portage
        echo "Got it. proceeding"
        break
    else
        echo "Invalid input."
    fi
done

# TODO: For SystemD it is necessary to implement the extra machine-id and configurations

echo "Leaving Chroot environment"
# =====END OF CHROOT ENVIRONMENT=====

rm -rf /root/temp

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
