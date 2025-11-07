```markdown
# 🛡️ Pterodactyl Protect Scripts

Kumpulan script bash untuk ngeproteksi panel Pterodactyl dari tangan-tangan jahil. Buat yang punya panel Pterodactyl dan mau aman dari admin lain yang sok mau hapus-hapus server atau utak-atik settingan.

## 🎯 Buat Siapa Ini?

- **Pemilik Panel** yang punya banyak admin tapi mau tetap kontrol penuh
- **Reseller** yang mau kasih akses panel ke client tanpa takut diobok-obok
- **Yang lagi jual VPS/Server** dan mau restrict akses admin lainnya

## 📦 Daftar Proteksi

### 1. `protect_server_delete_modify.sh`
**Yang Dicegah:**
- Admin lain hapus server yang bukan punya mereka
- Ganti detail server (nama, owner, dll) sembarangan

**File yang Dimodif:**
- `ServerDeletionService.php`
- `DetailsModificationService.php`

**Pesan Error:**
```

"❌Akses ditolak: Wawes Sikontol Mau hapus server orang 😹,Anda hanya dapat menghapus server milik Anda sendiri @protect depstore"

```

### 2. `protect_server_file_access.sh`
**Yang Dicegah:**
- Intip file server orang lain lewat file manager
- Download file server yang bukan punya sendiri

**File yang Dimodif:**
- `ServerController.php`
- `FileController.php`

**Pesan Error:**
```

"𝗔𝗸𝘀𝗲𝘀 𝗗𝗶 𝗧𝗼𝗹𝗮𝗸❌. 𝗛𝗮𝗻𝘆𝗮 𝗕𝗶𝗹𝗮 𝗠𝗶𝗹𝗶𝗸 𝗦𝗲𝗻𝗱𝗶𝗿𝗶."

```

### 3. `protect_settings_access.sh`
**Yang Dicegah:**
- Admin lain buka halaman settings panel
- Ubah-ubah setting panel

**File yang Dimodif:**
- `IndexController.php` (Settings)

**Pesan Error:**
```

"BOCAH TOLOL NGINTIP NGINTIP"

```

### 4. `protect_nests_access.sh`
**Yang Dicegah:**
- Lihat atau utak-atik nests & eggs
- Tambah/hapus nests

**File yang Dimodif:**
- `NestController.php`

**Pesan Error:**
```

"🚫 Akses ditolak! Hanya admin utama (ID 1) yang bisa membuka menu Nests."

```

### 5. `protect_nodes_access.sh`
**Yang Dicegah:**
- Lihat daftar nodes
- Akses detail node

**File yang Dimodif:**
- `NodeController.php`

**Pesan Error:**
```

"🚫 Akses ditolak! Hanya admin ID 1 yang dapat membuka menu Nodes. ©protect by depstore"

```

### 6. `protect_locations_access.sh`
**Yang Dicegah:**
- Akses menu locations
- Buat/hapus locations

**File yang Dimodif:**
- `LocationController.php`

**Pesan Error:**
```

"BOCAH TOLOL NGINTIP NGINTIP"

```

### 7. `protect_user_management.sh`
**Yang Dicegah:**
- Hapus user lain (kecuali admin ID 1)
- Ubah data user sensitif (email, password, dll)

**File yang Dimodif:**
- `UserController.php`

**Pesan Error:**
```

"❌ Hanya admin ID 1 yang dapat menghapus user lain!"
"⚠️Data hanya bisa diubah oleh admin ID 1."

```

## 🚀 Cara Pakai

### Opsi 1: Pasang Semua Sekaligus
```bash
# Download script all-in-one
wget https://raw.githubusercontent.com/depanSYZ/pterpdactyl-protect/installall.sh

# Kasih permission
chmod +x install_protect_all.sh

# Jalankan sebagai root
sudo ./install_protect_all.sh
```

Opsi 2: Pasang Satu-Satu

```bash
# Download semua script terpisah
wget https://raw.githubusercontent.com/depanSYZ/pterpdactyl-protect/install2.sh
wget https://raw.githubusercontent.com/depanSYZ/pterpdactyl-protect/install1.sh
# ... dan seterusnya

# Kasih permission
chmod +x protect_*.sh

# Jalankan sesuai kebutuhan
sudo ./protect_server_delete_modify.sh
sudo ./protect_settings_access.sh
# ... dan seterusnya
```

⚠️ Yang Perlu Diperhatiin

Sebelum Install:

· Backup panel dulu, siapa tau ada yang error
· Pastikan panel Pterodactyl udah terinstall di path default /var/www/pterodactyl
· Pastikan kamu login sebagai root

Setelah Install:

· Script bakal bikin backup file original dengan format filename.bak_TIMESTAMP
· Kalo mau restore, tinggal rename/balikin file backup-nya
· Untuk apply perubahan, mungkin perlu restart queue: php artisan queue:restart

Yang Bisa Akses:

· Hanya user dengan ID 1 yang bisa akses semua fitur
· Admin lain cuma bisa:
  · Lihat & manage server mereka sendiri
  · Akses file manager server mereka sendiri
  · Gak bisa hapus/ubah server orang

🔧 Troubleshooting

Kalo Error Permission:

```bash
sudo chmod +x *.sh
sudo ./script_name.sh
```

Kalo File Gak Ketemu:

· Pastikan Pterodactyl terinstall di /var/www/pterodactyl
· Cek path manual: ls -la /var/www/pterodactyl/app/

Kalo Mau Uninstall:

· Delete file yang dimodif, terus rename file backup:

```bash
mv /var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php.bak_20241212_120000 /var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php
```

🎭 Fitur Tambahan

Auto Backup:

Setiap file yang dimodif otomatis dibackup dengan timestamp, jadi aman kalo mau rollback.

Error Message "Kasar":

Pesan error sengaja dibuat kasar buat ngejailin admin yang iseng, bisa diubah sesuai selera.

Restrict Horizontal & Vertical:

· Horizontal: User biasa gak bisa akses server/user lain
· Vertical: Admin biasa gak bisa akses fitur system (nodes, nests, settings)

📞 Support

Kalo ada yang error atau mau tanya-tanya:

· Buat issue di GitHub
· Atau contact langsung

⚖️ Disclaimer

Script ini dibuat buat keamanan panel kamu. Gunakan dengan bijak, jangan disalahgunakan. Author gak tanggung jawab kalo ada yang error atau panel jadi rusak, selalu backup dulu sebelum install!

---

Dibuat dengan ❤️ buat yang mau panel Pterodactyl-nya aman dan terkendali

```
