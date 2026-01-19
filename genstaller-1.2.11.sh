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

GetTime() {
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
}

# TODO: Modify this so that we don't take input inside the function
DiskSetup() {
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

    #TODO: Send the below part outside the function to global scope

    # Mounting Partitions + Making /mnt/gentoo
    GEN=/mnt/gentoo
    mkdir -p "$GEN"
    mount "$PART3" "$GEN"
    swapon "$PART2"
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
    echo "Writing make.conf"
    echo 'USE="-systemd elogind dbus X harfbuzz"' | tee -a "$GEN"/etc/portage/make.conf
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
    echo "Writing make.conf"
    echo 'USE="systemd dbus X harfbuzz"' | tee -a "$GEN"/etc/portage/make.conf
    echo "Done!"
}

MakeConf() {
    echo 'MAKEOPTS="-j8 -l9"' | tee -a "$GEN"/etc/portage/make.conf
}
