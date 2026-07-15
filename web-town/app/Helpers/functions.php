<?php
declare(strict_types=1);

use App\Core\App;

function app_config(?string $key = null, mixed $default = null): mixed
{
    return App::config($key, $default);
}

function e(mixed $value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function base_path(): string
{
    return rtrim((string) App::config('base_path', ''), '/');
}

function url(string $path = '', array $query = []): string
{
    $base = base_path();
    $path = '/' . ltrim($path, '/');
    $href = ($base === '' ? '' : $base) . ($path === '/' && $base !== '' ? '/' : $path);
    if ($query !== []) {
        $href .= '?' . http_build_query($query);
    }

    return $href;
}

function asset_url(string $path): string
{
    return url('/assets/' . ltrim($path, '/'));
}

function redirect_to(string $path, array $query = []): never
{
    header('Location: ' . url($path, $query));
    exit;
}

function current_path(): string
{
    $uri = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH) ?: '/';
    $base = base_path();
    if ($base !== '' && str_starts_with($uri, $base)) {
        $uri = substr($uri, strlen($base)) ?: '/';
    }

    return '/' . trim($uri, '/');
}

function is_active_path(string $path): bool
{
    $current = current_path();
    $normalized = '/' . trim($path, '/');
    return $current === $normalized || ($normalized !== '/' && str_starts_with($current, $normalized));
}

function money_iqd(mixed $amount): string
{
    if ($amount === null || $amount === '') {
        return 'السعر عند الاتصال';
    }

    return number_format((float) $amount, 0) . ' د.ع';
}

function compact_number(mixed $value): string
{
    $n = (int) ($value ?? 0);
    if ($n >= 1000000) {
        return round($n / 1000000, 1) . 'M';
    }
    if ($n >= 1000) {
        return round($n / 1000, 1) . 'K';
    }

    return (string) $n;
}

function pick(array $array, string $key, mixed $default = ''): mixed
{
    return $array[$key] ?? $default;
}

function first_image(array $item): string
{
    $candidates = [
        $item['thumb_url'] ?? '',
        $item['image_url'] ?? '',
        $item['cover_url'] ?? '',
    ];
    if (isset($item['image_urls']) && is_array($item['image_urls']) && !empty($item['image_urls'])) {
        array_unshift($candidates, (string) $item['image_urls'][0]);
    }

    foreach ($candidates as $candidate) {
        $candidate = trim((string) $candidate);
        if ($candidate !== '') {
            return $candidate;
        }
    }

    return asset_url('images/placeholder-property.svg');
}

function api_client(): \App\Models\ApiClient
{
    static $client = null;
    if ($client === null) {
        $client = new \App\Models\ApiClient((string) App::config('api_entry'));
    }

    return $client;
}

/** @return array<string,mixed>|null */
function property_details_array(array $property): ?array
{
    $details = $property['details_json'] ?? null;
    if (is_string($details) && trim($details) !== '') {
        $decoded = json_decode($details, true);
        $details = is_array($decoded) ? $decoded : null;
    }
    return is_array($details) ? $details : null;
}

/** @return array{lat:float,lng:float}|null */
function property_coordinates(array $property): ?array
{
    $details = property_details_array($property);
    $location = is_array($details['location'] ?? null) ? $details['location'] : null;
    if ($location === null) {
        return null;
    }
    $lat = (float) ($location['lat'] ?? 0);
    $lng = (float) ($location['lng'] ?? 0);
    if ($lat === 0.0 && $lng === 0.0) {
        return null;
    }
    if (abs($lat) > 90 || abs($lng) > 180) {
        return null;
    }

    return ['lat' => $lat, 'lng' => $lng];
}

/** @return list<string> */
function property_image_list(array $property, array $extraImages = []): array
{
    $images = [];
    if ($extraImages !== []) {
        $images = $extraImages;
    }
    foreach (['image_urls', 'images'] as $key) {
        $raw = $property[$key] ?? null;
        if (is_array($raw)) {
            foreach ($raw as $url) {
                $url = trim((string) $url);
                if ($url !== '' && !in_array($url, $images, true)) {
                    $images[] = $url;
                }
            }
        }
    }
    $rawJoined = trim((string) ($property['image_urls_raw'] ?? ''));
    if ($rawJoined !== '') {
        foreach (explode('|||', $rawJoined) as $url) {
            $url = trim($url);
            if ($url !== '' && !in_array($url, $images, true)) {
                $images[] = $url;
            }
        }
    }
    $thumb = trim((string) ($property['thumb_url'] ?? ''));
    if ($thumb !== '' && !in_array($thumb, $images, true)) {
        array_unshift($images, $thumb);
    }
    if ($images === []) {
        $images[] = first_image($property);
    }

    return $images;
}

function property_category_label(string $category): string
{
    return match ($category) {
        'apartment' => 'شقة',
        'house' => 'بيت',
        'villa' => 'فيلا',
        'land' => 'أرض',
        'shop' => 'محل',
        'compound' => 'مجمع',
        default => $category !== '' ? $category : 'عقار',
    };
}

function property_purpose_label(string $purpose): string
{
    return match ($purpose) {
        'rent' => 'للإيجار',
        'sale' => 'للبيع',
        default => $purpose !== '' ? $purpose : 'عقار',
    };
}

function property_segment_label(string $segment): string
{
    return match ($segment) {
        'parcel' => 'مقاطعة',
        'standard' => 'عادي',
        default => $segment !== '' ? $segment : '',
    };
}

/** @return array<string,string> */
function property_category_options(): array
{
    return [
        '' => 'كل الفئات',
        'house' => 'بيت',
        'apartment' => 'شقة',
        'villa' => 'فيلا',
        'land' => 'أرض',
        'shop' => 'محل',
        'compound' => 'مجمع',
    ];
}

/** @return array<string,string> */
function property_purpose_options(): array
{
    return [
        '' => 'الكل',
        'sale' => 'للبيع',
        'rent' => 'للإيجار',
    ];
}

function notification_total_count(array $counts): int
{
    $total = 0;
    foreach ($counts as $key => $value) {
        if ($key === 'chat_unread') {
            $total += (int) $value;
            continue;
        }
        $total += max(0, (int) $value);
    }

    return $total;
}

/** @param array<string,mixed> $item */
function notification_item_url(array $item): string
{
    $payload = is_array($item['payload'] ?? null) ? $item['payload'] : [];
    $type = (string) ($item['event_type'] ?? $payload['type'] ?? '');
    $propertyId = trim((string) ($payload['property_id'] ?? ''));
    $threadId = trim((string) ($payload['thread_id'] ?? ''));
    $reelId = trim((string) ($payload['reel_id'] ?? ''));
    if ($threadId !== '') {
        return url('/messages', ['thread' => $threadId]);
    }
    if ($propertyId !== '') {
        if (str_contains($type, 'reject') || str_contains($type, 'pending') || str_contains($type, 'approval')) {
            return url('/property/' . $propertyId);
        }
        return url('/property/' . $propertyId);
    }
    if ($reelId !== '') {
        return url('/reels', ['reel' => $reelId]);
    }
    if (str_contains($type, 'property_request')) {
        return url('/my-requests');
    }

    return url('/notifications');
}

function admin_notification_total(array $stats): int
{
    return (int) admin_stat_value($stats, ['pending_properties'])
        + (int) admin_stat_value($stats, ['pending_offices'])
        + (int) admin_stat_value($stats, ['pending_reels'])
        + (int) admin_stat_value($stats, ['chat_unread_threads', 'chat_unread']);
}

/** @return list<array{label:string,value:string}> */
function property_spec_rows(array $property): array
{
    $rows = [];
    $details = property_details_array($property) ?? [];
    $push = static function (string $label, mixed $value) use (&$rows): void {
        if ($value === null || $value === '' || $value === false) {
            return;
        }
        $rows[] = ['label' => $label, 'value' => is_scalar($value) ? (string) $value : json_encode($value, JSON_UNESCAPED_UNICODE)];
    };
    $push('المساحة', !empty($property['area_sqm']) ? number_format((float) $property['area_sqm'], 0) . ' م²' : '');
    $push('الفئة', property_category_label((string) ($property['category'] ?? '')));
    $segment = property_segment_label((string) ($property['segment'] ?? ''));
    if ($segment !== '') {
        $push('النوع', $segment);
    }
    $push('المجمع', (string) ($property['compound_name'] ?? $details['compound_name'] ?? ''));
    foreach ([
        'rooms' => 'الغرف',
        'bedrooms' => 'غرف النوم',
        'bathrooms' => 'الحمامات',
        'floor' => 'الطابق',
        'floors_count' => 'عدد الطوابق',
        'facade' => 'الواجهة',
        'deed_type' => 'نوع السند',
        'building_age' => 'عمر البناء',
    ] as $key => $label) {
        $push($label, $details[$key] ?? null);
    }
    if (!empty($details['negotiable'])) {
        $rows[] = ['label' => 'السعر', 'value' => 'قابل للتفاوض'];
    }

    return $rows;
}

function property_owner_label(array $property): string
{
    $office = trim((string) ($property['owner_office_name'] ?? $property['office_name'] ?? ''));
    $full = trim((string) ($property['owner_full_name'] ?? $property['owner_name'] ?? ''));
    if ($office !== '') {
        return $office;
    }
    if ($full !== '') {
        return $full;
    }

    return 'ناشر المنشور';
}

/** @return list<array<string,mixed>> */
function property_map_markers(array $items): array
{
    $markers = [];
    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }
        $coords = property_coordinates($item);
        if ($coords === null) {
            continue;
        }
        $id = (string) ($item['id'] ?? '');
        if ($id === '') {
            continue;
        }
        $markers[] = [
            'id' => $id,
            'lat' => $coords['lat'],
            'lng' => $coords['lng'],
            'title' => (string) ($item['title'] ?? 'عقار'),
            'price' => money_iqd($item['price_iqd'] ?? null),
            'governorate' => (string) ($item['governorate'] ?? ''),
            'thumb' => first_image($item),
            'url' => url('/property/' . $id),
        ];
    }

    return $markers;
}

function int_stat(mixed $value): int
{
    if (is_int($value)) {
        return $value;
    }
    if (is_float($value)) {
        return (int) $value;
    }
    if (is_string($value) && is_numeric($value)) {
        return (int) $value;
    }

    return 0;
}

function office_display_name(array $row): string
{
    $display = trim((string) ($row['display_name'] ?? ''));
    if ($display !== '') {
        return $display;
    }
    $office = trim((string) ($row['office_name'] ?? ''));
    if ($office !== '') {
        return $office;
    }
    $full = trim((string) ($row['full_name'] ?? ''));

    return $full !== '' ? $full : 'مكتب عقاري';
}

function parcel_display_name(array $row): string
{
    $name = trim((string) ($row['parcel_name'] ?? $row['name'] ?? ''));
    $no = trim((string) ($row['parcel_no'] ?? ''));
    if ($name === '' && $no !== '') {
        return 'مقاطعة ' . $no;
    }
    if ($name !== '' && $no !== '') {
        return $name . ' — ' . $no;
    }

    return $name !== '' ? $name : 'مقاطعة';
}

function compound_display_name(array $row): string
{
    $name = trim((string) ($row['compound_name'] ?? $row['name'] ?? ''));

    return $name !== '' ? $name : 'مجمع سكني';
}

/** @param list<array<string,mixed>> $items */
function enrich_offices_with_post_counts(array $items): array
{
    if ($items === []) {
        return $items;
    }
    $properties = api_client()->get('properties/list', ['limit' => 300]);
    $counts = [];
    foreach (is_array($properties['items'] ?? null) ? $properties['items'] : [] as $property) {
        if (!is_array($property)) {
            continue;
        }
        $ownerId = (string) ($property['owner_user_id'] ?? '');
        if ($ownerId === '') {
            continue;
        }
        $counts[$ownerId] = ($counts[$ownerId] ?? 0) + 1;
    }
    foreach ($items as &$item) {
        if (!is_array($item)) {
            continue;
        }
        $id = (string) ($item['id'] ?? '');
        $item['posts_count'] = $counts[$id] ?? 0;
        if (!isset($item['is_marketer'])) {
            $item['is_marketer'] = (($item['account_type'] ?? '') === 'marketer') ? 1 : 0;
        }
        $item['display_name'] = office_display_name($item);
    }
    unset($item);

    return $items;
}

function account_kind_label(?array $user = null): string
{
    return match (account_kind($user)) {
        'admin' => 'مسؤول',
        'staff' => 'موظف',
        'office' => 'مكتب عقاري',
        'marketer' => 'مسوق',
        'customer' => 'زبون',
        default => 'زائر',
    };
}
