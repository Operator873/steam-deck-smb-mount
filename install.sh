#!/usr/bin/env bash

# ==============================================================================
# Steam Deck SMB Mount Wizard - Installer
# Description: Automates the download and setup of the SMB Mount Wizard.
# ==============================================================================

# Exit immediately if any command exits with a non-zero status.
# This prevents the script from trying to set permissions on a file that failed to download.
set -e

echo "==> Starting installation of Steam Deck SMB Mount Wizard..."

# Define the base URL for the raw GitHub repository files
REPO_RAW_URL="https://raw.githubusercontent.com/Operator873/steam-deck-smb-mount/main"

# Define the destination paths
# $HOME automatically expands to /home/deck on the Steam Deck
SCRIPT_DEST="$HOME/smb_wizard.sh"
DESKTOP_DEST="$HOME/Desktop/SMB-Wizard.desktop"

# Step 1: Download the main execution script
echo "  -> Downloading core script to $SCRIPT_DEST..."
curl -sSL -o "$SCRIPT_DEST" "${REPO_RAW_URL}/smb_wizard.sh"

# Step 2: Download the desktop shortcut directly to the visual desktop
echo "  -> Downloading desktop shortcut to $DESKTOP_DEST..."
curl -sSL -o "$DESKTOP_DEST" "${REPO_RAW_URL}/SMB-Wizard.desktop"

# Step 3: Apply execution permissions to both files so Plasma will run them natively
echo "  -> Applying execution permissions..."
chmod +x "$SCRIPT_DEST"
chmod +x "$DESKTOP_DEST"

# Final success message
echo "==> Installation complete! You can now double-click 'SMB Mount Wizard' on your Desktop."