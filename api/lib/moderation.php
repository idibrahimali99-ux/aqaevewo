<?php
declare(strict_types=1);

/**
 * سجل حركة الأدمن/الموظفين + أعمدة تم البيع للريلز.
 */

function vewo_staff_permission_allowed_keys(): array
{
    return [
        'promotions', 'news', 'offices', 'parcels', 'properties', 'reels',
        'engagement', 'chats', 'users', 'settings', 'unsold',
    ];
}

function vewo_admin_has_permission(array $admin, string $permission): bool
{
    if (($admin['role'] ?? '') === 'admin') {
        return true;
    }
    $decoded = json_decode((string) ($admin['staff_permissions_json'] ?? '[]'), true);
    $have = is_array($decoded) ? $decoded : [];

    return in_array($permission, $have, true);
}

function vewo_reels_has_sold_columns(PDO $pdo): bool
{
    static $ok = null;
    if ($ok !== null) {
        return $ok;
    }
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'reels' AND column_name = 'is_sold'"
        );
        $ok = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $ok = false;
    }

    return $ok;
}

function vewo_reels_ensure_sold_columns(PDO $pdo): bool
{
    if (vewo_reels_has_sold_columns($pdo)) {
        return true;
    }
    try {
        $pdo->exec(
            'ALTER TABLE reels
             ADD COLUMN is_sold TINYINT(1) NOT NULL DEFAULT 0,
             ADD COLUMN sold_at DATETIME(3) NULL'
        );
    } catch (Throwable $e) {
    }

    return vewo_reels_has_sold_columns($pdo);
}

function vewo_reels_sold_select(PDO $pdo): string
{
    vewo_reels_ensure_sold_columns($pdo);

    return vewo_reels_has_sold_columns($pdo)
        ? 'COALESCE(r.is_sold, 0) AS is_sold, r.sold_at'
        : '0 AS is_sold, NULL AS sold_at';
}

function vewo_moderation_ensure(PDO $pdo): bool
{
    static $ok = null;
    if ($ok !== null) {
        return $ok;
    }
    try {
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS moderation_activity (
                id CHAR(36) NOT NULL PRIMARY KEY,
                actor_user_id CHAR(36) NULL,
                actor_name VARCHAR(255) NOT NULL DEFAULT '',
                actor_role VARCHAR(20) NOT NULL DEFAULT '',
                target_kind VARCHAR(20) NOT NULL,
                target_id CHAR(36) NOT NULL,
                target_public_no INT UNSIGNED NULL,
                action VARCHAR(40) NOT NULL,
                message VARCHAR(500) NOT NULL DEFAULT '',
                note VARCHAR(500) NOT NULL DEFAULT '',
                created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
                KEY idx_moderation_target (target_kind, target_id, created_at),
                KEY idx_moderation_created (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $ok = true;
    } catch (Throwable $e) {
        $ok = false;
    }

    return $ok;
}

function vewo_moderation_action_label(string $action): string
{
    return match ($action) {
        'approve' => 'قام بالموافقة للنشر',
        'reject' => 'رفض المنشور',
        'update' => 'عدّل المنشور',
        'mark_sold' => 'ضغط تم البيع',
        'unmark_sold' => 'ألغى تم البيع وأعاد المنشور',
        'urgent_sale' => 'فعّل البيع العاجل',
        'cancel_urgent_sale' => 'ألغى البيع العاجل',
        'delete' => 'حذف المنشور',
        'reel_approve' => 'وافق على الريل',
        'reel_reject' => 'رفض الريل',
        'reel_update' => 'عدّل الريل',
        'reel_mark_sold' => 'علّم الريل كـ تم البيع',
        'reel_unmark_sold' => 'ألغى تم البيع للريل',
        'reel_delete' => 'حذف الريل',
        default => $action,
    };
}

function vewo_moderation_role_label(string $role): string
{
    return match ($role) {
        'admin' => 'الأدمن',
        'staff' => 'الموظف',
        'office' => 'المكتب',
        'customer' => 'الناشر',
        default => 'المستخدم',
    };
}

function vewo_moderation_message(string $actorRole, string $actorName, string $action): string
{
    $who = vewo_moderation_role_label($actorRole);
    $name = trim($actorName);
    if ($name === '') {
        $name = 'غير معروف';
    }

    return $who . ' ' . $name . ' ' . vewo_moderation_action_label($action);
}

/**
 * @param array<string,mixed>|null $actor
 */
function vewo_moderation_log(
    PDO $pdo,
    ?array $actor,
    string $kind,
    string $targetId,
    string $action,
    ?int $publicNo = null,
    string $note = ''
): void {
    if ($targetId === '' || $action === '' || !vewo_moderation_ensure($pdo)) {
        return;
    }
    $kind = $kind === 'reel' ? 'reel' : 'property';
    $actorId = is_array($actor) ? trim((string) ($actor['id'] ?? '')) : '';
    $actorName = is_array($actor) ? trim((string) ($actor['full_name'] ?? '')) : '';
    $actorRole = is_array($actor) ? trim((string) ($actor['role'] ?? '')) : '';
    $message = vewo_moderation_message($actorRole, $actorName, $action);
    try {
        $stmt = $pdo->prepare(
            'INSERT INTO moderation_activity
                (id, actor_user_id, actor_name, actor_role, target_kind, target_id, target_public_no, action, message, note, created_at)
             VALUES
                (:id, :uid, :n, :r, :k, :tid, :pub, :a, :m, :note, NOW(3))'
        );
        $stmt->execute([
            ':id' => uuid_v4(),
            ':uid' => $actorId !== '' ? $actorId : null,
            ':n' => mb_substr($actorName, 0, 255),
            ':r' => mb_substr($actorRole, 0, 20),
            ':k' => $kind,
            ':tid' => $targetId,
            ':pub' => $publicNo !== null && $publicNo > 0 ? $publicNo : null,
            ':a' => mb_substr($action, 0, 40),
            ':m' => mb_substr($message, 0, 500),
            ':note' => mb_substr($note, 0, 500),
        ]);
    } catch (Throwable $e) {
    }
}

function vewo_moderation_current_actor(PDO $pdo): ?array
{
    $admin = function_exists('vewo_try_admin_staff_user') ? vewo_try_admin_staff_user($pdo) : null;
    if (is_array($admin)) {
        return $admin;
    }
    $user = function_exists('vewo_try_session_user') ? vewo_try_session_user($pdo) : null;

    return is_array($user) ? $user : null;
}

function vewo_moderation_log_current(
    PDO $pdo,
    string $kind,
    string $targetId,
    string $action,
    ?int $publicNo = null,
    string $note = ''
): void {
    vewo_moderation_log($pdo, vewo_moderation_current_actor($pdo), $kind, $targetId, $action, $publicNo, $note);
}

/**
 * @return list<array<string,mixed>>
 */
function vewo_moderation_list(PDO $pdo, string $kind, string $targetId, int $limit = 20): array
{
    if ($targetId === '' || !vewo_moderation_ensure($pdo)) {
        return [];
    }
    $limit = max(1, min(50, $limit));
    try {
        $stmt = $pdo->prepare(
            'SELECT id, actor_user_id, actor_name, actor_role, action, message, note, created_at
             FROM moderation_activity
             WHERE target_kind = :k AND target_id = :id
             ORDER BY created_at DESC
             LIMIT ' . $limit
        );
        $stmt->execute([':k' => $kind === 'reel' ? 'reel' : 'property', ':id' => $targetId]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        return is_array($rows) ? $rows : [];
    } catch (Throwable $e) {
        return [];
    }
}

/**
 * @param list<array<string,mixed>> $items
 */
function vewo_moderation_attach(PDO $pdo, array &$items, string $kind): void
{
    if ($items === [] || !vewo_moderation_ensure($pdo)) {
        return;
    }
    $ids = [];
    foreach ($items as $row) {
        $id = trim((string) ($row['id'] ?? ''));
        if ($id !== '') {
            $ids[] = $id;
        }
    }
    $ids = array_values(array_unique($ids));
    if ($ids === []) {
        return;
    }
    $placeholders = [];
    $params = [':k' => $kind === 'reel' ? 'reel' : 'property'];
    foreach ($ids as $i => $id) {
        $key = ':id' . $i;
        $placeholders[] = $key;
        $params[$key] = $id;
    }
    try {
        $stmt = $pdo->prepare(
            'SELECT id, actor_user_id, actor_name, actor_role, target_id, action, message, note, created_at
             FROM moderation_activity
             WHERE target_kind = :k AND target_id IN (' . implode(',', $placeholders) . ')
             ORDER BY created_at DESC'
        );
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        return;
    }
    $byTarget = [];
    foreach ($rows as $row) {
        $tid = (string) ($row['target_id'] ?? '');
        if ($tid === '') {
            continue;
        }
        if (!isset($byTarget[$tid])) {
            $byTarget[$tid] = [];
        }
        if (count($byTarget[$tid]) >= 8) {
            continue;
        }
        $byTarget[$tid][] = [
            'id' => (string) ($row['id'] ?? ''),
            'actor_user_id' => (string) ($row['actor_user_id'] ?? ''),
            'actor_name' => (string) ($row['actor_name'] ?? ''),
            'actor_role' => (string) ($row['actor_role'] ?? ''),
            'action' => (string) ($row['action'] ?? ''),
            'message' => (string) ($row['message'] ?? ''),
            'note' => (string) ($row['note'] ?? ''),
            'created_at' => (string) ($row['created_at'] ?? ''),
        ];
    }
    foreach ($items as &$item) {
        $tid = (string) ($item['id'] ?? '');
        $item['activity'] = $byTarget[$tid] ?? [];
    }
    unset($item);
}

function vewo_property_public_no_of(PDO $pdo, string $id): ?int
{
    if ($id === '' || !function_exists('vewo_properties_has_public_no_column') || !vewo_properties_has_public_no_column($pdo)) {
        return null;
    }
    try {
        $stmt = $pdo->prepare('SELECT property_public_no FROM properties WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        $n = $stmt->fetchColumn();

        return $n !== false && $n !== null ? (int) $n : null;
    } catch (Throwable $e) {
        return null;
    }
}

function vewo_reel_public_no_of(PDO $pdo, string $id): ?int
{
    if ($id === '' || !function_exists('vewo_reels_has_public_no_column') || !vewo_reels_has_public_no_column($pdo)) {
        return null;
    }
    try {
        $stmt = $pdo->prepare('SELECT reel_public_no FROM reels WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        $n = $stmt->fetchColumn();

        return $n !== false && $n !== null ? (int) $n : null;
    } catch (Throwable $e) {
        return null;
    }
}

/**
 * تعليم ريل كمباع أو إلغاء البيع — صاحب الريل أو أدمن/موظف بصلاحية.
 */
function reels_mark_sold_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    vewo_reels_ensure_sold_columns($pdo);
    if (!vewo_reels_has_sold_columns($pdo)) {
        json_error(500, 'تعذر تفعيل تم البيع للريلز');
    }
    $in = read_json_body();
    $id = trim((string) ($in['reel_id'] ?? $in['id'] ?? ''));
    if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'معرّف الريل غير صالح');
    }
    $isSold = (int) ($in['is_sold'] ?? 1) === 1;
    $stmt = $pdo->prepare('SELECT owner_user_id, approval_status FROM reels WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row)) {
        json_error(404, 'الريل غير موجود');
    }
    if ((string) ($row['approval_status'] ?? '') !== 'approved') {
        json_error(400, 'لا يمكن تعليم هذا الريل قبل الموافقة عليه');
    }
    $ownerId = (string) ($row['owner_user_id'] ?? '');
    $sessionUser = vewo_try_session_user($pdo);
    $adminUser = vewo_try_admin_staff_user($pdo);
    $isOwner = $sessionUser !== null && (string) ($sessionUser['id'] ?? '') === $ownerId;
    $allowed = $isOwner;
    if ($adminUser !== null) {
        if ($isSold) {
            $allowed = ($adminUser['role'] ?? '') === 'admin'
                || vewo_admin_has_permission($adminUser, 'reels')
                || vewo_admin_has_permission($adminUser, 'properties');
        } else {
            $allowed = ($adminUser['role'] ?? '') === 'admin'
                || vewo_admin_has_permission($adminUser, 'unsold');
        }
    }
    if (!$allowed) {
        json_error(403, 'ليست لديك صلاحية تعديل حالة البيع');
    }
    if ($isSold) {
        $pdo->prepare('UPDATE reels SET is_sold = 1, sold_at = NOW(3) WHERE id = :id LIMIT 1')->execute([':id' => $id]);
        vewo_moderation_log(
            $pdo,
            $adminUser ?? $sessionUser,
            'reel',
            $id,
            'reel_mark_sold',
            vewo_reel_public_no_of($pdo, $id)
        );
    } else {
        $pdo->prepare('UPDATE reels SET is_sold = 0, sold_at = NULL WHERE id = :id LIMIT 1')->execute([':id' => $id]);
        vewo_moderation_log(
            $pdo,
            $adminUser ?? $sessionUser,
            'reel',
            $id,
            'reel_unmark_sold',
            vewo_reel_public_no_of($pdo, $id)
        );
    }
    echo json_encode(['ok' => true, 'is_sold' => $isSold ? 1 : 0], JSON_UNESCAPED_UNICODE);
}
