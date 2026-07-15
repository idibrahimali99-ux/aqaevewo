<?php
declare(strict_types=1);

/** @return list<string> */
function favorite_ids(): array
{
    $ids = $_SESSION['favorites'] ?? [];
    if (!is_array($ids)) {
        return [];
    }

    return array_values(array_unique(array_filter(array_map('strval', $ids))));
}

function is_favorite(string $id): bool
{
    return in_array($id, favorite_ids(), true);
}

function toggle_favorite(string $id): bool
{
    $id = trim($id);
    if ($id === '') {
        return false;
    }
    $ids = favorite_ids();
    if (in_array($id, $ids, true)) {
        $_SESSION['favorites'] = array_values(array_filter($ids, static fn (string $v): bool => $v !== $id));
        return false;
    }
    $ids[] = $id;
    $_SESSION['favorites'] = $ids;

    return true;
}

/** @return list<array<string,mixed>> */
function favorite_properties(): array
{
    $ids = favorite_ids();
    if ($ids === []) {
        return [];
    }
    $response = api_client()->get('properties/list', ['limit' => 250]);
    $items = is_array($response['items'] ?? null) ? $response['items'] : [];
    $map = [];
    foreach ($items as $item) {
        if (!is_array($item)) {
            continue;
        }
        $pid = (string) ($item['id'] ?? '');
        if ($pid !== '') {
            $map[$pid] = $item;
        }
    }
    $out = [];
    foreach ($ids as $id) {
        if (isset($map[$id])) {
            $out[] = $map[$id];
        }
    }

    return $out;
}
