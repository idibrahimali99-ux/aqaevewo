<?php
declare(strict_types=1);

/** @param array<string,mixed> $row */
function chat_thread_title(array $row, ?array $user = null): string
{
    $user ??= auth_user();
    $uid = (string) ($user['id'] ?? '');
    $role = (string) ($user['role'] ?? '');

    if ($role === 'admin' || $role === 'staff') {
        $customer = trim((string) ($row['customer_display_name'] ?? $row['customer_name'] ?? ''));
        $office = trim((string) ($row['office_display_name'] ?? $row['office_name'] ?? ''));
        if ($customer !== '' && $office !== '') {
            return $customer . ' ↔ ' . $office;
        }
        return $customer !== '' ? $customer : ($office !== '' ? $office : 'محادثة');
    }

    $isAdvertiser = (string) ($row['office_user_id'] ?? '') === $uid;
    if ($isAdvertiser) {
        $name = trim((string) ($row['first_sender_name'] ?? $row['admin_name'] ?? ''));
        return $name !== '' ? $name : 'مستفسر';
    }

    $office = trim((string) ($row['admin_name'] ?? ''));
    if ($office === '') {
        $office = 'عقار تاون';
    }
    $prop = trim((string) ($row['property_title'] ?? ''));
    if ($prop !== '') {
        return $prop . ' · ' . $office;
    }
    return $office;
}

/** @param array<string,mixed> $row */
function chat_thread_subtitle(array $row): string
{
    $preview = trim((string) ($row['last_message_preview'] ?? ''));
    if ($preview !== '') {
        return $preview;
    }
    $prop = trim((string) ($row['property_title'] ?? ''));
    if ($prop !== '') {
        return $prop;
    }
    return 'بدون رسائل بعد';
}

/** @param array<string,mixed> $row */
function chat_thread_avatar(array $row): string
{
    $thumb = trim((string) ($row['property_thumb_url'] ?? ''));
    if ($thumb !== '') {
        return $thumb;
    }
    return asset_url('images/placeholder-property.svg');
}

function web_route_from_app(string $target): string
{
    $target = trim($target);
    if ($target === '') {
        return url('/');
    }
    if (str_starts_with($target, 'http')) {
        return $target;
    }
    $path = preg_replace('#^/app#', '', $target) ?: '/';
    if (str_starts_with($path, '/search')) {
        return url('/search' . (str_contains($path, '?') ? substr($path, strpos($path, '?')) : ''));
    }
    $aliases = [
        '/offices' => '/offices',
        '/parcels' => '/parcels',
        '/compounds' => '/compounds',
        '/reels' => '/reels',
        '/map' => '/map',
        '/home' => '/',
    ];
    $base = strtok($path, '?') ?: '/';
    $query = str_contains($path, '?') ? substr($path, strpos($path, '?')) : '';
    if (isset($aliases[$base])) {
        return url($aliases[$base] . $query);
    }

    return url($path);
}

function home_section_icon(string $name): string
{
    return match ($name) {
        'apartment', 'building' => 'fa-building',
        'grid' => 'fa-border-all',
        'city' => 'fa-city',
        'home' => 'fa-house',
        'land' => 'fa-map',
        'shop' => 'fa-store',
        'villa' => 'fa-house-chimney',
        default => 'fa-compass',
    };
}
