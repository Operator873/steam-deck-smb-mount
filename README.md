# Operator873's Steam Deck SMB Mount Wizard

A few years ago, I [wrote a guide](https://www.reddit.com/r/SteamDeck/comments/ymjnjy/mounting_smb_shares_with_systemd/) on Reddit detailing how to mount a Samba share on a Steam Deck using `systemd`. This permitted the remote storage of ROMs, media, and other associated content that nerds like me want access to on their Deck. Recently, another user ([u/rogercrocha](https://www.reddit.com/user/rogercrocha/)) appeared in that thread with a ChatGPT-generated script to automate the process. This inspired me to revisit my old project and build a proper, native tool to make adding an SMB share incredibly easy—and honestly, quite pleasant.

This is the result.

### ✨ Features
* **Zero-Terminal Experience:** Completely GUI-driven using native KDE Plasma dialogs (`kdialog`).
* **Update Resilient:** Safely mounts your shares within the `/home/deck/` directory, ensuring your configuration survives major SteamOS system updates.
* **High Performance:** Utilizes the kernel CIFS driver rather than user-space FUSE frameworks (like Dolphin's default network viewer) for better emulator compatibility and lower CPU overhead.
* **Automated Lifecycle:** Generates strict, FHS-compliant `systemd` `.mount` and `.automount` units, securely stashes your credentials, and handles the `sudo` heavy lifting.

---

## 🛑 Prerequisites
Because this wizard creates system-level mount units, it requires root (`sudo`) access. 

Out of the box, SteamOS does not have a user password set. If you have never set a password on your Steam Deck, you must do so before running this wizard:
1. Open **Konsole** in Desktop Mode.
2. Type `passwd` and press Enter.
3. Create a secure password (it will not show characters on screen as you type).

## 🚀 Installation
Installation is scripted for ease of use. Simply copy the following one-liner into Konsole and press Enter:

`curl -sSL https://raw.githubusercontent.com/Operator873/steam-deck-smb-mount/main/install.sh | bash`

After the script completes, you will have an **SMB Mount Wizard** shortcut added directly to your Desktop. Double-click it to launch the tool!

## ⚙️ Modification
The wizard supports seamlessly modifying SMB configurations that it has created (it explicitly ignores and will not alter other systemd mount units on your system). Once you've created an SMB mount with this utility, you may relaunch the wizard via the desktop shortcut at any time and select "Modify" to change IPs, paths, or credentials.

## 🗑️ Uninstallation
The wizard features a built-in removal utility to make tearing down SMB shares just as easy as creating them. Launch the wizard and select **"Remove"** to safely stop the services, delete the systemd units, and wipe your cached credentials.

To fully remove the wizard itself from your system, execute the following commands in Konsole *after* you have used the tool to unmount your shares:

```bash
cd ~
rm -f smb_wizard.sh
rm -f Desktop/SMB-Wizard.desktop
```