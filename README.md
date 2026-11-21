# Build Hyperion (`build-hyperion`)

This repository contains automation scripts and configuration helpers to prepare a clean Debian Linux system (`ibm`) and build **SDL Hercules Hyperion** (IBM mainframe emulator) from source.

## Repository Structure

```text
~/projects/build-hyperion/
├── README.md        # Project documentation and build workflow
├── sysreqs          # Root bootstrap script for base tools and sudo access
├── buildreqs.sh     # User script to pull submodule source, install build packages & Regina REXX, and verify tool levels
└── hyperion/        # Git submodule containing the upstream SDL-Hercules-390/hyperion source
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

*(Future build phases and scripts will be documented here as they are added to the repository.)*

## References
* [SDL Hercules 390 Installation & Operation Guide](https://github.io)
* [SDL Hercules Hyperion GitHub Repository](https://github.com)

