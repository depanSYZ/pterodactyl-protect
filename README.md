```markdown
# 🛡️ Pterodactyl Protect Scripts

Collection of bash scripts to protect your Pterodactyl panel from unauthorized access. For Pterodactyl panel owners who want to secure their panel from other admins trying to delete servers or modify settings without permission.

## 🎯 Who This Is For?

- **Panel Owners** who have multiple admins but want to maintain full control
- **Resellers** who want to give panel access to clients without worrying about misuse
- **VPS/Server Providers** who need to restrict access for other admins

## 📦 Protection List

### 1. `protect_server_delete_modify.sh`
**What It Prevents:**
- Other admins deleting servers they don't own
- Unauthorized modification of server details (name, owner, etc.)

**Modified Files:**
- `ServerDeletionService.php`
- `DetailsModificationService.php`

**Error Message:**
```

"❌ Access Denied: You can only delete your own servers @protect depstore"

```

### 2. `protect_server_file_access.sh`
**What It Prevents:**
- Peeking into other users' server files through file manager
- Downloading files from servers they don't own

**Modified Files:**
- `ServerController.php`
- `FileController.php`

**Error Message:**
```

"𝗔𝗰𝗰𝗲𝘀𝘀 𝗗𝗲𝗻𝗶𝗲𝗱❌. 𝗢𝗻𝗹𝘆 𝗔𝗹𝗹𝗼𝘄𝗲𝗱 𝗳𝗼𝗿 𝗢𝘄𝗻𝗲𝗿𝘀."

```

### 3. `protect_settings_access.sh`
**What It Prevents:**
- Other admins accessing panel settings page
- Modifying panel settings

**Modified Files:**
- `IndexController.php` (Settings)

**Error Message:**
```

"Access Denied: Unauthorized Settings Access"

```

### 4. `protect_nests_access.sh`
**What It Prevents:**
- Viewing or modifying nests & eggs
- Adding/deleting nests

**Modified Files:**
- `NestController.php`

**Error Message:**
```

"🚫 Access Denied! Only main admin (ID 1) can access Nests menu."

```

### 5. `protect_nodes_access.sh`
**What It Prevents:**
- Viewing node list
- Accessing node details

**Modified Files:**
- `NodeController.php`

**Error Message:**
```

"🚫 Access Denied! Only admin ID 1 can access Nodes menu. ©protect by depstore"

```

### 6. `protect_locations_access.sh`
**What It Prevents:**
- Accessing locations menu
- Creating/deleting locations

**Modified Files:**
- `LocationController.php`

**Error Message:**
```

"Access Denied: Unauthorized Location Access"

```

### 7. `protect_user_management.sh`
**What It Prevents:**
- Deleting other users (except admin ID 1)
- Modifying sensitive user data (email, password, etc.)

**Modified Files:**
- `UserController.php`

**Error Message:**
```

"❌ Only admin ID 1 can delete other users!"
"⚠️Data can only be modified by admin ID 1."

```

## 🚀 How to Use

### Option 1: Install All at Once
```bash
# Download all-in-one script
wget https://raw.githubusercontent.com/depanSYZ/pterpdactyl-protect/installall.sh

# Give permission
chmod +x install_protect_all.sh

# Run as root
sudo ./install_protect_all.sh
```

Option 2: Install One by One

```bash
# Download individual scripts
wget https://raw.githubusercontent.com/depanSYZ/pterpdactyl-protect/install2.sh
wget https://raw.githubusercontent.com/depanSYZ/pterpdactyl-protect/install1.sh
# ... and so on

# Give permission
chmod +x protect_*.sh

# Run as needed
sudo ./protect_server_delete_modify.sh
sudo ./protect_settings_access.sh
# ... and so on
```

⚠️ Important Notes

Before Installation:

· Backup your panel first, in case of errors
· Ensure Pterodactyl panel is installed in default path /var/www/pterodactyl
· Make sure you're logged in as root

After Installation:

· Script will create backup of original files with format filename.bak_TIMESTAMP
· To restore, simply rename/restore the backup files
· To apply changes, you may need to restart queue: php artisan queue:restart

Access Permissions:

· Only user with ID 1 can access all features
· Other admins can only:
  · View & manage their own servers
  · Access file manager for their own servers
  · Cannot delete/modify others' servers

🔧 Troubleshooting

If Permission Error:

```bash
sudo chmod +x *.sh
sudo ./script_name.sh
```

If Files Not Found:

· Ensure Pterodactyl is installed in /var/www/pterodactyl
· Check path manually: ls -la /var/www/pterodactyl/app/

If You Want to Uninstall:

· Delete modified files, then rename backup files:

```bash
mv /var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php.bak_20241212_120000 /var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php
```

🎭 Additional Features

Auto Backup:

Every modified file is automatically backed up with timestamp, safe for rollback.

Custom Error Messages:

Error messages can be customized according to your preference.

Horizontal & Vertical Restrictions:

· Horizontal: Regular users cannot access other servers/users
· Vertical: Regular admins cannot access system features (nodes, nests, settings)

📞 Support

If you encounter errors or have questions:

· Create an issue on GitHub
· Or contact directly

⚖️ Disclaimer

These scripts are created for your panel security. Use wisely, don't misuse. Author is not responsible for any errors or panel damage, always backup before installation!

---

Made with ❤️ for those who want their Pterodactyl panel secure and under control

```
