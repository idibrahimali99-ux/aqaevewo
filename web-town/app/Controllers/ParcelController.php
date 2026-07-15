<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class ParcelController extends Controller
{
    public function index(): void
    {
        $govs = api_client()->get('app/governorates');
        $response = api_client()->get('parcels/list', [
            'governorate' => trim((string) ($_GET['governorate'] ?? '')),
            'limit' => 50,
        ]);
        $items = is_array($response['items'] ?? null) ? $response['items'] : [];
        $govFilter = trim((string) ($_GET['governorate'] ?? ''));
        if ($govFilter !== '') {
            $items = array_values(array_filter($items, static fn(array $row): bool => trim((string) ($row['governorate'] ?? '')) === $govFilter));
        }
        $this->view('parcels/index', [
            'title' => 'المقاطعات',
            'items' => $items,
            'governorates' => $govs['items'] ?? $govs['governorates'] ?? [],
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
        ]);
    }

    public function show(string $id): void
    {
        $properties = api_client()->get('properties/list', [
            'parcel_id' => $id,
            'include_mine' => '1',
            'limit' => 200,
        ]);
        $this->view('parcels/show', [
            'title' => trim((string) ($_GET['title'] ?? 'مقاطعة')),
            'parcelId' => $id,
            'properties' => $properties['items'] ?? [],
        ]);
    }
}
