Genstaller v1.2.3
Update Notes:
- Added a SystemD option instead of only having OpenRC. Both are AMD64.
- Added a choice for Nvidia or Amd graphics
- Added a choice to set the date at the beginning the script after the root check and networking check.
- Added support for all devices. Vda, NVMe, sda, usb, etc... no longer bound to only 2 choices.
Patch Notes:
- Fixed the text editor choice not recognizing "none" as an option
- Fixed the fstab configuration not being positioned properly
- Fixed the Hostname configuration being repetative in what it prints into the console
- Fixed both Username and Hostname variables not being detected properly
- Fixed networking incorrectly implementing the Hostname variable
- Fixed the text editor choice to be more clear
- Fixed an issue where choosing to install your own kernel with no grub would cause the script to crash due to a syntax error
