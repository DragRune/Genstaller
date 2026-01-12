# Genstaller
Genstaller is a Gentoo Linux installer script I've been working on for about a week now. 
Still in heavy development, and feedback/recommendations are heavily appreciated!

About the script:

Currently there are about 23 total main sections as of v1.2.3
in order, the sections are as follows:

set the date,
wipe the specified drive,
partition the specified drive,
format the specified drive's partitions,
mount the partitions,
acquire the most recent stage file (currently between OpenRC and SystemD) as of v1.2.3,
chroot,
source profile, mount boot partition, and emerge-webrsync,
eselect profile,
choice to emerge @world,
choice between 4 popular text editors or none,
locale generation & environment update,
firmware compilation,
choice of own kernel compilation or gentoo-dist kernel compilation,
unconfigured grub for own kernel, and grub for gentoo-dist kernel,
fstab configuration,
hostname configuration,
networking configuration,
a choice between "sudo" or "doas" or a permission elevation command,
user configuration,
and graphics drivers compilation and configuration.

Currently, i have not found a reliable way to make it available in the script for the user to set a root passwd or user passwd within the chroot environment.

If there are any questions, feel free to ask me personally on my discord: real_djkevin
