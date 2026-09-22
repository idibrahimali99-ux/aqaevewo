<?php
declare(strict_types=1);

namespace App\Controllers\Admin;

use App\Core\Controller;

final class DashboardController extends Controller
{
    public function index(): void
    {
        redirect_to('/admin/overview');
    }

    public function userProfile(string $id = ''): void
    {
        $id = trim($id);
        redirect_to('/admin/users', $id !== '' ? ['profile' => $id] : []);
    }

    public function section(string $section = 'overview'): void
    {
        $sectionDef = admin_section($section);
        if ($sectionDef === null || !admin_can_access_section($sectionDef)) {
            if ($section !== '' && $section !== 'overview') {
                http_response_code($sectionDef === null ? 404 : 403);
                $this->view('admin/sections/user_profile', [
                    'title' => 'تعذر فتح الصفحة',
                    'user' => auth_user(),
                    'sectionKey' => $section,
                    'section' => $sectionDef ?? ['label' => 'غير متاح', 'tabs' => [], 'operations' => []],
                    'data' => [
                        'ok' => false,
                        'error' => $sectionDef === null
                            ? 'هذا القسم غير موجود.'
                            : 'لا تملك صلاحية فتح هذا القسم.',
                    ],
                    'stats' => [],
                    'apiMeta' => [
                        'entry' => (string) app_config('api_entry'),
                        'token_type' => auth_token_type(),
                        'stats_ok' => false,
                        'stats_error' => '',
                    ],
                    'operationResult' => null,
                    'currentSection' => $section,
                    'homeSections' => [],
                    'serverStats' => [],
                    'telegramMeta' => [],
                    'forcedError' => true,
                ], 'admin');
                return;
            }
            $section = admin_default_section();
            $sectionDef = admin_section($section);
        }
        $operationResult = null;
        if (request_method() === 'POST') {
            verify_csrf();
            $operationKey = (string) ($_POST['_operation'] ?? '');
            $operationResult = run_admin_operation($section, $operationKey, $_POST);
        }
        $data = admin_section_data($section, $_GET);
        $stats = in_array($section, ['overview', 'notifications'], true)
            ? $data
            : admin_fetch_stats();
        $apiMeta = [
            'entry' => (string) app_config('api_entry'),
            'token_type' => auth_token_type(),
            'stats_ok' => !empty($stats['ok']),
            'stats_error' => (string) ($stats['error'] ?? ''),
        ];

        if (in_array($section, ['chats', 'chat_room'], true)) {
            $this->view('admin/messenger', [
                'title' => (string) ($sectionDef['label'] ?? 'المحادثات'),
                'user' => auth_user(),
                'sectionKey' => $section,
                'section' => $sectionDef,
                'stats' => $stats,
                'apiMeta' => $apiMeta,
                'currentSection' => $section,
                'activeThread' => trim((string) ($_GET['thread'] ?? '')),
            ], 'admin');
            return;
        }

        $homeSections = [];
        $serverStats = [];
        $telegramMeta = [];
        $appUpdate = [];
        if ($section === 'settings') {
            if (empty($data['ok'])) {
                $retry = api_get_resilient('health');
                if (!empty($retry['ok'])) {
                    $data = $retry;
                }
            }
            $hs = api_client()->get('admin/home-sections', [], auth_token());
            $homeSections = is_array($hs['items'] ?? null) ? $hs['items'] : [];
            $serverStats = admin_local_server_stats();
            $remoteStats = api_client()->get('admin/server-stats', [], auth_token());
            if (!empty($remoteStats['ok'])) {
                $serverStats = $remoteStats;
            }
            $telegramMeta = api_client()->get('admin/telegram', [], auth_token());
            $appUpdate = api_client()->get('admin/app-update', [], auth_token());
        }

        $viewData = [
            'title' => (string) ($sectionDef['label'] ?? 'لوحة الإدارة'),
            'user' => auth_user(),
            'sectionKey' => $section,
            'section' => $sectionDef,
            'data' => $data,
            'stats' => $stats,
            'apiMeta' => $apiMeta,
            'operationResult' => $operationResult,
            'currentSection' => $section,
            'homeSections' => $homeSections,
            'serverStats' => $serverStats,
            'telegramMeta' => $telegramMeta,
            'appUpdate' => $appUpdate,
            'openedProfile' => null,
            'openedProfileId' => '',
            'openedProfileProperties' => [],
        ];
        if ($section === 'users') {
            $openedId = trim((string) ($_GET['profile'] ?? ''));
            if ($openedId !== '') {
                $viewData['openedProfileId'] = $openedId;
                $detail = api_client()->get(
                    'admin/user',
                    ['id' => $openedId, 'user_id' => $openedId],
                    auth_token()
                );
                $fromApi = is_array($detail['user'] ?? null) ? $detail['user'] : null;
                $fromApiId = is_array($fromApi) ? trim((string) ($fromApi['id'] ?? '')) : '';
                if (is_array($fromApi) && ($fromApiId === '' || strcasecmp($fromApiId, $openedId) === 0)) {
                    $viewData['openedProfile'] = $fromApi;
                }
                if (is_array($detail['properties'] ?? null)) {
                    $viewData['openedProfileProperties'] = $detail['properties'];
                }
            }
        }
        $richView = admin_section_template($section);
        $this->view($richView ?? 'admin/section', $viewData, 'admin');
    }
}
