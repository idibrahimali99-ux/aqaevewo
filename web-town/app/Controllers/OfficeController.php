<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class OfficeController extends Controller
{
    public function index(): void
    {
        $response = api_client()->get('offices/list', ['limit' => 50]);
        $items = enrich_offices_with_post_counts(is_array($response['items'] ?? null) ? $response['items'] : []);
        $this->view('pages/offices', [
            'title' => 'المكاتب العقارية',
            'items' => $items,
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
        ]);
    }

    public function marketers(): void
    {
        $response = api_client()->get('marketers/list', ['limit' => 50]);
        $items = enrich_offices_with_post_counts(is_array($response['items'] ?? null) ? $response['items'] : []);
        foreach ($items as &$item) {
            if (is_array($item)) {
                $item['is_marketer'] = 1;
            }
        }
        unset($item);
        $this->view('pages/marketers', [
            'title' => 'المسوقون العقاريون',
            'items' => $items,
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
        ]);
    }

    public function show(string $id): void
    {
        $detail = api_client()->get('offices/detail', ['id' => $id]);
        if (empty($detail['ok'])) {
            http_response_code(404);
            $this->view('errors/404', ['title' => 'المكتب غير موجود']);
            return;
        }
        $office = $detail['office'] ?? $detail;
        $properties = api_client()->get('properties/list', ['owner_id' => $id, 'limit' => 200]);
        $reels = api_client()->get('reels/list', ['owner_id' => $id, 'limit' => 20]);
        $this->view('pages/office-profile', [
            'title' => (string) ($office['office_name'] ?? $office['full_name'] ?? 'مكتب'),
            'office' => $office,
            'properties' => $properties['items'] ?? [],
            'reels' => $reels['items'] ?? [],
        ]);
    }

    public function marketerShow(string $id): void
    {
        $detail = api_client()->get('marketers/detail', ['id' => $id]);
        if (empty($detail['ok'])) {
            http_response_code(404);
            $this->view('errors/404', ['title' => 'المسوق غير موجود']);
            return;
        }
        $marketer = $detail['marketer'] ?? $detail['office'] ?? $detail;
        $properties = api_client()->get('properties/list', ['owner_id' => $id, 'limit' => 200]);
        $reels = api_client()->get('reels/list', ['owner_id' => $id, 'limit' => 20]);
        $this->view('pages/marketer-profile', [
            'title' => (string) ($marketer['office_name'] ?? $marketer['full_name'] ?? 'مسوق'),
            'marketer' => $marketer,
            'properties' => $properties['items'] ?? [],
            'reels' => $reels['items'] ?? [],
        ]);
    }
}
