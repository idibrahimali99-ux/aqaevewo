<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class HomeController extends Controller
{
    public function index(): void
    {
        $bootstrap = api_get_resilient('app/bootstrap');
        $properties = api_get_resilient('properties/list', ['limit' => 12]);
        $offices = api_get_resilient('offices/list', ['limit' => 6]);
        $parcels = api_get_resilient('parcels/list', ['limit' => 8]);
        $compounds = api_get_resilient('compounds/list', ['limit' => 8]);
        $compoundItems = is_array($compounds['items'] ?? null) ? $compounds['items'] : [];

        $apiError = '';
        if (empty($bootstrap['ok'])) {
            $apiError = (string) ($bootstrap['error'] ?? 'تعذر الاتصال بخدمة API');
            $snippet = trim((string) ($bootstrap['raw_snippet'] ?? ''));
            if ($snippet !== '' && (bool) app_config('debug', false)) {
                $apiError .= ' — ' . $snippet;
            }
            $entry = trim((string) ($bootstrap['api_entry'] ?? app_config('api_entry', '')));
            if ($entry !== '') {
                $apiError .= ' [' . $entry . ']';
            }
        }

        $this->view('home/index', [
            'title' => 'الرئيسية',
            'bootstrap' => $bootstrap,
            'promotions' => $bootstrap['promotions'] ?? [],
            'news' => $bootstrap['property_news'] ?? [],
            'sections' => $bootstrap['home_sections'] ?? [],
            'properties' => $properties['items'] ?? [],
            'offices' => $offices['items'] ?? [],
            'parcels' => $parcels['items'] ?? [],
            'compounds' => $compoundItems,
            'api_error' => $apiError,
        ]);
    }
}
