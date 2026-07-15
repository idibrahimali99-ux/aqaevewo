<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class CompoundController extends Controller
{
    public function index(): void
    {
        $response = api_client()->get('compounds/list', [
            'governorate' => trim((string) ($_GET['governorate'] ?? '')),
            'limit' => 50,
        ]);
        $this->view('compounds/index', [
            'title' => 'المجمعات السكنية',
            'items' => $response['items'] ?? [],
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
        ]);
    }

    public function show(string $id): void
    {
        $properties = api_client()->get('properties/list', [
            'compound_id' => $id,
            'include_mine' => '1',
            'limit' => 200,
        ]);
        $this->view('compounds/show', [
            'title' => trim((string) ($_GET['title'] ?? 'مجمع سكني')),
            'compoundId' => $id,
            'properties' => $properties['items'] ?? [],
        ]);
    }
}
