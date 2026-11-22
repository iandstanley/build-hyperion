#!/usr/bin/env bash
# ==============================================================================
# Script Name:   setup_mainframe_dev.sh
# Description:   Installs Debian-native equivalents of classic IBM mainframe
#                compilers, 3270 terminal emulators, XEDIT/ISPF clones, and
#                workflow utilities for MVS 3.8J & VM/370CE development, and
#                configures shell aliases, .therc, and .vimrc for 'ibm' & 'ian'.
#
# Installed Compilers & Mainframe Compatibility Notes:
# ------------------------------------------------------------------------------
# 1. gfortran (GNU Fortran) -> aliased as 'f77'
#    - Mainframe Target: IBM FORTRAN IV (FORTRAN G / FORTRAN H / WATFIV)
#    - Compatibility:    High with '-std=legacy -fno-automatic'. Enforces static
#                        variable allocation (retaining values across calls
#                        without SAVE) and supports 80-col fixed-form layout.
#
# 2. regina-rexx (Regina REXX Interpreter)
#    - Mainframe Target: BREXX / BREXX-370 (VM/370CE & MVS 3.8J)
#    - Compatibility:    Very High. Implements classic procedural REXX (TRL2 /
#                        ANSI X3.274-1996) matching BREXX without OO extensions.
#
# 3. marst (GNU MARST Algol-to-C Translator) -> aliased as 'algol60'
#    - Mainframe Target: OS Algol F / Algol W (MVS 3.8J & VM/370CE)
#    - Compatibility:    High. Implements Revised Report on ALGOL 60. Translates
#                        .alg to .c (compile output with: gcc file.c -lalgol -lm).
#
# 4. fp-compiler (Free Pascal Compiler) -> aliased as 'pascal'
#    - Mainframe Target: Stanford Pascal / Pascal/VS (VM/370CE)
#    - Compatibility:    High with '-Miso'. Enforces ISO 7185 / Wirth Pascal
#                        rules and blocks modern Delphi/Turbo extensions.
#
# 5. gnucobol (GnuCOBOL Compiler) -> aliased as 'cobol'
#    - Mainframe Target: MVT COBOL / IKFCBL00 (ANS COBOL 1968/1974 on MVS 3.8J)
#    - Compatibility:    High with '-std=ibm -fixed'. Enforces 80-column card
#                        margins (Cols 1-6 seq, Col 7 ind, 8-11 A, 12-72 B).
#
# Installed 3270, Editor & Workflow Tools:
# ------------------------------------------------------------------------------
# 6. ibm-3270 Suite (c3270, x3270, xfonts-x3270-misc, s3270, pr3287)
#    - Terminal emulators (curses, X11, scriptable) with IND$FILE transfer
#      support and 3287 network printer daemon for Hercules TN3270 ports.
#
# 7. the (The Hessling Editor) -> aliased as 'xedit'
#    - VM/CMS XEDIT & KEDIT clone with REXX macro support and prefix commands.
#      Configured via ~/.therc to boot into IBM XEDIT compatibility mode.
#
# 8. lspf (Linux ISPF Clone, built from GitHub) -> aliased as 'ispf'
#    - Full MVS ISPF/PDF clone (Option 2 Edit, Option 3.4 DSLIST, split screen).
#
# 9. Utilities (netcat-openbsd, iconv [built-in], tmux, screen, vim)
#    - Socket JCL submission (nc localhost 3505 < job.jcl), EBCDIC conversion
#      (iconv -f UTF-8 -t IBM1047), session multiplexing, and ruler-guided Vim.
# ==============================================================================

set -euo pipefail

# Verify root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with root privileges."
   echo "Usage: sudo bash $0"
   exit 1
fi

echo "=== 1. Updating Debian package index and installing APT packages ==="
apt-get update

# Install compilers, 3270 tools, XEDIT clone, multiplexers, Vim, and lspf build deps
# Note: 'iconv' is already pre-installed on Debian via 'libc-bin'
apt-get install -y \
    gfortran \
    regina-rexx \
    marst \
    fp-compiler \
    gnucobol \
    c3270 \
    x3270 \
    xfonts-x3270-misc \
    s3270 \
    pr3287 \
    the \
    the-doc \
    netcat-openbsd \
    tmux \
    screen \
    vim \
    git \
    g++ \
    make \
    libncurses-dev \
    libboost-all-dev \
    libmagic-dev

echo "=== 2. Building and installing lspf (ISPF Clone) from GitHub ==="
if [[ ! -d /opt/lspf ]]; then
    git clone https://github.com /opt/lspf
    pushd /opt/lspf/src > /dev/null
    # Point lspf's system path to /opt/lspf so all users share panels/messages
    sed -i 's|#define ZSYSPATH .*|#define ZSYSPATH "/opt/lspf"|g' lspf.h
    ./compsetup
    ./setup
    ./comp1
    pushd /opt/lspf/src/Apps > /dev/null
    ./compapps
    popd > /dev/null
    popd > /dev/null
    # Symlink binary into /usr/local/bin so it is available system-wide
    ln -sf /opt/lspf/src/lspf /usr/local/bin/lspf
    echo "lspf built and installed to /usr/local/bin/lspf"
else
    echo "/opt/lspf already exists — skipping lspf build."
fi

echo "=== 3. Configuring aliases, .therc, and .vimrc for 'ibm' and 'ian' ==="

# --- Bash Aliases (~/.bashrc) ---
BASH_ALIASES=$(cat << 'EOF'

# --- Mainframe Development Aliases ---
alias algol60='marst'
alias pascal='fpc -Miso'
alias cobol='cobc -std=ibm -fixed'
alias f77='gfortran -std=legacy -fno-automatic'
alias xedit='the'
alias ispf='lspf'
EOF
)

# --- Csh/Tcsh Aliases (~/.cshrc) ---
CSH_ALIASES=$(cat << 'EOF'

# --- Mainframe Development Aliases ---
alias algol60 'marst'
alias pascal 'fpc -Miso'
alias cobol 'cobc -std=ibm -fixed'
alias f77 'gfortran -std=legacy -fno-automatic'
alias xedit 'the'
alias ispf 'lspf'
EOF
)

# --- Default XEDIT Compatibility Profile (~/.therc) ---
DEFAULT_THERC=$(cat << 'EOF'
* Default THE (The Hessling Editor) Profile for IBM VM/CMS XEDIT Compatibility
'set compat xedit xedit xedit'
'set case mixed ignore'
'set number on'
'set prefix on left'
'set scale on 2'
'set curline on 3'
'set msgline on 2 1 overlay'
'set cmdline bottom'
'set hexshow on'
'set autosave 10'
EOF
)

# --- Vim Mainframe Column Rulers (~/.vimrc) ---
# Sets visual column guides based on file extension:
#   - COBOL (.cob, .cbl): Col 7 (indicator), Col 8 (Area A), Col 12 (Area B), Col 73 (Seq end)
#   - FORTRAN (.f, .for, .f77): Col 6 (continuation), Col 7 (statement start), Col 73 (Seq end)
#   - JCL (.jcl): Col 3 (// operand area), Col 16 (continuation area), Col 72 (continuation flag)
VIM_MAINFRAME_CONFIG=$(cat << 'EOF'

" --- Mainframe Fixed-Column Rulers & Settings ---
if has("autocmd")
  augroup MainframeColumns
    autocmd!
    " Detect .f77 and .jcl extensions explicitly
    autocmd BufNewFile,BufRead *.f77 setfiletype fortran
    autocmd BufNewFile,BufRead *.jcl setfiletype jcl

    " COBOL (.cob, .cbl): Cols 7, 8, 12, and 73 (beyond 72 is ignored by compiler)
    autocmd FileType cobol setlocal colorcolumn=7,8,12,73 textwidth=72 expandtab tabstop=4 shiftwidth=4

    " FORTRAN IV/77 (.f, .for, .f77): Col 6 (cont), Col 7 (code), Col 73 (seq)
    autocmd FileType fortran let b:fortran_fixed_source=1 | setlocal colorcolumn=6,7,73 textwidth=72 expandtab tabstop=6 shiftwidth=6

    " JCL (.jcl): Col 3 (after //), Col 16 (max operand start), Col 72 (cont flag), Col 73 (seq)
    autocmd FileType jcl setlocal colorcolumn=3,16,72,73 textwidth=71 expandtab tabstop=2 shiftwidth=2
  augroup END
endif
EOF
)

for TARGET_USER in ibm ian; do
    if ! id "$TARGET_USER" &>/dev/null; then
        echo "Warning: User '$TARGET_USER' does not exist on this system. Skipping."
        continue
    fi

    USER_GROUP=$(id -gn "$TARGET_USER")
    USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

    BASHRC="$USER_HOME/.bashrc"
    CSHRC="$USER_HOME/.cshrc"
    THERC="$USER_HOME/.therc"
    VIMRC="$USER_HOME/.vimrc"

    # 1. Append Bash aliases if not already present
    touch "$BASHRC"
    if ! grep -q "Mainframe Development Aliases" "$BASHRC"; then
        echo "$BASH_ALIASES" >> "$BASHRC"
        echo "[$TARGET_USER] Added Bash aliases to $BASHRC"
    else
        echo "[$TARGET_USER] Bash aliases already exist in $BASHRC — skipping."
    fi
    chown "$TARGET_USER":"$USER_GROUP" "$BASHRC"

    # 2. Append Csh aliases if not already present
    touch "$CSHRC"
    if ! grep -q "Mainframe Development Aliases" "$CSHRC"; then
        echo "$CSH_ALIASES" >> "$CSHRC"
        echo "[$TARGET_USER] Added Csh aliases to $CSHRC"
    else
        echo "[$TARGET_USER] Csh aliases already exist in $CSHRC — skipping."
    fi
    chown "$TARGET_USER":"$USER_GROUP" "$CSHRC"

    # 3. Create default ~/.therc if it does not already exist
    if [[ ! -f "$THERC" ]]; then
        echo "$DEFAULT_THERC" > "$THERC"
        chown "$TARGET_USER":"$USER_GROUP" "$THERC"
        echo "[$TARGET_USER] Created default XEDIT profile at $THERC"
    else
        echo "[$TARGET_USER] $THERC already exists — preserving existing file."
    fi

    # 4. Append Vim mainframe column markers if not already present
    touch "$VIMRC"
    if ! grep -q "Mainframe Fixed-Column Rulers" "$VIMRC"; then
        echo "$VIM_MAINFRAME_CONFIG" >> "$VIMRC"
        echo "[$TARGET_USER] Added mainframe column markers to $VIMRC"
    else
        echo "[$TARGET_USER] Mainframe column markers already exist in $VIMRC — skipping."
    fi
    chown "$TARGET_USER":"$USER_GROUP" "$VIMRC"
done

echo "=== Setup Complete! ==="
echo "Users 'ibm' and 'ian' should run 'source ~/.bashrc' (or 'source ~/.cshrc')"
echo "or start a new login session to activate the new aliases."

