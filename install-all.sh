#!/usr/bin/env bash
# install_protect_all.sh — Pterodactyl Protect (All-in-One)
# Mode: Pasang SEMUA proteksi sekaligus. Backup otomatis. Pesan “kasar” dipertahankan sesuai permintaan.
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
    mv "$TARGET" "$BAK"
    echo "📦 Backup file lama: $BAK"
  fi
}

echo "🚀 Memasang semua proteksi Pterodactyl (All-in-One)…"
echo "🕒 Timestamp: $TS"
echo

# ========== 1) Anti Delete & Modifikasi Server ==========
echo "➡️  Proteksi: Anti Delete & Modifikasi Server"

# ServerDeletionService.php
TARGET="/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
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
                    throw new DisplayException('❌Akses ditolak:  Wawes Sikontol Mau hapus server orang 😹,Anda hanya dapat menghapus server milik Anda sendiri @protect depstore');
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
echo "✅ ServerDeletionService.php selesai."

# DetailsModificationService.php
TARGET="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
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
            abort(403, 'Akses ditolak: hanya admin utama yang bisa mengubah detail server.');
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
echo "✅ DetailsModificationService.php selesai."
echo

# ========== 2) Anti Akses Server & File ==========
echo "➡️  Proteksi: Anti Akses Server & File"

# ServerController.php
TARGET="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
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
            abort(403, '𝗔𝗸𝘀𝗲𝘀 𝗗𝗶 𝗧𝗼𝗹𝗮𝗸❌. 𝗛𝗮𝗻𝘆𝗮 𝗕𝗶𝗹𝗮 𝗠𝗶𝗹𝗶𝗸 𝗦𝗲𝗻𝗱𝗶𝗿𝗶.');
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
echo "✅ ServerController.php selesai."

# FileController.php
TARGET="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Carbon\CarbonImmutable;
use Illuminate\Http\Response;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Services\Nodes\NodeJWTService;
use Pterodactyl\Repositories\Wings\DaemonFileRepository;
use Pterodactyl\Transformers\Api\Client\FileObjectTransformer;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CopyFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\PullFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ListFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\ChmodFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DeleteFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\RenameFileRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CreateFolderRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\CompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\DecompressFilesRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\GetFileContentsRequest;
use Pterodactyl\Http\Requests\Api\Client\Servers\Files\WriteFileContentRequest;

class FileController extends ClientApiController
{
    public function __construct(
        private NodeJWTService $jwtService,
        private DaemonFileRepository $fileRepository
    ) {
        parent::__construct();
    }

    private function checkServerAccess($request, Server $server)
    {
        $user = $request->user();
        if ($user->id === 1) return;
        if ($server->owner_id !== $user->id) {
            abort(403, 'Anda tidak memiliki akses ke server ini.');
        }
    }

    public function directory(ListFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $contents = $this->fileRepository
            ->setServer($server)
            ->getDirectory($request->get('directory') ?? '/');

        return $this->fractal->collection($contents)
            ->transformWith($this->getTransformer(FileObjectTransformer::class))
            ->toArray();
    }

    public function contents(GetFileContentsRequest $request, Server $server): Response
    {
        $this->checkServerAccess($request, $server);

        $response = $this->fileRepository->setServer($server)->getContent(
            $request->get('file'),
            config('pterodactyl.files.max_edit_size')
        );

        Activity::event('server:file.read')->property('file', $request->get('file'))->log();

        return new Response($response, Response::HTTP_OK, ['Content-Type' => 'text/plain']);
    }

    public function download(GetFileContentsRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);

        $token = $this->jwtService
            ->setExpiresAt(CarbonImmutable::now()->addMinutes(15))
            ->setUser($request->user())
            ->setClaims([
                'file_path' => rawurldecode($request->get('file')),
                'server_uuid' => $server->uuid,
            ])
            ->handle($server->node, $request->user()->id . $server->uuid);

        Activity::event('server:file.download')->property('file', $request->get('file'))->log();

        return [
            'object' => 'signed_url',
            'attributes' => [
                'url' => sprintf(
                    '%s/download/file?token=%s',
                    $server->node->getConnectionAddress(),
                    $token->toString()
                ),
            ],
        ];
    }

    public function write(WriteFileContentRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->putContent($request->get('file'), $request->getContent());
        Activity::event('server:file.write')->property('file', $request->get('file'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function create(CreateFolderRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->createDirectory($request->input('name'), $request->input('root', '/'));
        Activity::event('server:file.create-directory')->property('name', $request->input('name'))->property('directory', $request->input('root'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function rename(RenameFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->renameFiles($request->input('root'), $request->input('files'));
        Activity::event('server:file.rename')->property('directory', $request->input('root'))->property('files', $request->input('files'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function copy(CopyFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->copyFile($request->input('location'));
        Activity::event('server:file.copy')->property('file', $request->input('location'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function compress(CompressFilesRequest $request, Server $server): array
    {
        $this->checkServerAccess($request, $server);
        $file = $this->fileRepository->setServer($server)->compressFiles($request->input('root'), $request->input('files'));
        Activity::event('server:file.compress')->property('directory', $request->input('root'))->property('files', $request->input('files'))->log();
        return $this->fractal->item($file)->transformWith($this->getTransformer(FileObjectTransformer::class))->toArray();
    }

    public function decompress(DecompressFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        set_time_limit(300);
        $this->fileRepository->setServer($server)->decompressFile($request->input('root'), $request->input('file'));
        Activity::event('server:file.decompress')->property('directory', $request->input('root'))->property('files', $request->input('file'))->log();
        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }

    public function delete(DeleteFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->deleteFiles($request->input('root'), $request->input('files'));
        Activity::event('server:file.delete')->property('directory', $request->input('root'))->property('files', $request->input('files'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function chmod(ChmodFilesRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->chmodFiles($request->input('root'), $request->input('files'));
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }

    public function pull(PullFileRequest $request, Server $server): JsonResponse
    {
        $this->checkServerAccess($request, $server);
        $this->fileRepository->setServer($server)->pull($request->input('url'), $request->input('directory'), $request->safe(['filename', 'use_header', 'foreground']));
        Activity::event('server:file.pull')->property('directory', $request->input('directory'))->property('url', $request->input('url'))->log();
        return new JsonResponse([], Response::HTTP_NO_CONTENT);
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ FileController.php selesai."
echo

# ========== 3) Anti Akses Settings Panel ==========
echo "➡️  Proteksi: Anti Akses Settings Panel"

TARGET="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Settings;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Settings\BaseSettingsFormRequest;

class IndexController extends Controller
{
    use AvailableLanguages;

    public function __construct(
        private AlertsMessageBag $alert,
        private Kernel $kernel,
        private SettingsRepositoryInterface $settings,
        private SoftwareVersionService $versionService,
        private ViewFactory $view
    ) {
    }

    public function index(): View
    {
        // 🔒 Hanya user ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        return $this->view->make('admin.settings.index', [
            'version' => $this->versionService,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    public function update(BaseSettingsFormRequest $request): RedirectResponse
    {
        // 🔒 Hanya user ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        foreach ($request->normalize() as $key => $value) {
            $this->settings->set('settings::' . $key, $value);
        }

        $this->kernel->call('queue:restart');
        $this->alert->success(
            'Panel settings have been updated successfully and the queue worker was restarted to apply these changes.'
        )->flash();

        return redirect()->route('admin.settings');
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ Settings IndexController.php selesai."
echo

# ========== 4) Anti Akses Nests & Eggs ==========
echo "➡️  Proteksi: Anti Akses Nests & Eggs"

TARGET="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nests;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Nests\NestUpdateService;
use Pterodactyl\Services\Nests\NestCreationService;
use Pterodactyl\Services\Nests\NestDeletionService;
use Pterodactyl\Contracts\Repository\NestRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Nest\StoreNestFormRequest;
use Illuminate\Support\Facades\Auth;

class NestController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected NestCreationService $nestCreationService,
        protected NestDeletionService $nestDeletionService,
        protected NestRepositoryInterface $repository,
        protected NestUpdateService $nestUpdateService,
        protected ViewFactory $view
    ) {
    }

    public function index(): View
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin utama (ID 1) yang bisa membuka menu Nests.');
        }

        return $this->view->make('admin.nests.index', [
            'nests' => $this->repository->getWithCounts(),
        ]);
    }

    public function create(): View
    {
        return $this->view->make('admin.nests.new');
    }

    public function store(StoreNestFormRequest $request): RedirectResponse
    {
        $nest = $this->nestCreationService->handle($request->normalize());
        $this->alert->success(trans('admin/nests.notices.created', ['name' => htmlspecialchars($nest->name)]))->flash();
        return redirect()->route('admin.nests.view', $nest->id);
    }

    public function view(int $nest): View
    {
        return $this->view->make('admin.nests.view', [
            'nest' => $this->repository->getWithEggServers($nest),
        ]);
    }

    public function update(StoreNestFormRequest $request, int $nest): RedirectResponse
    {
        $this->nestUpdateService->handle($nest, $request->normalize());
        $this->alert->success(trans('admin/nests.notices.updated'))->flash();
        return redirect()->route('admin.nests.view', $nest);
    }

    public function destroy(int $nest): RedirectResponse
    {
        $this->nestDeletionService->handle($nest);
        $this->alert->success(trans('admin/nests.notices.deleted'))->flash();
        return redirect()->route('admin.nests');
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ NestController.php selesai."
echo

# ========== 5) Anti Akses Nodes ==========
echo "➡️  Proteksi: Anti Akses Nodes"

TARGET="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin\Nodes;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Facades\Auth;

class NodeController extends Controller
{
    public function __construct(private ViewFactory $view)
    {
    }

    public function index(Request $request): View
    {
        // 🔒 Hanya admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, '🚫 Akses ditolak! Hanya admin ID 1 yang dapat membuka menu Nodes. ©protect by depstore');
        }

        $nodes = QueryBuilder::for(
            Node::query()->with('location')->withCount('servers')
        )
            ->allowedFilters(['uuid', 'name'])
            ->allowedSorts(['id'])
            ->paginate(25);

        return $this->view->make('admin.nodes.index', ['nodes' => $nodes]);
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ NodeController.php selesai."
echo

# ========== 6) Anti Akses Locations ==========
echo "➡️  Proteksi: Anti Akses Locations"

TARGET="/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Location;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Requests\Admin\LocationFormRequest;
use Pterodactyl\Services\Locations\LocationUpdateService;
use Pterodactyl\Services\Locations\LocationCreationService;
use Pterodactyl\Services\Locations\LocationDeletionService;
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;

class LocationController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected LocationCreationService $creationService,
        protected LocationDeletionService $deletionService,
        protected LocationRepositoryInterface $repository,
        protected LocationUpdateService $updateService,
        protected ViewFactory $view
    ) {
    }

    public function index(): View
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'Akses ditolak');
        }

        return $this->view->make('admin.locations.index', [
            'locations' => $this->repository->getAllWithDetails(),
        ]);
    }

    public function view(int $id): View
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        return $this->view->make('admin.locations.view', [
            'location' => $this->repository->getWithNodes($id),
        ]);
    }

    public function create(LocationFormRequest $request): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        $location = $this->creationService->handle($request->normalize());
        $this->alert->success('Location was created successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    public function update(LocationFormRequest $request, Location $location): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        if ($request->input('action') === 'delete') {
            return $this->delete($location);
        }

        $this->updateService->handle($location->id, $request->normalize());
        $this->alert->success('Location was updated successfully.')->flash();

        return redirect()->route('admin.locations.view', $location->id);
    }

    public function delete(Location $location): RedirectResponse
    {
        // 🔒 Cegah akses selain admin ID 1
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, 'BOCAH TOLOL NGINTIP NGINTIP ');
        }

        try {
            $this->deletionService->handle($location->id);
            return redirect()->route('admin.locations');
        } catch (DisplayException $ex) {
            $this->alert->danger($ex->getMessage())->flash();
        }

        return redirect()->route('admin.locations.view', $location->id);
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ LocationController.php selesai."
echo

# ========== 7) Anti Hapus User ==========
# ========== 8) Anti Ubah Data User ==========
echo "➡️  Proteksi: Anti Hapus & Ubah Data User"

TARGET="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
backup_then "$TARGET"
cat >"$TARGET" <<'PHP'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Model;
use Illuminate\Support\Collection;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Spatie\QueryBuilder\QueryBuilder;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\Translation\Translator;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Http\Requests\Admin\NewUserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;

class UserController extends Controller
{
    use AvailableLanguages;

    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected Translator $translator,
        protected UserUpdateService $updateService,
        protected UserRepositoryInterface $repository,
        protected ViewFactory $view
    ) {
    }

    public function index(Request $request): View
    {
        $users = QueryBuilder::for(
            User::query()->select('users.*')
                ->selectRaw('COUNT(DISTINCT(subusers.id)) as subuser_of_count')
                ->selectRaw('COUNT(DISTINCT(servers.id)) as servers_count')
                ->leftJoin('subusers', 'subusers.user_id', '=', 'users.id')
                ->leftJoin('servers', 'servers.owner_id', '=', 'users.id')
                ->groupBy('users.id')
        )
            ->allowedFilters(['username', 'email', 'uuid'])
            ->allowedSorts(['id', 'uuid'])
            ->paginate(50);

        return $this->view->make('admin.users.index', ['users' => $users]);
    }

    public function create(): View
    {
        return $this->view->make('admin.users.new', [
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    public function view(User $user): View
    {
        return $this->view->make('admin.users.view', [
            'user' => $user,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    /**
     * @throws \Exception
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function delete(Request $request, User $user): RedirectResponse
    {
        // === Proteksi hapus user ===
        if ($request->user()->id !== 1) {
            throw new DisplayException("❌ Hanya admin ID 1 yang dapat menghapus user lain!");
        }

        if ($request->user()->id === $user->id) {
            throw new DisplayException($this->translator->get('admin/user.exceptions.user_has_servers'));
        }

        $this->deletionService->handle($user);
        return redirect()->route('admin.users');
    }

    /**
     * @throws \Pterodactyl\Exceptions\Model\DataValidationException
     * @throws \Pterodactyl\Exceptions\Repository\RecordNotFoundException
     */
    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        // === Proteksi ubah data penting ===
        $restricted = ['email', 'first_name', 'last_name', 'password'];
        foreach ($restricted as $field) {
            if ($request->filled($field) && $request->user()->id !== 1) {
                throw new DisplayException("⚠️ Data hanya bisa diubah oleh admin ID 1.");
            }
        }

        if ($user->root_admin && $request->user()->id !== 1) {
            throw new DisplayException("🚫 Tidak dapat menurunkan hak admin pengguna ini. Hanya ID 1 yang memiliki izin.");
        }

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $request->normalize());

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();
        return redirect()->route('admin.users.view', $user->id);
    }

    public function json(Request $request): Model|Collection
    {
        $users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            $user->md5 = md5(strtolower($user->email));
            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));
            return $item;
        });
    }
}
PHP
chmod 644 "$TARGET"
echo "✅ UserController.php selesai."
echo

echo "🎉 Semua 8 kategori proteksi terpasang!"
echo "📦 File lama dibackup dengan suffix: .bak_${TS}"
echo ""
echo "🔒 Kategori yang dipasang:"
echo "   1. Anti Delete & Modifikasi Server"
echo "   2. Anti Akses Server & File" 
echo "   3. Anti Akses Settings Panel"
echo "   4. Anti Akses Nests & Eggs"
echo "   5. Anti Akses Nodes"
echo "   6. Anti Akses Locations"
echo "   7. Anti Hapus User"
echo "   8. Anti Ubah Data User"
echo ""
echo "✅ Installasi selesai!"
