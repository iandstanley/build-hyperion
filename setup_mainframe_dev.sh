#!/usr/bin/env bash
# ==============================================================================
# Script Name:   setup_mainframe_dev.sh
# Description:   Installs Debian-native equivalents of classic IBM mainframe
#                compilers/interpreters (found in MVS 3.8J & VM/370CE) and
#                configures shell aliases for users 'ibm' and 'ian'.
#
# Installed Compilers & Mainframe Compatibility Notes:
# ------------------------------------------------------------------------------
# 1. gfortran (GNU Fortran)
#    - Mainframe Target: IBM FORTRAN IV (FORTRAN G / FORTRAN H / WATFIV)
#    - Compatibility:    High when invoked with '-std=legacy -fno-automatic'.
#                        Supports fixed-form 80-column card layout (Cols 1-72),
#                        Hollerith constants, and arithmetic IF statements.
#                        '-fno-automatic' enforces static variable allocation
#                        (retaining local variable state across subroutine calls
#                        even without explicit SAVE statements, matching IBM's
#                        S/370 FORTRAN compilers).
#
# 2. regina-rexx (Regina REXX Interpreter)
#    - Mainframe Target: BREXX / BREXX-370 (VM/370CE & MVS 3.8J)
#    - Compatibility:    Very High. Both Regina and BREXX implement classic
#                        procedural REXX (TRL2 / ANSI X3.274-1996) without OO
#                        extensions. Avoid Regina-specific STREAM() I/O in
#                        shared scripts, as VM/370 CMS uses EXECIO instead.
#
# 3. marst (GNU MARST Algol-to-C Translator)
#    - Mainframe Target: OS Algol F / Algol W (MVS 3.8J & VM/370CE)
#    - Compatibility:    High. Implements the Revised Report on ALGOL 60
#                        (unlike ALGOL 68). Supports block structure and
#                        call-by-name semantics; standard I/O procedure names
#                        (inreal/outreal vs. INSYMBOL/OUTREAL) require minor
#                        adaptation when porting between Linux and S/370.
#                        * Note: MARST translates .alg source into .c files,
#                          which must then be compiled with gcc and linked with
#                          '-lalgol -lm'.
#
# 4. fp-compiler (Free Pascal Compiler)
#    - Mainframe Target: Stanford Pascal / Pascal/VS (VM/370CE)
#    - Compatibility:    High when invoked with '-Miso'. Enforces ISO 7185 /
#                        classic Wirth Pascal rules, nested procedures, and
#                        standard INPUT/OUTPUT program headers while blocking
#                        modern Delphi/Turbo Pascal extensions that fail on S/370.
#
# 5. gnucobol (GnuCOBOL Compiler)
#    - Mainframe Target: MVT COBOL / IKFCBL00 (ANS COBOL 1968/1974 on MVS 3.8J)
#    - Compatibility:    High when invoked with '-std=ibm -fixed'. Enforces
#                        strict 80-column punch-card margins (Cols 1-6 sequence,
#                        Col 7 indicator, Cols 8-11 Area A, Cols 12-72 Area B,
#                        Cols 73-80 ignored) and IBM dialect syntax rules.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status (-e),
# treat unset variables as an error (-u), and fail pipelines if any stage fails (-o pipefail).
set -euo pipefail

# Verify the script is being run with root privileges (required for apt-get and editing other users' files)
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with root privileges."
   echo "Usage: sudo bash $0"
   exit 1
fi

echo "=== 1. Updating Debian package index and installing compilers ==="
# Refresh local APT package cache
apt-get update

# Install the selected compilers/interpreters non-interactively (-y)
apt-get install -y \
    gfortran \
    regina-rexx \
    marst \
    fp-compiler \
    gnucobol

echo "=== 2. Configuring shell aliases for users 'ibm' and 'ian' ==="

# Define the alias block for Bash (~/.bashrc).
# Note: Bash uses an '=' sign between the alias name and its command string.
BASH_ALIASES=$(cat << 'EOF'

# --- Mainframe Development Aliases ---
# Maps 'algol60' to the GNU MARST Algol 60 translator
alias algol60='marst'
# Compiles Pascal in strict ISO 7185 mode (closest to VM/370 Stanford Pascal)
alias pascal='fpc -Miso'
# Compiles COBOL using IBM dialect rules and fixed 80-column card format
alias cobol='cobc -std=ibm -fixed'
# Compiles FORTRAN in legacy mode with static local variable storage
alias f77='gfortran -std=legacy -fno-automatic'
EOF
)

# Define the alias block for C Shell / TENEX C Shell (~/.cshrc).
# Note: Csh/Tcsh uses a space (no '=' sign) between the alias name and command string.
CSH_ALIASES=$(cat << 'EOF'

# --- Mainframe Development Aliases ---
# Maps 'algol60' to the GNU MARST Algol 60 translator
alias algol60 'marst'
# Compiles Pascal in strict ISO 7185 mode (closest to VM/370 Stanford Pascal)
alias pascal 'fpc -Miso'
# Compiles COBOL using IBM dialect rules and fixed 80-column card format
alias cobol 'cobc -std=ibm -fixed'
# Compiles FORTRAN in legacy mode with static local variable storage
alias f77 'gfortran -std=legacy -fno-automatic'
EOF
)

# Loop through each target developer account
for TARGET_USER in ibm ian; do
    # Check if the user account exists on the Debian system before proceeding
    if ! id "$TARGET_USER" &>/dev/null; then
        echo "Warning: User '$TARGET_USER' does not exist on this system. Skipping."
        continue
    fi

    # Look up the user's primary group and home directory from /etc/passwd via NSS
    USER_GROUP=$(id -gn "$TARGET_USER")
    USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

    BASHRC="$USER_HOME/.bashrc"
    CSHRC="$USER_HOME/.cshrc"

    # --- Configure Bash (~/.bashrc) ---
    # Create .bashrc if it does not already exist
    touch "$BASHRC"
    # Check for the header marker to make this script idempotent (safe to run multiple times)
    if ! grep -q "Mainframe Development Aliases" "$BASHRC"; then
        echo "$BASH_ALIASES" >> "$BASHRC"
        echo "Added Bash aliases to $BASHRC"
    else
        echo "Bash aliases already present in $BASHRC — skipping."
    fi
    # Restore proper ownership so root does not own the user's rc file
    chown "$TARGET_USER":"$USER_GROUP" "$BASHRC"

    # --- Configure Csh (~/.cshrc) ---
    # Create .cshrc if it does not already exist
    touch "$CSHRC"
    # Prevent duplicate entries if the script is re-run
    if ! grep -q "Mainframe Development Aliases" "$CSHRC"; then
        echo "$CSH_ALIASES" >> "$CSHRC"
        echo "Added Csh aliases to $CSHRC"
    else
        echo "Csh aliases already present in $CSHRC — skipping."
    fi
    # Restore proper ownership so root does not own the user's rc file
    chown "$TARGET_USER":"$USER_GROUP" "$CSHRC"
done

echo "=== Setup Complete! ==="
echo "Next steps: Have 'ibm' and 'ian' run 'source ~/.bashrc' (or 'source ~/.cshrc')"
echo "or start a new login session to activate the new aliases."

