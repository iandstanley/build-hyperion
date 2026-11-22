#!/usr/bin/env bash
# ==============================================================================
# Script Name:   setup_mainframe_dev.sh
# Description:   Installs Debian-native equivalents of classic IBM mainframe
#                compilers, 3270 terminal emulators, XEDIT/ISPF clones, and
#                workflow utilities for MVS 3.8J & VM/370CE development,
#                builds GNU MARST, THE (The Hessling Editor), and lspf from
#                source, installs check80/pad80/submitjcl into /usr/local/bin,
#                and configures shell aliases, EBCDIC helpers, .therc, and
#                .vimrc for 'ibm' & 'ian'.
# ==============================================================================

set -euo pipefail

# Verify root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run with root privileges."
   echo "Usage: sudo bash $0"
   exit 1
fi

# Determine the invoking user and their home directory (even when run via sudo)
BUILD_USER="${SUDO_USER:-$USER}"
BUILD_HOME=$(getent passwd "$BUILD_USER" | cut -d: -f6)

echo "=== 1. Updating Debian package index and installing APT packages ==="
apt-get update

# Install compilers, 3270 tools, build/debug utilities, archive tools, and library deps
# Note: 'iconv' and 'dd' are pre-installed on Debian via 'libc-bin' and 'coreutils'
apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    gdb \
    gfortran \
    regina-rexx \
    libregina3-dev \
    fp-compiler \
    gnucobol \
    c3270 \
    x3270 \
    xfonts-x3270-misc \
    s3270 \
    pr3287 \
    curl \
    tar \
    gzip \
    unzip \
    netcat-openbsd \
    tmux \
    screen \
    vim \
    git \
    g++ \
    make \
    m4 \
    xxd \
    hexedit \
    gawk \
    dos2unix \
    ripgrep \
    fd-find \
    mc \
    rlwrap \
    shellcheck \
    python3 \
    python3-venv \
    libncurses-dev \
    libboost-all-dev \
    libmagic-dev

echo "=== 2. Building and installing GNU MARST (Algol 60) into /usr/local ==="
MARST_URL="https://www.mirrorservice.org/sites/ftp.gnu.org/gnu/marst/marst-2.8.tar.gz"
MARST_BUILD_DIR="$BUILD_HOME/marst-build"

if ! command -v marst &>/dev/null; then
    trap 'rm -rf "$MARST_BUILD_DIR"' EXIT

    rm -rf "$MARST_BUILD_DIR"
    echo "Downloading and extracting $MARST_URL into $MARST_BUILD_DIR as user '$BUILD_USER'..."
    sudo -u "$BUILD_USER" mkdir -p "$MARST_BUILD_DIR"
    sudo -u "$BUILD_USER" bash -c "
        set -euo pipefail
        cd '$MARST_BUILD_DIR'
        curl -fsSL '$MARST_URL' -o marst-2.8.tar.gz
        tar -xzf marst-2.8.tar.gz --strip-components=1
        ./configure
        make
    "

    echo "Installing GNU MARST into /usr/local..."
    make -C "$MARST_BUILD_DIR" install
    ldconfig

    rm -rf "$MARST_BUILD_DIR"
    trap - EXIT
    echo "GNU MARST installed to $(command -v marst) and build directory removed."
else
    echo "marst is already installed at $(command -v marst) — skipping GNU MARST build."
fi

echo "=== 3. Building and installing THE (The Hessling Editor) into /usr/local ==="
THE_URL="https://sourceforge.net/projects/hessling-editor/files/hessling-editor/4.0/thesrc40.zip/download"
THE_BUILD_DIR="$BUILD_HOME/the-build"

if ! command -v the &>/dev/null; then
    trap 'rm -rf "$THE_BUILD_DIR"' EXIT

    rm -rf "$THE_BUILD_DIR"
    echo "Downloading and extracting $THE_URL into $THE_BUILD_DIR as user '$BUILD_USER'..."
    sudo -u "$BUILD_USER" mkdir -p "$THE_BUILD_DIR"
    sudo -u "$BUILD_USER" bash -c "
        set -euo pipefail
        cd '$THE_BUILD_DIR'
        curl -fsSL '$THE_URL' -o thesrc40.zip
        unzip -q thesrc40.zip
        mkdir -p build
        cd build
        ../configure --with-rexx=regina --with-curses=ncurses
        make
    "

    echo "Installing THE (The Hessling Editor) into /usr/local..."
    make -C "$THE_BUILD_DIR/build" install
    ldconfig

    rm -rf "$THE_BUILD_DIR"
    trap - EXIT
    echo "THE installed to $(command -v the) and build directory removed."
else
    echo "the is already installed at $(command -v the) — skipping THE build."
fi

echo "=== 4. Building and installing lspf (ISPF Clone) into /usr/local ==="
LSPF_REPO_URL="https://github.com/daniel64/lspf.git"
LSPF_SHARE_DIR="/usr/local/share/lspf"
LSPF_BIN="/usr/local/bin/lspf"
LSPF_BUILD_DIR="$BUILD_HOME/lspf-build"

if [[ ! -x "$LSPF_BIN" || ! -d "$LSPF_SHARE_DIR" ]]; then
    # Ensure temporary build directory is removed on exit or error
    trap 'rm -rf "$LSPF_BUILD_DIR"' EXIT

    rm -rf "$LSPF_BUILD_DIR"
    echo "Cloning $LSPF_REPO_URL into $LSPF_BUILD_DIR as user '$BUILD_USER'..."
    sudo -u "$BUILD_USER" git clone "$LSPF_REPO_URL" "$LSPF_BUILD_DIR"

    # Configure ZSYSPATH to /usr/local/share/lspf and compile as non-root user
    sudo -u "$BUILD_USER" bash -c "
        set -euo pipefail
        cd '$LSPF_BUILD_DIR/src'
        sed -i 's|#define ZSYSPATH .*|#define ZSYSPATH "$LSPF_SHARE_DIR"|g' lspf.h
        ./compsetup
        ./setup
        ./comp1
        cd '$LSPF_BUILD_DIR/src/Apps'
        ./compapps
    "

    echo "Installing lspf binary to $LSPF_BIN and runtime assets to $LSPF_SHARE_DIR..."
    install -Dm755 "$LSPF_BUILD_DIR/src/lspf" "$LSPF_BIN"

    mkdir -p "$LSPF_SHARE_DIR"
    for ASSET_DIR in help mlib plib rexx slib tlib; do
        if [[ -d "$LSPF_BUILD_DIR/$ASSET_DIR" ]]; then
            cp -r "$LSPF_BUILD_DIR/$ASSET_DIR" "$LSPF_SHARE_DIR/"
        fi
    done

    # Copy compiled shared libraries (Apps) into ZSYSPATH/Apps
    if [[ -d "$LSPF_BUILD_DIR/src/Apps" ]]; then
        mkdir -p "$LSPF_SHARE_DIR/Apps"
        find "$LSPF_BUILD_DIR/src/Apps" -maxdepth 1 -name "*.so" -exec cp {} "$LSPF_SHARE_DIR/Apps/" \;
    fi

    # Clean up temporary build directory in user's home
    rm -rf "$LSPF_BUILD_DIR"
    trap - EXIT
    echo "lspf installed to $LSPF_BIN (assets in $LSPF_SHARE_DIR) and build directory removed."
else
    echo "lspf is already installed at $LSPF_BIN — skipping lspf build."
fi

echo "=== 5. Installing check80, pad80, and submitjcl into /usr/local/bin ==="

# --- /usr/local/bin/check80 ---
cat << 'EOF' > /usr/local/bin/check80
#!/usr/bin/env bash
set -euo pipefail

file="/dev/stdin"
max_col=72

for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        max_col="$arg"
    else
        file="$arg"
    fi
done

tr -d '\r' < "$file" | awk -v max="$max_col" '
    length($0) > max {
        printf "Line %d exceeds column %d (length %d): %s\n", NR, max, length($0), $0 > "/dev/stderr"
        bad++
    }
    END {
        if (bad > 0) {
            printf "check80 FAILED: %d line(s) exceed column %d.\n", bad, max > "/dev/stderr"
            exit 1
        }
    }
'
EOF
chmod 755 /usr/local/bin/check80

# --- /usr/local/bin/pad80 ---
cat << 'EOF' > /usr/local/bin/pad80
#!/usr/bin/env bash
set -euo pipefail

add_seq=0
file="/dev/stdin"

for arg in "$@"; do
    if [[ "$arg" == "--seq" ]]; then
        add_seq=1
    else
        file="$arg"
    fi
done

tr -d '\r' < "$file" | awk -v seq="$add_seq" '
    {
        if (seq == 1) {
            printf "%-72.72s%08d\n", $0, NR * 100
        } else {
            printf "%-80.80s\n", $0
        }
    }
'
EOF
chmod 755 /usr/local/bin/pad80

# --- /usr/local/bin/submitjcl ---
cat << 'EOF' > /usr/local/bin/submitjcl
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: submitjcl <file.jcl> [host] [port]" >&2
    exit 1
fi

if ! /usr/local/bin/check80 "$1" 72; then
    echo "Submission aborted: fix lines exceeding column 72 first." >&2
    exit 1
fi

tr -d '\r' < "$1" | nc -w 2 "${2:-127.0.0.1}" "${3:-3505}"
EOF
chmod 755 /usr/local/bin/submitjcl

echo "Installed check80, pad80, and submitjcl to /usr/local/bin."

echo "=== 6. Configuring aliases, EBCDIC helpers, .therc, and .vimrc for 'ibm' and 'ian' ==="

# --- Bash Aliases & EBCDIC Helpers (~/.bashrc) ---
BASH_ALIASES=$(cat << 'EOF'

# --- Mainframe Development Aliases ---
alias algol60='marst'
alias pascal='fpc -Miso'
alias cobol='cobc -std=ibm -fixed'
alias f77='gfortran -std=legacy -fno-automatic'
alias xedit='the'
alias ispf='lspf'
alias fd='fdfind'

# --- EBCDIC & 80-Col Card Stream Helpers ---
# Stream/file conversion using IBM-1047 (swap to IBM037 if preferred)
ascii2ebcdic() { iconv -f UTF-8 -t IBM1047 "${@:--}"; }
ebcdic2ascii() { iconv -f IBM1047 -t UTF-8 "${@:--}"; }

# Convert newline-delimited ASCII text <-> fixed 80-byte unblocked EBCDIC card deck
card2ebcdic()  { dd if="${1:-/dev/stdin}" of="${2:-/dev/stdout}" conv=ebcdic,block cbs=80 status=none; }
ebcdic2card()  { dd if="${1:-/dev/stdin}" of="${2:-/dev/stdout}" conv=ascii,unblock cbs=80 status=none; }

# Hex dump with EBCDIC-to-ASCII preview
hexebcdic()    { dd if="${1:-/dev/stdin}" conv=ascii status=none | xxd; }
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
alias fd 'fdfind'

# --- EBCDIC & 80-Col Card Stream Helpers ---
alias ascii2ebcdic 'iconv -f UTF-8 -t IBM1047'
alias ebcdic2ascii 'iconv -f IBM1047 -t UTF-8'
alias card2ebcdic  'dd conv=ebcdic,block cbs=80 status=none'
alias ebcdic2card  'dd conv=ascii,unblock cbs=80 status=none'
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
        echo "[$TARGET_USER] Added Bash aliases and EBCDIC helpers to $BASHRC"
    else
        echo "[$TARGET_USER] Bash aliases already exist in $BASHRC — skipping."
    fi
    chown "$TARGET_USER":"$USER_GROUP" "$BASHRC"

    # 2. Append Csh aliases if not already present
    touch "$CSHRC"
    if ! grep -q "Mainframe Development Aliases" "$CSHRC"; then
        echo "$CSH_ALIASES" >> "$CSHRC"
        echo "[$TARGET_USER] Added Csh aliases and EBCDIC helpers to $CSHRC"
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


