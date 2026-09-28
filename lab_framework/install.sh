#!/usr/bin/env bash
# Installs the lab framework on workstation. Run as student from this directory.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST=/opt/rh294lab

sudo mkdir -p "$DEST"
sudo rm -rf "$DEST/lib" "$DEST/exercises"
sudo cp -r "$SRC/lib" "$SRC/exercises" "$SRC/ansible.cfg" "$SRC/inventory" "$DEST/"
sudo chmod -R a+rX "$DEST"
sudo chmod 0640 "$DEST/inventory"
sudo chgrp student "$DEST/inventory"
sudo install -m 0755 "$SRC/bin/lab" /usr/local/bin/lab
sudo install -m 0644 "$SRC/completion/lab" /etc/bash_completion.d/lab
echo "Installed. Open a new terminal, then run: lab list"
