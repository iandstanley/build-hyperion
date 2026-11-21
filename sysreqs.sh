#!/bin/sh -v
set -e

# Ensure sbin directories are in PATH when using plain 'su' on Debian
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Verify the script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

echo "Updating package lists..."
apt-get update

echo "Installing git, sudo, wget, and curl..."
apt-get install -y git sudo wget curl mc ed tree 

echo "Configuring 'ian' as a sudoer..."
if id "ian" >/dev/null 2>&1; then
    usermod -aG sudo ian
    echo "Success: 'ian' has been added to the sudo group."
else
    echo "Error: User 'ian' does not exist." >&2
    exit 1
fi

git config --global user.name "Ian Stanley"
git config --global user.email "iandstanley@gmail.com"

echo "Base setup complete. Note: 'ian' will need to log out and back in for sudo group membership to take effect."
