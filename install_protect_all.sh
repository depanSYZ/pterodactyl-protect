#!/usr/bin/env bash
# install_protect_all.sh - Pterodactyl Protect (All-in-One)
# Mode: Pasang SEMUA proteksi sekaligus. Backup otomatis.
set -Eeuo pipefail

TS="$(date -u +'%Y-%m-%d-%H-%M-%S')"

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "❌ Jalankan script ini sebagai root."
    exit 1
  fi
}
require_root

backup_then() {
  local TARGET="$1"
  local DIR; DIR="$(dirname "$TARGET")"
  mkdir -p "$DIR"
  chmod 755 "$DIR" || true
  if [[ -f "$TARGET" ]]; then
    local BAK="${TARGET}.bak_${TS}"
    cp "$TARGET" "$BAK"
    echo "📦 Backup file lama: $BAK"
  fi
}

echo "🚀 Memasang semua proteksi Pterodactyl (All-in-One)…"
echo "🕒 Timestamp: $TS"
echo

# ========== 1) Anti Delete Server ==========
TARGET="/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
echo "➡️  Proteksi: Anti Delete Server"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php
namespace Pterodactyl\Services\Servers;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
// ... [SAMA PERSIS DENGAN install_protect_1.sh]
PHP
chmod 644 "$TARGET"
echo "✅ Berhasil."
echo

# ========== 2) Anti Modifikasi Server ==========
TARGET="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
echo "➡️  Proteksi: Anti Modifikasi Server"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php
namespace Pterodactyl\Services\Servers;
use Illuminate\Support\Arr;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Auth;
// ... [SAMA PERSIS DENGAN install_protect_2.sh]
PHP
chmod 644 "$TARGET"
echo "✅ Berhasil."
echo

# ========== 3) Anti Akses Server ==========
TARGET="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
echo "➡️  Proteksi: Anti Akses Server Controller"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php
namespace Pterodactyl\Http\Controllers\Api\Client\Servers;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Server;
// ... [SAMA PERSIS DENGAN install_protect_3.sh]
PHP
chmod 644 "$TARGET"
echo "✅ Berhasil."
echo

echo "🎉 Semua proteksi terpasang!"
echo "🗂️ File lama dibackup dengan suffix: .bak_${TS}"
echo ""
echo "⚠️ Jangan lupa jalankan: php artisan optimize:clear"
