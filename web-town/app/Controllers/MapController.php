<?php

declare(strict_types=1);



namespace App\Controllers;



use App\Core\Controller;



final class MapController extends Controller

{

    public function index(): void

    {

        $response = api_client()->get('properties/list', ['limit' => 250]);

        $items = is_array($response['items'] ?? null) ? $response['items'] : [];

        $markers = property_map_markers($items);

        $this->view('map/index', [

            'title' => 'خريطة العقارات',

            'items' => $items,

            'markers' => $markers,

            'mapsKey' => (string) app_config('google_maps_key', ''),

            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',

        ]);

    }

}

