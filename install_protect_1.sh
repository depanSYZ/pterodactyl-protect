#!/usr/bin/env bash
# install_protect_1.sh - Pterodactyl Protect (Anti Delete Server)
# Proteksi: Anti Delete Server - hanya owner yang bisa hapus server
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

echo "🚀 Memasang Proteksi 1: Anti Delete Server"
echo "🕒 Timestamp: $TS"
echo

# ========== Services/Servers/ServerDeletionService.php ==========
TARGET="/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
echo "➡️  Proteksi: Anti Delete Server"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {
    }

    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    /**
     * @throws \Throwable
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function handle(Server $server): void
    {
        $user = Auth::user();

        // 🔒 Hanya Admin ID=1 boleh hapus server siapa saja.
        // User biasa: hanya boleh hapus server miliknya sendiri.
        if ($user) {
            if ($user->id !== 1) {
                $ownerId = $server->owner_id
                    ?? $server->user_id
                    ?? ($server->owner?->id ?? null)
                    ?? ($server->user?->id ?? null);

                if ($ownerId === null) {
                    throw new DisplayException('Akses ditolak: informasi pemilik server tidak tersedia.');
                }

                if ((int) $ownerId !== (int) $user->id) {
                    throw new DisplayException('❌Akses ditolak: Anda hanya dapat menghapus server milik Anda sendiri');
                }
            }
        }

        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }
            Log::warning($exception);
        }

        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) {
                        throw $exception;
                    }
                    $database->delete();
                    Log::warning($exception);
                }
            }
            $server->delete();
        });
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ Berhasil dipasang: Anti Delete Server"
echo

echo "🎉 Proteksi 1 berhasil terpasang!"
echo "🗂️ File lama dibackup dengan suffix: .bak_${TS}"
echo ""
echo "⚠️ Jangan lupa jalankan: php artisan optimize:clear"
