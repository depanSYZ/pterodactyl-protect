#!/usr/bin/env bash
# install_protect_2.sh - Pterodactyl Protect (Anti Modifikasi Server)
# Proteksi: Anti Modifikasi Server - hanya admin utama bisa ubah detail server
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

echo "🚀 Memasang Proteksi 2: Anti Modifikasi Server"
echo "🕒 Timestamp: $TS"
echo

# ========== Services/Servers/DetailsModificationService.php ==========
TARGET="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
echo "➡️  Proteksi: Anti Modifikasi Server"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Arr;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Auth;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Traits\Services\ReturnsUpdatedModels;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class DetailsModificationService
{
    use ReturnsUpdatedModels;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $serverRepository
    ) {}

    /**
     * @throws \Throwable
     */
    public function handle(Server $server, array $data): Server
    {
        // 🚫 Hanya user ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'Akses ditolak: Lu Siapa mek? protect by @depstore11.');
        }

        return $this->connection->transaction(function () use ($data, $server) {
            $owner = $server->owner_id;

            $server->forceFill([
                'external_id' => Arr::get($data, 'external_id'),
                'owner_id' => Arr::get($data, 'owner_id'),
                'name' => Arr::get($data, 'name'),
                'description' => Arr::get($data, 'description') ?? '',
            ])->saveOrFail();

            if ($server->owner_id !== $owner) {
                try {
                    $this->serverRepository->setServer($server)->revokeUserJTI($owner);
                } catch (DaemonConnectionException $exception) {
                    // Wings offline → abaikan
                }
            }

            return $server;
        });
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ Berhasil dipasang: Anti Modifikasi Server"
echo

echo "🎉 Proteksi 2 berhasil terpasang!"
echo "🗂️ File lama dibackup dengan suffix: .bak_${TS}"
echo ""
echo "⚠️ Jangan lupa jalankan: php artisan optimize:clear"
