<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class PropertyController extends Controller
{
    public function index(): void
    {
        $govs = api_client()->get('app/governorates');
        $response = api_client()->get('properties/list', [
            'q' => trim((string) ($_GET['q'] ?? '')),
            'governorate' => trim((string) ($_GET['governorate'] ?? '')),
            'purpose' => trim((string) ($_GET['purpose'] ?? '')),
            'category' => trim((string) ($_GET['cat'] ?? $_GET['category'] ?? '')),
            'segment' => trim((string) ($_GET['segment'] ?? '')),
            'limit' => 120,
        ]);
        $items = is_array($response['items'] ?? null) ? $response['items'] : [];
        $purpose = trim((string) ($_GET['purpose'] ?? ''));
        $governorate = trim((string) ($_GET['governorate'] ?? ''));
        $category = trim((string) ($_GET['cat'] ?? $_GET['category'] ?? ''));
        $segment = trim((string) ($_GET['segment'] ?? ''));
        if ($purpose !== '') {
            $items = array_values(array_filter($items, static fn (mixed $row): bool => is_array($row) && (string) ($row['purpose'] ?? '') === $purpose));
        }
        if ($governorate !== '') {
            $items = array_values(array_filter($items, static function (mixed $row) use ($governorate): bool {
                if (!is_array($row)) {
                    return false;
                }
                $gov = (string) ($row['governorate'] ?? '');

                return $gov === $governorate || mb_stripos($gov, $governorate) !== false;
            }));
        }
        if ($category !== '') {
            $items = array_values(array_filter($items, static fn (mixed $row): bool => is_array($row) && (string) ($row['category'] ?? '') === $category));
        }
        if ($segment !== '') {
            $items = array_values(array_filter($items, static fn (mixed $row): bool => is_array($row) && (string) ($row['segment'] ?? 'standard') === $segment));
        }
        $path = current_path();
        $this->view('properties/index', [
            'title' => str_starts_with($path, '/search') ? 'البحث والفلترة' : (trim((string) ($_GET['q'] ?? '')) !== '' ? 'نتائج البحث' : 'العقارات'),
            'items' => $items,
            'governorates' => $govs['items'] ?? $govs['governorates'] ?? [],
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
        ]);
    }

    public function search(): void
    {
        $this->index();
    }

    public function show(string $id): void
    {
        $response = api_client()->get('properties/get', ['id' => $id]);
        if (empty($response['ok'])) {
            http_response_code(404);
            $this->view('errors/404', ['title' => 'العقار غير موجود']);
            return;
        }
        $this->view('properties/show', [
            'title' => (string) ($response['property']['title'] ?? 'تفاصيل العقار'),
            'property' => $response['property'] ?? $response,
            'images' => is_array($response['images'] ?? null) ? $response['images'] : [],
            'videoUrl' => (string) ($response['video_url'] ?? ($response['property']['video_url'] ?? '')),
        ]);
    }

    public function contact(string $id): void
    {
        verify_csrf();
        $user = require_login();
        $data = api_client()->post('chat/thread/open', ['property_id' => $id], auth_token());
        $threadId = (string) ($data['thread_id'] ?? $data['id'] ?? '');
        if ($threadId !== '') {
            redirect_to('/messages', ['thread' => $threadId]);
        }
        redirect_to('/property/' . $id, ['error' => (string) ($data['error'] ?? 'تعذر فتح المحادثة')]);
    }
}
