<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class NewsController extends Controller
{
    public function show(string $id): void
    {
        $response = api_client()->get('app_property_news_get', ['id' => $id]);
        if (empty($response['ok'])) {
            $response = api_client()->get('app/property-news/get', ['id' => $id]);
        }
        if (empty($response['ok'])) {
            http_response_code(404);
            $this->view('errors/404', ['title' => 'الخبر غير موجود']);
            return;
        }
        $this->view('news/show', [
            'title' => (string) ($response['news']['title'] ?? $response['item']['title'] ?? 'خبر'),
            'news' => $response['news'] ?? $response['item'] ?? $response,
        ]);
    }
}
