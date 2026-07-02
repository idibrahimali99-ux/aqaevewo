<?php
declare(strict_types=1);

function vewo_follows_table_exists(PDO $pdo): bool
{
    try {
        $t = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = 'vewo_follows'"
        );

        return $t !== false && (int) $t->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_posting_packages_table_exists(PDO $pdo): bool
{
    try {
        $t = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = 'posting_packages'"
        );

        return $t !== false && (int) $t->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_properties_has_synthetic_likes(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'synthetic_likes'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_target_follower_columns(PDO $pdo, string $kind): ?array
{
    return match ($kind) {
        'office' => ['table' => 'users', 'id_col' => 'id'],
        'compound' => ['table' => 'compounds', 'id_col' => 'id'],
        'parcel' => ['table' => 'parcels', 'id_col' => 'id'],
        default => null,
    };
}

function vewo_recount_followers(PDO $pdo, string $kind, string $targetId): void
{
    if (!vewo_follows_table_exists($pdo)) {
        return;
    }
    $meta = vewo_target_follower_columns($pdo, $kind);
    if ($meta === null) {
        return;
    }
    try {
        $cnt = $pdo->prepare(
            'SELECT COUNT(*) FROM vewo_follows WHERE target_kind = :k AND target_id = :t'
        );
        $cnt->execute([':k' => $kind, ':t' => $targetId]);
        $real = (int) $cnt->fetchColumn();
        $pdo->prepare(
            "UPDATE {$meta['table']} SET follower_count = :c WHERE {$meta['id_col']} = :id LIMIT 1"
        )->execute([':c' => $real, ':id' => $targetId]);
    } catch (Throwable $e) {
    }
}

/**
 * قائمة متابعاتي (لترتيب الرئيسية).
 */
function follow_list_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    $me = require_auth_user($pdo);
    $uid = (string) ($me['id'] ?? '');
    if (!vewo_follows_table_exists($pdo)) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);

        return;
    }
    $stmt = $pdo->prepare(
        'SELECT target_kind, target_id, created_at FROM vewo_follows WHERE user_id = :u ORDER BY created_at DESC'
    );
    $stmt->execute([':u' => $uid]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}

/**
 * تبديل متابعة: office | compound | parcel
 */
function follow_toggle_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    if (!vewo_follows_table_exists($pdo)) {
        json_error(503, 'نفّذ patch_follows_packages_engagement_mysql.sql');
    }
    $me = require_auth_user($pdo);
    $uid = (string) ($me['id'] ?? '');
    $in = read_json_body();
    $kind = trim((string) ($in['target_kind'] ?? ''));
    $tid = trim((string) ($in['target_id'] ?? ''));
    if (!in_array($kind, ['office', 'compound', 'parcel'], true)) {
        json_error(400, 'target_kind غير صالح');
    }
    if ($tid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $tid)) {
        json_error(400, 'target_id غير صالح');
    }
    if ($kind === 'office' && $tid === $uid) {
        json_error(400, 'لا يمكن متابعة نفسك');
    }
    $chk = $pdo->prepare(
        'SELECT id FROM vewo_follows WHERE user_id = :u AND target_kind = :k AND target_id = :t LIMIT 1'
    );
    $chk->execute([':u' => $uid, ':k' => $kind, ':t' => $tid]);
    $existing = $chk->fetchColumn();
    if ($existing !== false) {
        $pdo->prepare('DELETE FROM vewo_follows WHERE id = :id LIMIT 1')->execute([':id' => $existing]);
        vewo_recount_followers($pdo, $kind, $tid);
        echo json_encode(['ok' => true, 'following' => false], JSON_UNESCAPED_UNICODE);

        return;
    }
    $fid = uuid_v4();
    $pdo->prepare(
        'INSERT INTO vewo_follows (id, user_id, target_kind, target_id, created_at)
         VALUES (:id, :u, :k, :t, NOW(3))'
    )->execute([':id' => $fid, ':u' => $uid, ':k' => $kind, ':t' => $tid]);
    vewo_recount_followers($pdo, $kind, $tid);
    echo json_encode(['ok' => true, 'following' => true], JSON_UNESCAPED_UNICODE);
}

/**
 * حالة متابعة + عدد المتابعين (حقيقي + تركيبي).
 */
function follow_status_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    $kind = trim((string) ($_GET['target_kind'] ?? ''));
    $tid = trim((string) ($_GET['target_id'] ?? ''));
    if (!in_array($kind, ['office', 'compound', 'parcel'], true) || $tid === '') {
        json_error(400, 'معاملات غير صالحة');
    }
    $following = false;
    $su = vewo_try_session_user($pdo);
    if ($su !== null && vewo_follows_table_exists($pdo)) {
        $uid = (string) ($su['id'] ?? '');
        $st = $pdo->prepare(
            'SELECT 1 FROM vewo_follows WHERE user_id = :u AND target_kind = :k AND target_id = :t LIMIT 1'
        );
        $st->execute([':u' => $uid, ':k' => $kind, ':t' => $tid]);
        $following = (bool) $st->fetchColumn();
    }
    $followers = 0;
    $meta = vewo_target_follower_columns($pdo, $kind);
    if ($meta !== null) {
        try {
            $row = $pdo->prepare(
                "SELECT COALESCE(follower_count,0) AS fc, COALESCE(synthetic_follower_boost,0) AS sb
                 FROM {$meta['table']} WHERE {$meta['id_col']} = :id LIMIT 1"
            );
            $row->execute([':id' => $tid]);
            $r = $row->fetch(PDO::FETCH_ASSOC);
            if (is_array($r)) {
                $followers = (int) ($r['fc'] ?? 0) + (int) ($r['sb'] ?? 0);
            }
        } catch (Throwable $e) {
        }
    }
    echo json_encode([
        'ok' => true,
        'following' => $following,
        'follower_count' => $followers,
    ], JSON_UNESCAPED_UNICODE);
}

function admin_posting_packages_route(PDO $pdo): void
{
    vewo_require_admin_permission($pdo, 'users');
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if (!vewo_posting_packages_table_exists($pdo)) {
        json_error(503, 'نفّذ patch_follows_packages_engagement_mysql.sql');
    }
    if ($method === 'GET') {
        $stmt = $pdo->query(
            'SELECT id, name_ar, listing_limit, applies_to, sort_order, is_active, created_at
             FROM posting_packages ORDER BY sort_order ASC, name_ar ASC'
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $in = read_json_body();
    $action = trim((string) ($in['action'] ?? 'upsert'));
    if ($action === 'delete') {
        $id = trim((string) ($in['id'] ?? ''));
        if ($id === '') {
            json_error(400, 'id مطلوب');
        }
        $pdo->prepare('DELETE FROM posting_packages WHERE id = :id LIMIT 1')->execute([':id' => $id]);
        echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);

        return;
    }
    $id = trim((string) ($in['id'] ?? ''));
    $name = trim((string) ($in['name_ar'] ?? ''));
    $limitRaw = $in['listing_limit'] ?? $in['listingLimit'] ?? null;
    $unlimited = !empty($in['unlimited']) || $limitRaw === null && array_key_exists('unlimited', $in) && $in['unlimited'] === true;
    $limit = $unlimited ? null : max(0, (int) $limitRaw);
    $applies = trim((string) ($in['applies_to'] ?? 'both'));
    if (!in_array($applies, ['office', 'marketer', 'both'], true)) {
        $applies = 'both';
    }
    $sort = (int) ($in['sort_order'] ?? 0);
    $active = (int) ($in['is_active'] ?? 1) === 1 ? 1 : 0;
    if ($name === '') {
        json_error(400, 'اسم الباقة مطلوب');
    }
    if ($id === '') {
        $id = uuid_v4();
        $pdo->prepare(
            'INSERT INTO posting_packages (id, name_ar, listing_limit, applies_to, sort_order, is_active, created_at)
             VALUES (:id, :n, :l, :a, :s, :ac, NOW(3))'
        )->execute([
            ':id' => $id, ':n' => $name, ':l' => $limit, ':a' => $applies, ':s' => $sort, ':ac' => $active,
        ]);
    } else {
        $pdo->prepare(
            'UPDATE posting_packages SET name_ar = :n, listing_limit = :l, applies_to = :a,
             sort_order = :s, is_active = :ac WHERE id = :id LIMIT 1'
        )->execute([
            ':id' => $id, ':n' => $name, ':l' => $limit, ':a' => $applies, ':s' => $sort, ':ac' => $active,
        ]);
    }
    echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);
}

/**
 * تعيين باقة/رصيد لمسوق أو مكتب.
 */
function admin_assign_posting_package_route(PDO $pdo): void
{
    vewo_require_admin_permission($pdo, 'users');
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $in = read_json_body();
    $userId = trim((string) ($in['user_id'] ?? ''));
    if ($userId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $userId)) {
        json_error(400, 'user_id غير صالح');
    }
    $trialUnlimited = !empty($in['posting_trial_unlimited']) || !empty($in['unlimited']);
    $remaining = isset($in['posting_listings_remaining']) ? (int) $in['posting_listings_remaining'] : null;
    $packageId = trim((string) ($in['posting_package_id'] ?? $in['package_id'] ?? ''));
    $marketerApproved = isset($in['marketer_approved']) ? ((int) $in['marketer_approved'] === 1 ? 1 : 0) : null;

    $sets = [];
    $params = [':id' => $userId];
    if (vewo_users_has_posting_quota_columns($pdo)) {
        $sets[] = 'posting_trial_unlimited = :tu';
        $params[':tu'] = $trialUnlimited ? 1 : 0;
        if ($remaining !== null) {
            $sets[] = 'posting_listings_remaining = :rem';
            $params[':rem'] = max(0, $remaining);
        }
    }
    if ($packageId !== '' && vewo_posting_packages_table_exists($pdo)) {
        if (!preg_match('/^[0-9a-fA-F-]{36}$/', $packageId)) {
            json_error(400, 'package_id غير صالح');
        }
        $sets[] = 'posting_package_id = :pkg';
        $params[':pkg'] = $packageId;
        $pstmt = $pdo->prepare('SELECT listing_limit FROM posting_packages WHERE id = :id AND is_active = 1 LIMIT 1');
        $pstmt->execute([':id' => $packageId]);
        $prow = $pstmt->fetch(PDO::FETCH_ASSOC);
        if (is_array($prow) && vewo_users_has_posting_quota_columns($pdo)) {
            $lim = $prow['listing_limit'];
            if ($lim === null || $lim === '') {
                $sets = array_filter($sets, static fn ($s) => !str_contains($s, 'posting_trial_unlimited'));
                $sets[] = 'posting_trial_unlimited = 1';
                $params[':tu'] = 1;
            } elseif ($remaining === null) {
                $sets[] = 'posting_listings_remaining = :rem';
                $params[':rem'] = (int) $lim;
                $sets[] = 'posting_trial_unlimited = 0';
                $params[':tu'] = 0;
            }
        }
    }
    if ($marketerApproved !== null && vewo_users_has_is_marketer_column($pdo)) {
        $sets[] = 'office_approved = :oa';
        $params[':oa'] = $marketerApproved;
    }
    if ($sets === []) {
        json_error(400, 'لا شيء لتحديثه');
    }
    $sql = 'UPDATE users SET ' . implode(', ', $sets) . ' WHERE id = :id LIMIT 1';
    $pdo->prepare($sql)->execute($params);
    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
}

/**
 * زيادة متابعين تركيبية (إدارة).
 */
function admin_follow_boost_route(PDO $pdo): void
{
    vewo_require_admin_permission($pdo, 'engagement');
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $in = read_json_body();
    $kind = trim((string) ($in['target_kind'] ?? ''));
    $tid = trim((string) ($in['target_id'] ?? ''));
    $add = max(0, (int) ($in['add_count'] ?? $in['count'] ?? 0));
    if (!in_array($kind, ['office', 'compound', 'parcel'], true) || $tid === '' || $add < 1) {
        json_error(400, 'بيانات غير صالحة');
    }
    $meta = vewo_target_follower_columns($pdo, $kind);
    if ($meta === null) {
        json_error(400, 'نوع غير مدعوم');
    }
    try {
        $pdo->prepare(
            "UPDATE {$meta['table']} SET synthetic_follower_boost = COALESCE(synthetic_follower_boost,0) + :a
             WHERE {$meta['id_col']} = :id LIMIT 1"
        )->execute([':a' => $add, ':id' => $tid]);
    } catch (Throwable $e) {
        json_error(503, 'نفّذ patch_follows_packages_engagement_mysql.sql');
    }
    $followers = 0;
    try {
        $row = $pdo->prepare(
            "SELECT COALESCE(follower_count,0) + COALESCE(synthetic_follower_boost,0) AS t
             FROM {$meta['table']} WHERE {$meta['id_col']} = :id LIMIT 1"
        );
        $row->execute([':id' => $tid]);
        $r = $row->fetch(PDO::FETCH_ASSOC);
        if (is_array($r)) {
            $followers = (int) ($r['t'] ?? 0);
        }
    } catch (Throwable $e) {
    }
    echo json_encode(['ok' => true, 'follower_count' => $followers], JSON_UNESCAPED_UNICODE);
}

function admin_marketers_list_route(PDO $pdo): void
{
    vewo_require_admin_permission($pdo, 'users');
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    if (!vewo_users_has_is_marketer_column($pdo)) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);

        return;
    }
    $pkgCol = vewo_users_has_posting_quota_columns($pdo)
        ? 'u.posting_trial_unlimited, u.posting_listings_remaining, u.posting_package_id,'
        : '';
    $stmt = $pdo->query(
        "SELECT u.id, u.full_name, u.phone, u.email, u.office_name, u.office_approved,
                {$pkgCol}
                COALESCE(u.follower_count,0) AS follower_count,
                COALESCE(u.synthetic_follower_boost,0) AS synthetic_follower_boost
         FROM users u
         WHERE u.role = 'office' AND COALESCE(u.is_marketer,0) = 1
         ORDER BY u.created_at DESC
         LIMIT 500"
    );
    $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}
