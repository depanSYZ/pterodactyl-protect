#!/usr/bin/env bash
# install_protect_3.sh - Pterodactyl Protect (Anti Akses Server)
# Proteksi: Anti Akses Server - user hanya bisa akses server milik sendiri
set -Eeuo pipefail

TS="$(date -u +'%Y-%m-%d-%H-%M-%S')"

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "❌ Jalankan script ini sebagai root."
    exit 1
  fi
}

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

echo "🚀 Memasang Proteksi 3: Anti Akses Server"
echo "🕒 Timestamp: $TS"
echo

# ========== Api/Client/Servers/ServerController.php ==========
TARGET="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
echo "➡️  Proteksi: Anti Akses Server Controller"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Server;
use Pterodactyl\Transformers\Api\Client\ServerTransformer;
use Pterodactyl\Services\Servers\GetUserPermissionsService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\GetServerRequest;

class ServerController extends ClientApiController
{
    public function __construct(private GetUserPermissionsService $permissionsService)
    {
        parent::__construct();
    }

    public function index(GetServerRequest $request, Server $server): array
    {
        // 🔒 Anti intip server orang lain (kecuali admin ID 1)
        $authUser = Auth::user();

        if ($authUser->id !== 1 && (int) $server->owner_id !== (int) $authUser->id) {
            abort(403, '𝗔𝗸𝘀𝗲𝘀 𝗗𝗶 𝗧𝗼𝗹𝗮𝗸❌. 𝗛𝗮𝗻𝘆𝗮 𝗕𝗶𝘀𝗮 𝗔𝗸𝘀𝗲𝘀 𝗦𝗲𝗿𝘃𝗲𝗿 𝗠𝗶𝗹𝗶𝗸 𝗦𝗲𝗻𝗱𝗶𝗿𝗶.');
        }

        return $this->fractal->item($server)
            ->transformWith($this->getTransformer(ServerTransformer::class))
            ->addMeta([
                'is_server_owner' => $request->user()->id === $server->owner_id,
                'user_permissions' => $this->permissionsService->handle($server, $request->user()),
            ])
            ->toArray();
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ Berhasil dipasang: Anti Akses Server"
echo

echo "🎉 Proteksi 3 berhasil terpasang!"
echo "🗂️ File lama dibackup dengan suffix: .bak_${TS}"
echo ""
echo "⚠️ Jangan lupa jalankan: php artisan optimize:clear"
