# Genstaller v1.2.10
Patch Notes:
- Fixed an issue where net_name wasn't set properly.

# Genstaller v1.2.9
Patch Notes:
- Fixed an issue where hostname didn't work in networking.
- Fixed the issue with nvidia drivers being masked.
- Fixed the kernel choice being slightly repetitive when a choice other than "1" or "2" is made.

# Genstaller v1.2.8
Patch Notes:
- Fixed variables not carrying over due to improper quotation all over the script, this includes the user config issues.

# Genstaller v1.2.7
Patch Notes:
- Fixed an issue where the script would crash while setting up networking for systemd.
- Fixed the user configuration not recognizing variables AGAIN.

# Genstaller v1.2.6
Patch Notes:
- Fixed an issue where selecting systemd would make the script crash due to networking still being entirely done under openrc.

# Genstaller v1.2.5
Patch Notes:
- Fixed an issue where selecting systemd would lead to the script crashing due to use flag conflicts.

# Genstaller v1.2.4
Patch Notes:
- Fixed an issue that caused the stage file to loop indefinitely.
- Fixed an issue with setting the date where it would result in a script crash due to a syntax error.

# Genstaller v1.2.3
Update Notes:
- Added a SystemD option instead of only having OpenRC. Both are AMD64.
- Added a choice for Nvidia or Amd graphics.
- Added a choice to set the date at the beginning the script after the root check and networking check.
- Added support for all devices. Vda, NVMe, sda, usb, etc... no longer bound to only 2 choices.
- Fixed the text editor choice not recognizing "none" as an option
- Fixed the fstab configuration not being positioned properly
- Fixed the Hostname configuration being repetative in what it prints into the console
- Fixed both Username and Hostname variables not being detected properly
- Fixed networking incorrectly implementing the Hostname variable
- Fixed the text editor choice to be more clear
- Fixed an issue where choosing to install your own kernel with no grub would cause the script to crash due to a syntax error
