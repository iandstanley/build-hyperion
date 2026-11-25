#!/bin/sh -v
set -e

# Ensure the script is NOT run as root (should be run as 'ian' using sudo)
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Do not run this script as root. Run it as 'ian' (it uses sudo internally)." >&2
    exit 1
fi

# Navigate to the directory where this script lives (~/projects/build-hyperion)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Step 1: Checking and updating the 'hyperion' git submodule ==="
git submodule status
git submodule update --init --recursive

if [ ! -d "hyperion" ] || [ -z "$(ls -A hyperion)" ]; then
    echo "Error: The 'hyperion' submodule directory is empty or missing." >&2
    exit 1
fi

echo "=== Step 2: Checking for Release Notes ==="
ls -la hyperion/RELEASE* hyperion/README* 2>/dev/null || true

echo "=== Step 3: Installing Debian build dependencies and Regina REXX ==="
sudo apt-get update
sudo apt-get -y install \
    git wget time \
    build-essential cmake flex gawk m4 autoconf automake \
    libtool-bin libltdl-dev \
    libbz2-dev zlib1g-dev \
    libcap2-bin \
    libregina3-dev \
    ncurses-base ncurses-bin ncurses-doc ncurses-hexedit ncurses-term

echo "=== Step 4: Verifying package and compiler versions (bldlvlck) ==="
cd hyperion
if [ -x "./util/bldlvlck" ]; then
    ./util/bldlvlck
else
    echo "Warning: ./util/bldlvlck not found or not executable."
fi

echo "=== Build prerequisites complete! ==="

