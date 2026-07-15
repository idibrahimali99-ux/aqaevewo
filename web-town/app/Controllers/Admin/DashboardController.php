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

    public function section(string $section = 'overview'): void
    {
        $sectionDef = admin_section($section);
        if ($sectionDef === null || !admin_can_access_section($sectionDef)) {
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
        ];
        $richView = admin_section_template($section);
        $this->view($richView ?? 'admin/section', $viewData, 'admin');
    }
}
