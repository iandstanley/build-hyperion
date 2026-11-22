# Build Hyperion (`build-hyperion`)

This repository contains automation scripts and configuration helpers to prepare a clean Debian Linux system (`ibm`) and build **SDL Hercules Hyperion** (IBM mainframe emulator) from source on Intel architectures, as well as provision a mainframe development environment.

## Repository Structure

```text
~/projects/build-hyperion/
├── README.md               # Project documentation and build workflow
├── sysreqs                 # Root bootstrap script for base tools and sudo access
├── buildreqs.sh            # User script to pull submodule source, install build packages & Regina REXX, and verify tool levels
├── makehyperion.sh         # Interactive build script to configure, compile across all CPU cores, and install Hercules
├── setup_mainframe_dev.sh  # Root script to install mainframe-compatible compilers, 3270 emulators, editors, and user configs
└── hyperion/               # Git submodule containing the upstream SDL-Hercules-390/hyperion source
```

* **`build-hyperion` (Root Repo):** Tracks the custom build scripts, environment setup, and project documentation independently of the upstream Hercules source code.
* **`hyperion/` (Submodule):** Holds the cloned upstream [SDL Hercules Hyperion](https://github.com) repository. Keeping it as a submodule allows upstream updates to be pulled cleanly without cluttering your local build scripts.

## Scripts

### 1. `sysreqs`
* **Purpose:** Bootstraps a minimal Debian installation with essential system utilities and grants administrative privileges to the build user (`ian`).
* **What it does:**
  * Explicitly exports standard `/sbin` paths so administrative commands work reliably under a plain `su` session.
  * Updates `apt` package lists and installs `git`, `sudo`, `wget`, and `curl`.
  * Adds the user `ian` to the `sudo` group.

### 2. `buildreqs.sh`
* **Purpose:** Prepares the `hyperion` source code and installs all Debian compiler toolchains, libraries, and Regina REXX dependencies required to compile Hercules.
* **What it does:**
  * Verifies the script is run as a non-root user (`ian`) rather than `root`.
  * Checks and initializes/updates the `hyperion` Git submodule (`git submodule update --init --recursive`).
  * Lists any `RELEASE*` or `README*` files in the submodule for review.
  * Installs required Debian build packages (`build-essential`, `cmake`, `flex`, `gawk`, `m4`, `autoconf`, `automake`, `libtool-bin`, `libltdl-dev`, `libbz2-dev`, `zlib1g-dev`, `libcap2-bin`) and `libregina3-dev` for Regina REXX support.
  * Runs Hercules's `./util/bldlvlck` script to verify that all required compiler and tool versions meet minimum requirements.

### 3. `makehyperion.sh`
* **Purpose:** Configures, compiles, and installs SDL Hercules Hyperion from the `hyperion/` submodule, pausing between each stage for manual inspection.
* **What it does:**
  * Verifies the script is run as `ian` (not `root`) and checks that `./configure` exists in `hyperion/`.
  * **Configure:** Runs `./configure` to prepare the build for the host Intel system, then pauses for review.
  * **Compile:** Detects all available CPU cores via `nproc` and builds Hercules in parallel (`make -j$(nproc)`), then pauses so you can inspect the build output for errors.
  * **Install:** Runs `sudo make install` to install Hercules system-wide and automatically apply required thread priority and network capabilities (`setcap`), followed by a final confirmation pause.

### 4. `setup_mainframe_dev.sh`
* **Purpose:** Provisions the Debian host with classic mainframe-compatible compilers, 3270 terminal emulators, XEDIT/ISPF editor clones, and pre-configured developer profiles for **MVS 3.8J** and **VM/370CE** workflows.
* **What it does:**
  * **Installs Mainframe-Compatible Compilers & Interpreters (via `apt`):**
    * **FORTRAN (`gfortran`):** Configured to emulate IBM FORTRAN IV (FORTRAN G/H) using legacy fixed-form rules and static variable storage.
    * **REXX (`regina-rexx`):** Classic procedural REXX interpreter matching BREXX/370 on VM/370CE and MVS 3.8J.
    * **ALGOL 60 (`marst`):** GNU MARST Algol-to-C translator matching OS Algol F / Algol W.
    * **Pascal (`fp-compiler`):** Free Pascal Compiler configured in strict ISO 7185 mode to match VM/370 Stanford Pascal.
    * **COBOL (`gnucobol`):** Configured for IBM dialect rules and 80-column fixed punch-card formatting (MVT COBOL / IKFCBL00).
  * **Installs 3270 Emulators, Editors & Utilities:**
    * **IBM 3270 Suite:** `c3270` (console), `x3270` + `xfonts-x3270-misc` (X11), `s3270` (scriptable), and `pr3287` (network printer daemon).
    * **XEDIT Clone (`the`):** The Hessling Editor for VM/CMS XEDIT-style editing with REXX macro support.
    * **ISPF Clone (`lspf`):** Cloned from GitHub into `/opt/lspf`, compiled from C++ source, and symlinked to `/usr/local/bin/lspf`.
    * **Workflow Tools:** `netcat-openbsd` (for socket JCL card reader submission), `tmux`, `screen`, and `vim` (alongside Debian's built-in `iconv` for EBCDIC conversions).
  * **Configures Developer Accounts (`ibm` and `ian`) Idempotently:**
    * **Bash Aliases (`~/.bashrc`):** Appends Bash-syntax aliases (`alias name='cmd'`) for `f77`, `cobol`, `pascal`, `algol60`, `xedit`, and `ispf` to both `ian` and `ibm`.
    * **Csh/Tcsh Aliases (`~/.cshrc`):** Appends C-shell-syntax aliases (`alias name 'cmd'`) for `f77`, `cobol`, `pascal`, `algol60`, `xedit`, and `ispf` to both `ian` and `ibm`.
    * **XEDIT Profile (`~/.therc`):** Creates a default profile (if one does not already exist) setting IBM VM/CMS XEDIT compatibility mode, line numbering, scale rulers, and left-hand prefix commands.
    * **Vim Column Guides (`~/.vimrc`):** Appends file-extension-aware column markers (`colorcolumn`) for fixed-column editing across COBOL (`.cob`, `.cbl` at cols `7, 8, 12, 73`), FORTRAN (`.f`, `.for`, `.f77` at cols `6, 7, 73`), and JCL (`.jcl` at cols `3, 16, 72, 73`).

## Usage Process

### Phase 1: Base System Bootstrap (`sysreqs`)

1. Log in to the host (`ibm`) via SSH as `ian` and navigate to the project directory:
   ```sh
   cd ~/projects/build-hyperion
   ```
2. Switch to the `root` user using plain `su` and execute `sysreqs`:
   ```sh
   su
   sh sysreqs
   exit
   ```
3. **Refresh Session Permissions:** Log out of the SSH session completely and log back in as `ian` so the new `sudo` group membership takes effect:
   ```sh
   exit
   ```

### Phase 2: Build Prerequisites & Submodule Setup (`buildreqs.sh`)

1. Log back in as `ian` and navigate to the project directory:
   ```sh
   cd ~/projects/build-hyperion
   ```
2. Ensure `buildreqs.sh` is executable and run it:
   ```sh
   chmod +x buildreqs.sh
   ./buildreqs.sh
   ```

### Phase 3: Configure, Compile & Install (`makehyperion.sh`)

1. Ensure `makehyperion.sh` is executable and run it as `ian`:
   ```sh
   chmod +x makehyperion.sh
   ./makehyperion.sh
   ```
2. At each pause prompt (`./configure`, `make`, and `sudo make install`), scroll back through the terminal output to verify there are no warnings or errors, then press **Enter** to proceed to the next step (or **Ctrl+C** to abort).
3. Refresh the dynamic linker cache so Debian recognizes the newly installed shared libraries (`libherc.so`, etc.) in `/usr/local/lib`:
   ```sh
   sudo ldconfig
   ```
4. Verify the installed binaries and version details:
   ```sh
   hercules --help=version
   ```

### Phase 4: Mainframe Development Environment Setup (`setup_mainframe_dev.sh`)

1. Ensure `setup_mainframe_dev.sh` is executable and run it with `sudo`:
   ```sh
   chmod +x setup_mainframe_dev.sh
   sudo ./setup_mainframe_dev.sh
   ```
2. Reload the shell configuration for both `ian` and `ibm` (depending on whether you are using **Bash** or **Csh/Tcsh**):
   ```sh
   # If using Bash:
   source ~/.bashrc

   # If using Csh / Tcsh:
   source ~/.cshrc
   ```

## References
* [SDL Hercules 390 Installation & Operation Guide](https://github.io)
* [SDL Hercules Hyperion GitHub Repository](https://github.com)
