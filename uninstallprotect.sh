#!/usr/bin/env bash
# uninstall_protect.sh - Uninstall semua proteksi Pterodactyl
set -Eeuo pipefail

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "❌ Jalankan script ini sebagai root."
    exit 1
  fi
}

require_root

echo "🔄 Memulai uninstall semua proteksi Pterodactyl..."
echo "📦 Mencari file backup..."

# List semua file yang mungkin ada backup-nya
FILES=(
    "/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
    "/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
    "/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
)

RESTORED_COUNT=0

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        # Cari backup file terbaru
        BACKUP_FILE=$(ls "${file}.bak_"* 2>/dev/null | sort -r | head -1)
        
        if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
            echo "🔄 Restoring: $(basename "$file")"
            mv "$BACKUP_FILE" "$file"
            ((RESTORED_COUNT++))
            
            # Restore permission
            chmod 644 "$file"
            echo "✅ $(basename "$file") restored from: $(basename "$BACKUP_FILE")"
        else
            echo "⚠️  No backup found for: $(basename "$file")"
        fi
    else
        echo "❌ File not found: $(basename "$file")"
    fi
done

echo ""
echo "📊 Uninstall Summary:"
echo "   ✅ $RESTORED_COUNT files restored from backup"
echo ""
echo "🎯 Yang perlu dilakukan manual:"
echo "   🔄 Restart queue: php artisan queue:restart"
echo "   🧹 Clear cache: php artisan cache:clear"
echo "   🔄 Reload PHP: systemctl reload php-fpm (atau apache2/nginx)"
echo ""
echo "💡 Tips: Jika masih ada issue, cek backup file manual:"
echo "   ls -la /var/www/pterodactyl/app/**/*.bak_*"
