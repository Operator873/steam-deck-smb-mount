#!/usr/bin/env bash

# ==============================================================================
# Steam Deck SMB Mount Wizard v1.0
# Description: A GUI-driven script to manage SMB shares via systemd on SteamOS.
# ==============================================================================

APP_TITLE="SMB Mount Wizard"
TAG="Managed by SteamDeck SMB Wizard"

# ==============================================================================
# Utility Functions
# ==============================================================================

# Exit cleanly if the user clicks "Cancel" on any kdialog window
function die_on_cancel() {
    if [ $? -ne 0 ]; then
        kdialog --title "$APP_TITLE" --msgbox "Operation cancelled by user. Exiting."
        exit 1
    fi
}

# Verify the user has a sudo password set
function check_sudo() {
    SUDO_PASS=$(kdialog --title "$APP_TITLE" --password "System changes require root access.\n\nEnter your Steam Deck (sudo) password:")
    die_on_cancel

    if ! echo "$SUDO_PASS" | sudo -S -v >/dev/null 2>&1; then
        kdialog --title "$APP_TITLE" --error "Authentication failed.\n\nYou must open Konsole and type 'passwd' to create a password first."
        exit 1
    fi
}

# Validate network connectivity using Ping, falling back to Netcat on port 445
function validate_network() {
    kdialog --title "$APP_TITLE" --passivepopup "Validating connection to $SMB_SERVER..." 3
    
    # Try ICMP Ping first (1 packet, 2 second timeout)
    if ! ping -c 1 -W 2 "$SMB_SERVER" >/dev/null 2>&1; then
        # Fallback to Netcat on SMB Port 445 (zero-I/O mode, 2 second timeout)
        if ! nc -z -w 2 "$SMB_SERVER" 445 >/dev/null 2>&1; then
            kdialog --title "$APP_TITLE" --error "Network Validation Failed!\n\nCould not reach $SMB_SERVER via Ping or Port 445.\nPlease check the IP address and your Wi-Fi connection."
            exit 1
        fi
    fi
}

# Parse variables to format systemd-compliant filenames
function parse_variables() {
    # Convert path /home/deck/NAS to home-deck-NAS
    UNIT_PREFIX=$(echo "$MOUNT_POINT" | sed 's/^\///' | sed 's/\//-/g')
    MOUNT_FILE="${UNIT_PREFIX}.mount"
    AUTOMOUNT_FILE="${UNIT_PREFIX}.automount"
    CRED_FILE="/home/deck/.smbcreds_${UNIT_PREFIX}"
}

# ==============================================================================
# Core Actions (Install / Modify / Remove)
# ==============================================================================

# Gather inputs from the user, with optional default values for the Modification flow
function gather_inputs() {
    local def_server=${1:-""}
    local def_share=${2:-""}
    local def_mount=${3:-"/home/deck/NAS"}
    local def_user=${4:-""}

    SMB_SERVER=$(kdialog --title "$APP_TITLE" --inputbox "Enter your NAS/Server IP Address:" "$def_server")
    die_on_cancel

    SMB_SHARE=$(kdialog --title "$APP_TITLE" --inputbox "Enter the name of the SMB Share:" "$def_share")
    die_on_cancel

    MOUNT_POINT=$(kdialog --title "$APP_TITLE" --inputbox "Enter the local mount path:" "$def_mount")
    die_on_cancel

    SMB_USER=$(kdialog --title "$APP_TITLE" --inputbox "Enter your SMB Username:" "$def_user")
    die_on_cancel

    SMB_PASS=$(kdialog --title "$APP_TITLE" --password "Enter your SMB Password:")
    die_on_cancel

    validate_network

    kdialog --title "$APP_TITLE" --yesno "Confirm Settings:\n\nServer: //$SMB_SERVER/$SMB_SHARE\nMount: $MOUNT_POINT\nUser: $SMB_USER\n\nProceed?"
    die_on_cancel
}

# Generate and enable the systemd payload
function generate_system_files() {
    echo "$SUDO_PASS" | sudo -S mkdir -p "$MOUNT_POINT"
    echo "$SUDO_PASS" | sudo -S chown deck:deck "$MOUNT_POINT"

    echo -e "username=${SMB_USER}\npassword=${SMB_PASS}" > "$CRED_FILE"
    chmod 600 "$CRED_FILE"

    # Write the .mount file. Note the tag in the Description used for tracking.
    echo "$SUDO_PASS" | sudo -S tee "/etc/systemd/system/${MOUNT_FILE}" > /dev/null <<EOF
[Unit]
Description=Mount SMB share at ${MOUNT_POINT} - $TAG
Requires=network-online.target
After=network-online.target systemd-resolved.service
Wants=network-online.target systemd-resolved.service

[Mount]
What=//${SMB_SERVER}/${SMB_SHARE}
Where=${MOUNT_POINT}
Type=cifs
Options=rw,uid=1000,gid=1000,nofail,credentials=${CRED_FILE}
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

    # Write the .automount file
    echo "$SUDO_PASS" | sudo -S tee "/etc/systemd/system/${AUTOMOUNT_FILE}" > /dev/null <<EOF
[Unit]
Description=Automount SMB share at ${MOUNT_POINT}

[Automount]
Where=${MOUNT_POINT}

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable the automount service
    echo "$SUDO_PASS" | sudo -S systemctl daemon-reload
    echo "$SUDO_PASS" | sudo -S systemctl enable --now "${AUTOMOUNT_FILE}"

    kdialog --title "$APP_TITLE" --msgbox "Success! Your share has been mounted.\n\nOpening file manager now."
    
    # Launch Dolphin to prove the mount was successful
    xdg-open "$MOUNT_POINT" &
}

# The uninstaller and config remover
function remove_share() {
    # Find all .mount files containing our specific tag
    mapfile -t EXISTING < <(grep -l "$TAG" /etc/systemd/system/*.mount 2>/dev/null)
    
    if [ ${#EXISTING[@]} -eq 0 ]; then
        kdialog --title "$APP_TITLE" --msgbox "No shares managed by this wizard were found."
        exit 0
    fi

    # Build kdialog radiolist arguments
    local args=()
    for file in "${EXISTING[@]}"; do
        # Extract the mount point for display
        local target=$(grep "^Where=" "$file" | cut -d= -f2)
        args+=("$file" "$target" "off")
    done

    # Let user select which config to delete
    SELECTED_FILE=$(kdialog --title "$APP_TITLE" --radiolist "Select the share to remove:" "${args[@]}")
    die_on_cancel

    # Extract target info to clean up properly
    local target_mount=$(grep "^Where=" "$SELECTED_FILE" | cut -d= -f2)
    local unit_prefix=$(basename "$SELECTED_FILE" .mount)
    local cred_file="/home/deck/.smbcreds_${unit_prefix}"

    # Stop and disable systemd units
    echo "$SUDO_PASS" | sudo -S systemctl disable --now "${unit_prefix}.automount" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S systemctl disable --now "${unit_prefix}.mount" 2>/dev/null

    # Remove systemd files and credentials
    echo "$SUDO_PASS" | sudo -S rm -f "/etc/systemd/system/${unit_prefix}.mount"
    echo "$SUDO_PASS" | sudo -S rm -f "/etc/systemd/system/${unit_prefix}.automount"
    rm -f "$cred_file"

    echo "$SUDO_PASS" | sudo -S systemctl daemon-reload

    # Attempt to remove the mount directory only if it is completely empty
    rmdir "$target_mount" 2>/dev/null

    kdialog --title "$APP_TITLE" --msgbox "Share configuration removed successfully."
}

# The modification logic: scrape existing data, re-prompt, and overwrite
function modify_share() {
    mapfile -t EXISTING < <(grep -l "$TAG" /etc/systemd/system/*.mount 2>/dev/null)
    
    if [ ${#EXISTING[@]} -eq 0 ]; then
        kdialog --title "$APP_TITLE" --msgbox "No shares managed by this wizard were found."
        exit 0
    fi

    local args=()
    for file in "${EXISTING[@]}"; do
        local target=$(grep "^Where=" "$file" | cut -d= -f2)
        args+=("$file" "$target" "off")
    done

    SELECTED_FILE=$(kdialog --title "$APP_TITLE" --radiolist "Select the share to modify:" "${args[@]}")
    die_on_cancel

    # Scrape existing variables from the unit file
    local old_where=$(grep "^Where=" "$SELECTED_FILE" | cut -d= -f2)
    local old_what=$(grep "^What=" "$SELECTED_FILE" | cut -d= -f2)
    
    # Strip the leading // from What= to get server and share
    local clean_what=${old_what#//}
    local old_server=${clean_what%%/*}
    local old_share=${clean_what#*/}

    # Extract username from the credentials file
    local unit_prefix=$(basename "$SELECTED_FILE" .mount)
    local cred_file="/home/deck/.smbcreds_${unit_prefix}"
    local old_user=$(grep "^username=" "$cred_file" | cut -d= -f2)

    # Disable old units before rebuilding in case the user changes the mount path
    echo "$SUDO_PASS" | sudo -S systemctl disable --now "${unit_prefix}.automount" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S systemctl disable --now "${unit_prefix}.mount" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S rm -f "/etc/systemd/system/${unit_prefix}.mount" "/etc/systemd/system/${unit_prefix}.automount"

    # Pass the scraped values as defaults into the input gatherer
    gather_inputs "$old_server" "$old_share" "$old_where" "$old_user"
    parse_variables
    generate_system_files
}

# ==============================================================================
# Main Execution Flow
# ==============================================================================

check_sudo

# Launch the primary menu to determine user intent
USER_CHOICE=$(kdialog --title "$APP_TITLE" --menu "What would you like to do?" \
    "Install" "Mount a new SMB Share" \
    "Modify" "Edit an existing SMB Share" \
    "Remove" "Uninstall an SMB Share")
die_on_cancel

case $USER_CHOICE in
    "Install")
        gather_inputs
        parse_variables
        generate_system_files
        ;;
    "Modify")
        modify_share
        ;;
    "Remove")
        remove_share
        ;;
esac

exit 0