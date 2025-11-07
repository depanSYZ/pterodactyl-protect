
```markdown
# 🛡️ Pterodactyl Protect

Script proteksi untuk panel Pterodactyl yang mencegah akses tidak sah dan modifikasi oleh user biasa.

## 📋 Fitur Proteksi

### 🛡️ Protect 1 - Anti Delete Server
- Hanya admin ID 1 yang bisa hapus server user lain
- User biasa hanya bisa hapus server milik sendiri

### 🛡️ Protect 2 - Anti Modifikasi Server  
- Hanya admin ID 1 yang bisa ubah detail server
- User biasa tidak bisa ubah nama, owner, dll

### 🛡️ Protect 3 - Anti Akses Server
- User hanya bisa akses server milik sendiri
- Tidak bisa intip server user lain

### 🛡️ Protect ALL - Semua Proteksi
- Install semua proteksi sekaligus

## 🚀 Cara Install

### Via Bot Telegram (Recommended)
```

/installprotect 1    # Install proteksi 1
/installprotect 2# Install proteksi 2
/installprotect 3    # Install proteksi 3
/installprotect all# Install semua proteksi

```

### Via Terminal SSH
```bash
# Proteksi 1
bash <(curl -s https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_1.sh)

# Proteksi 2
bash <(curl -s https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_2.sh)

# Proteksi 3  
bash <(curl -s https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_3.sh)

# Semua Proteksi
bash <(curl -s https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_all.sh)
```

🔧 Command Lainnya

```bash
/statusprotect       # Cek status proteksi
/backupprotect       # Backup file original  
/uninstallprotect    # Hapus semua proteksi
```

⚠️ Catatan Penting

1. Backup Otomatis: File original dibackup dengan format .bak_TIMESTAMP
2. Hanya Root: Script harus dijalankan sebagai user root
3. Clear Cache: Setelah install, jalankan php artisan optimize:clear
4. Test Dulu: Selalu test di server development sebelum production

🆘 Troubleshooting

Error Permission Denied

```bash
chmod +x install_protect_*.sh
```

Error File Not Found

· Pastikan Pterodactyl terinstall di /var/www/pterodactyl
· Cek path dengan ls -la /var/www/pterodactyl/app/Services/Servers/

📞 Support

· Telegram: @depstore11
· GitHub: depanSYZ/pterodactyl-protect

⚖️ License

MIT License - bebas digunakan untuk project pribadi dan komersial.

```
1. Clone repository:
```bash
git clone https://github.com/depanSYZ/pterodactyl-protect.git
cd pterodactyl-protect
```

1. Copy semua file .sh dan README.md ke folder
2. Commit dan push:

```bash
git add .
git commit -m "Add Pterodactyl protect scripts"
git push origin main
```

Step 3: Dapatkan RAW URL

Format RAW URL:

```
https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_1.sh
https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_2.sh
https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_3.sh  
https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_all.sh
```
```javascript
// Ganti ini di fungsi installProtection()
const command = `bash <(curl -s https://raw.githubusercontent.com/depanSYZ/pterodactyl-protect/main/install_protect_${type}.sh)`;
```
