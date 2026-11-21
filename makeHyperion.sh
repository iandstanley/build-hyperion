#!/bin/sh
set -e

# Ensure the script is NOT run as root (should be run as 'ian' using sudo when needed)
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: Do not run this script as root. Run it as 'ian' (it uses sudo internally for install)." >&2
    exit 1
fi

# Helper function to pause and wait for user confirmation
pause_step() {
    printf "\n>>> %s\n" "$1"
    printf "Press [Enter] to continue, or Ctrl+C to abort... "
    read -r _
}

# Navigate to the hyperion submodule directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYPERION_DIR="$SCRIPT_DIR/hyperion"

if [ ! -d "$HYPERION_DIR" ] || [ ! -x "$HYPERION_DIR/configure" ]; then
    echo "Error: '$HYPERION_DIR/configure' not found. Did you run ./buildreqs.sh first?" >&2
    exit 1
fi

cd "$HYPERION_DIR"

echo "=== Step 6: Configuring Hercules for Intel Linux ==="
./configure
pause_step "Step 6 (./configure) complete. Scroll up to inspect the configuration summary."

CORES="$(nproc)"
echo "=== Step 7: Building Hercules using $CORES CPU cores ==="
make -j"$CORES"
pause_step "Step 7 (make -j$CORES) complete. Scroll up to verify there were no build errors."

echo "=== Step 8: Installing Hercules system-wide (sudo make install) ==="
sudo make install
pause_step "Step 8 (sudo make install) complete."

echo "=== Build and installation complete! ==="
echo "You can verify the installation by running: hercules --help=version"

