<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class HomeController extends Controller
{
    public function index(): void
    {
        $bootstrap = api_client()->get('app/bootstrap');
        $properties = api_client()->get('properties/list', ['limit' => 12]);
        $offices = api_client()->get('offices/list', ['limit' => 6]);
        $parcels = api_client()->get('parcels/list', ['limit' => 8]);
        $compounds = api_client()->get('compounds/list', ['limit' => 8]);
        $this->view('home/index', [
            'title' => 'الرئيسية',
            'bootstrap' => $bootstrap,
            'promotions' => $bootstrap['promotions'] ?? [],
            'news' => $bootstrap['property_news'] ?? [],
            'sections' => $bootstrap['home_sections'] ?? [],
            'properties' => $properties['items'] ?? [],
            'offices' => $offices['items'] ?? [],
            'parcels' => $parcels['items'] ?? [],
            'compounds' => $compounds['items'] ?? [],
            'api_error' => empty($bootstrap['ok']) ? (string) ($bootstrap['error'] ?? '') : '',
        ]);
    }
}
