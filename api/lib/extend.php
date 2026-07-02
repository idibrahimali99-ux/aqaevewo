<?php
declare(strict_types=1);

/**
 * مسارات إضافية: إحصاءات الأدمن، مكاتب، مستخدمون، عقارات عامة، إنشاء عقار، users/me.
 * يُحمّل من index.php بعد تهيئة $pdo (دوال json_error و uuid_v4 و require_* متوفرة في index).
 */

/** @return array{id:string,full_name:string,phone:string,role:string}|null */
function vewo_try_session_user(PDO $pdo): ?array
{
    $token = get_bearer_token();
    if ($token === null || strlen($token) !== 64) {
        return null;
    }
    $stmt = $pdo->prepare(
        'SELECT u.id, u.full_name, u.phone, u.role FROM user_session_tokens k
         INNER JOIN users u ON u.id = k.user_id
         WHERE k.token = :t AND k.expires_at > NOW(3) AND u.is_active = 1
         LIMIT 1'
    );
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    return is_array($row) ? $row : null;
}

/** @return array{id:string,full_name:string,role:string}|null */
function vewo_try_admin_staff_user(PDO $pdo): ?array
{
    $token = get_bearer_token();
    if ($token === null || strlen($token) !== 64) {
        return null;
    }
    $stmt = $pdo->prepare(
        'SELECT u.id, u.full_name, u.role FROM admin_api_tokens k
         INNER JOIN users u ON u.id = k.user_id
         WHERE k.token = :t AND k.expires_at > NOW(3) AND u.is_active = 1 AND u.role IN (\'admin\',\'staff\')
         LIMIT 1'
    );
    $stmt->execute([':t' => $token]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    return is_array($row) ? $row : null;
}

function vewo_properties_has_public_no_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'property_public_no'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_properties_has_review_meta_columns(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'reject_note'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * ملخص منشور للمحادثات (تفاصيل، خريطة، ناشر).
 *
 * @return array<string,mixed>|null
 */
function vewo_property_summary_array(PDO $pdo, string $propertyId): ?array
{
    if ($propertyId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $propertyId)) {
        return null;
    }
    $propNoExpr = vewo_properties_has_public_no_column($pdo)
        ? 'property_public_no'
        : 'NULL AS property_public_no';
    $reviewExpr = (function_exists('vewo_properties_has_review_meta_columns') && vewo_properties_has_review_meta_columns($pdo))
        ? 'approval_status, reject_note, resubmission_allowed'
        : 'approval_status, NULL AS reject_note, 0 AS resubmission_allowed';
    try {
        $stmt = $pdo->prepare(
            'SELECT ' . $propNoExpr . ', title, governorate, address_line, price_iqd, area_sqm, description, details_json,
                    ' . $reviewExpr . ', owner_user_id,
                    (SELECT m.public_url FROM property_media m WHERE m.property_id = properties.id AND m.media_type = \'image\' ORDER BY m.created_at ASC LIMIT 1) AS thumb_url
             FROM properties WHERE id = :id LIMIT 1'
        );
        $stmt->execute([':id' => $propertyId]);
        $prow = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        return null;
    }
    if (!is_array($prow)) {
        return null;
    }

    $imageUrls = [];
    try {
        $mst = $pdo->prepare(
            "SELECT public_url FROM property_media WHERE property_id = :id AND media_type = 'image' ORDER BY created_at ASC"
        );
        $mst->execute([':id' => $propertyId]);
        while ($mr = $mst->fetch(PDO::FETCH_ASSOC)) {
            $u = trim((string) ($mr['public_url'] ?? ''));
            if ($u !== '') {
                $imageUrls[] = $u;
            }
        }
    } catch (Throwable $e) {
        $imageUrls = [];
    }

    return [
        'id' => $propertyId,
        'property_public_no' => $prow['property_public_no'] ?? null,
        'title' => (string) ($prow['title'] ?? ''),
        'governorate' => (string) ($prow['governorate'] ?? ''),
        'address_line' => (string) ($prow['address_line'] ?? ''),
        'thumb_url' => (string) ($prow['thumb_url'] ?? ''),
        'image_urls' => $imageUrls,
        'images' => $imageUrls,
        'price_iqd' => $prow['price_iqd'] ?? null,
        'area_sqm' => $prow['area_sqm'] ?? null,
        'description' => (string) ($prow['description'] ?? ''),
        'details_json' => isset($prow['details_json']) ? (string) $prow['details_json'] : '',
        'approval_status' => (string) ($prow['approval_status'] ?? ''),
        'reject_note' => (string) ($prow['reject_note'] ?? ''),
        'resubmission_allowed' => (int) ($prow['resubmission_allowed'] ?? 0),
        'owner_user_id' => (string) ($prow['owner_user_id'] ?? ''),
    ];
}

function vewo_users_has_posting_quota_columns(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'posting_trial_unlimited'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * يمنع نشر منشور جديد إذا انتهت حصة المكتب (عند إيقاف التجريبي).
 */
function vewo_office_assert_can_post(PDO $pdo, string $userId, string $role): void
{
    if ($role !== 'office' || !vewo_users_has_posting_quota_columns($pdo)) {
        return;
    }
    $stmt = $pdo->prepare(
        'SELECT posting_trial_unlimited, posting_listings_remaining FROM users WHERE id = :id AND role = \'office\' LIMIT 1'
    );
    $stmt->execute([':id' => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row)) {
        return;
    }
    if ((int) ($row['posting_trial_unlimited'] ?? 1) === 1) {
        return;
    }
    $remRaw = $row['posting_listings_remaining'] ?? null;
    $rem = ($remRaw === null || $remRaw === '') ? 0 : (int) $remRaw;
    if ($rem <= 0) {
        json_error(
            403,
            'لقد نفدت حصة المنشورات في باقتك. يمكنك التصفح والمحادثات؛ لزيادة الرصيد تواصل مع الدعم على 07871456361.'
        );
    }
}

function vewo_office_consume_posting_quota(PDO $pdo, string $userId, string $role): void
{
    if ($role !== 'office' || !vewo_users_has_posting_quota_columns($pdo)) {
        return;
    }
    $stmt = $pdo->prepare(
        'SELECT posting_trial_unlimited FROM users WHERE id = :id AND role = \'office\' LIMIT 1'
    );
    $stmt->execute([':id' => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row) || (int) ($row['posting_trial_unlimited'] ?? 1) === 1) {
        return;
    }
    try {
        $pdo->prepare(
            'UPDATE users SET posting_listings_remaining = GREATEST(COALESCE(posting_listings_remaining, 0) - 1, 0) WHERE id = :id AND role = \'office\' LIMIT 1'
        )->execute([':id' => $userId]);
    } catch (Throwable $e) {
    }
}

function vewo_allocate_property_public_no(PDO $pdo): int
{
    $pdo->query("SELECT GET_LOCK('vewo_property_public_no', 20)");
    try {
        return (int) $pdo->query(
            'SELECT COALESCE(MAX(property_public_no), 20000000) + 1 FROM properties'
        )->fetchColumn();
    } finally {
        $pdo->query("SELECT RELEASE_LOCK('vewo_property_public_no')");
    }
}

function vewo_reels_has_public_no_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'reels' AND column_name = 'reel_public_no'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_reels_has_engagement_columns(PDO $pdo): bool
{
    if (!vewo_reels_has_public_no_column($pdo)) {
        return false;
    }
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'reels'
               AND column_name IN ('view_count','synthetic_likes')"
        );

        return $chk !== false && (int) $chk->fetchColumn() >= 2;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_allocate_reel_public_no(PDO $pdo): int
{
    $pdo->query("SELECT GET_LOCK('vewo_reel_public_no', 20)");
    try {
        return (int) $pdo->query(
            'SELECT COALESCE(MAX(reel_public_no), 30000000) + 1 FROM reels'
        )->fetchColumn();
    } finally {
        $pdo->query("SELECT RELEASE_LOCK('vewo_reel_public_no')");
    }
}

function vewo_engagement_rules_table_exists(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = 'admin_engagement_rules'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * تطبيق قواعد زيادة المشاهدات/اللايكات عند استدعاء لوحة الأدمن (مرة لكل طلب HTTP).
 */
function vewo_engagement_process_due_rules(PDO $pdo): void
{
    static $done = false;
    if ($done) {
        return;
    }
    $done = true;
    if (!vewo_engagement_rules_table_exists($pdo)) {
        return;
    }
    try {
        $rules = $pdo->query('SELECT id, target_kind, target_public_no, views_per_tick, likes_per_tick, interval_seconds, last_tick_at FROM admin_engagement_rules')
            ->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        return;
    }
    if (!is_array($rules)) {
        return;
    }
    $hasPropPub = function_exists('vewo_properties_has_public_no_column') && vewo_properties_has_public_no_column($pdo);
    $hasReelEng = vewo_reels_has_engagement_columns($pdo);
    foreach ($rules as $rule) {
        $id = (string) ($rule['id'] ?? '');
        if ($id === '') {
            continue;
        }
        $interval = max(30, (int) ($rule['interval_seconds'] ?? 60));
        $vInterval = max(30, (int) ($rule['views_interval_seconds'] ?? $interval));
        $lInterval = max(30, (int) ($rule['likes_interval_seconds'] ?? $interval));
        $last = $rule['last_tick_at'] ?? null;
        $lastTs = ($last !== null && $last !== '') ? strtotime((string) $last) : 0;
        $now = time();
        $kind = (string) ($rule['target_kind'] ?? '');
        $pub = (int) ($rule['target_public_no'] ?? 0);
        $dv = max(0, (int) ($rule['views_per_tick'] ?? 0));
        $dl = max(0, (int) ($rule['likes_per_tick'] ?? 0));
        if ($pub < 1 || ($dv === 0 && $dl === 0)) {
            continue;
        }
        $applyViews = $dv > 0 && ($lastTs === 0 || ($now - $lastTs) >= $vInterval);
        $applyLikes = $dl > 0 && ($lastTs === 0 || ($now - $lastTs) >= $lInterval);
        if (!$applyViews && !$applyLikes) {
            continue;
        }
        try {
            if ($kind === 'property' && $hasPropPub) {
                if ($applyViews && $dv > 0) {
                    $u = $pdo->prepare('UPDATE properties SET views = views + :dv WHERE property_public_no = :p LIMIT 1');
                    $u->execute([':dv' => $dv, ':p' => $pub]);
                }
                if ($applyLikes && $dl > 0 && function_exists('vewo_properties_has_synthetic_likes') && vewo_properties_has_synthetic_likes($pdo)) {
                    $u = $pdo->prepare(
                        'UPDATE properties SET synthetic_likes = synthetic_likes + :dl WHERE property_public_no = :p LIMIT 1'
                    );
                    $u->execute([':dl' => $dl, ':p' => $pub]);
                }
            } elseif ($kind === 'reel' && $hasReelEng) {
                $rv = $applyViews ? $dv : 0;
                $rl = $applyLikes ? $dl : 0;
                if ($rv > 0 || $rl > 0) {
                    $u = $pdo->prepare(
                        'UPDATE reels SET view_count = view_count + :dv, synthetic_likes = synthetic_likes + :dl WHERE reel_public_no = :p LIMIT 1'
                    );
                    $u->execute([':dv' => $rv, ':dl' => $rl, ':p' => $pub]);
                }
            }
            $pdo->prepare('UPDATE admin_engagement_rules SET last_tick_at = NOW(3) WHERE id = :id LIMIT 1')->execute([':id' => $id]);
        } catch (Throwable $e) {
        }
    }
}

function vewo_require_admin_permission_any(PDO $pdo, array $permissions): void
{
    $admin = require_admin_from_bearer($pdo);
    if (($admin['role'] ?? '') === 'admin') {
        return;
    }
    $decoded = json_decode((string) ($admin['staff_permissions_json'] ?? '[]'), true);
    $have = is_array($decoded) ? $decoded : [];
    foreach ($permissions as $p) {
        if (in_array($p, $have, true)) {
            return;
        }
    }
    json_error(403, 'لا تملك صلاحية هذا القسم');
}

/**
 * إدارة جدولة المشاهدات/اللايكات (منشور # أو ريل #).
 */
function admin_engagement_route(PDO $pdo): void
{
    vewo_require_admin_permission($pdo, 'engagement');
    vewo_engagement_process_due_rules($pdo);
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        if (!vewo_engagement_rules_table_exists($pdo)) {
            echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);

            return;
        }
        $stmt = $pdo->query(
            'SELECT id, target_kind, target_public_no, views_per_tick, likes_per_tick, interval_seconds, last_tick_at, created_at
             FROM admin_engagement_rules ORDER BY created_at DESC LIMIT 200'
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];

        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'DELETE') {
        $id = trim((string) ($_GET['id'] ?? ''));
        if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            json_error(400, 'معرّف غير صالح');
        }
        if (!vewo_engagement_rules_table_exists($pdo)) {
            json_error(400, 'الجدول غير مثبت');
        }
        $stmt = $pdo->prepare('DELETE FROM admin_engagement_rules WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    if (!vewo_engagement_rules_table_exists($pdo)) {
        json_error(400, 'نفّذ patch قاعدة البيانات admin_engagement أولاً');
    }
    $in = read_json_body();
    $kind = trim((string) ($in['target_kind'] ?? $in['kind'] ?? ''));
    if (!in_array($kind, ['property', 'reel'], true)) {
        json_error(400, 'target_kind يجب property أو reel');
    }
    $pub = (int) ($in['target_public_no'] ?? $in['public_no'] ?? 0);
    if ($pub < 1) {
        json_error(400, 'رقم المنشور/الريل غير صالح');
    }
    $viewsPer = max(0, (int) ($in['views_per_tick'] ?? $in['views_per_minute'] ?? 0));
    $likesPer = max(0, (int) ($in['likes_per_tick'] ?? $in['likes_per_interval'] ?? 0));
    $interval = max(30, (int) ($in['interval_seconds'] ?? 60));
    $viewsInterval = max(30, (int) ($in['views_interval_seconds'] ?? $interval));
    $likesInterval = max(30, (int) ($in['likes_interval_seconds'] ?? $interval));
    if ($viewsPer === 0 && $likesPer === 0) {
        json_error(400, 'حدد views_per_tick أو likes_per_tick (أكبر من صفر)');
    }
    $rid = uuid_v4();
    $hasSplitInterval = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'admin_engagement_rules' AND column_name = 'views_interval_seconds'"
        );
        $hasSplitInterval = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
    }
    try {
        $del = $pdo->prepare('DELETE FROM admin_engagement_rules WHERE target_kind = :k AND target_public_no = :p');
        $del->execute([':k' => $kind, ':p' => $pub]);
        if ($hasSplitInterval) {
            $stmt = $pdo->prepare(
                'INSERT INTO admin_engagement_rules (id, target_kind, target_public_no, views_per_tick, likes_per_tick,
                 interval_seconds, views_interval_seconds, likes_interval_seconds, last_tick_at, created_at)
                 VALUES (:id, :k, :p, :v, :l, :i, :vi, :li, NULL, NOW(3))'
            );
            $stmt->execute([
                ':id' => $rid,
                ':k' => $kind,
                ':p' => $pub,
                ':v' => $viewsPer,
                ':l' => $likesPer,
                ':i' => $interval,
                ':vi' => $viewsInterval,
                ':li' => $likesInterval,
            ]);
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO admin_engagement_rules (id, target_kind, target_public_no, views_per_tick, likes_per_tick, interval_seconds, last_tick_at, created_at)
                 VALUES (:id, :k, :p, :v, :l, :i, NULL, NOW(3))'
            );
            $stmt->execute([
                ':id' => $rid,
                ':k' => $kind,
                ':p' => $pub,
                ':v' => $viewsPer,
                ':l' => $likesPer,
                ':i' => $interval,
            ]);
        }
    } catch (Throwable $e) {
        json_error(500, 'تعذر حفظ القاعدة');
    }
    echo json_encode(['ok' => true, 'id' => $rid], JSON_UNESCAPED_UNICODE);
}

function vewo_users_has_staff_permissions_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'staff_permissions_json'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_users_has_email_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'email'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_users_has_profile_photo_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'profile_photo_url'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_users_has_is_marketer_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'is_marketer'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_users_has_office_location_columns(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_lat'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_parcels_has_district_id_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'parcels' AND column_name = 'district_id'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_districts_table_exists(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = 'districts'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_districts_has_kind_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'districts' AND column_name = 'kind'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

/**
 * يجعل القضاء/الناحية التي ينشئها الأدمن قابلة للاستخدام كمقاطعة عامة.
 *
 * @return array{id:string,governorate:string,parcel_name:string,parcel_no:string}|null
 */
function vewo_ensure_public_parcel_for_district(PDO $pdo, string $districtId): ?array
{
    if ($districtId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $districtId)) {
        return null;
    }
    if (!vewo_districts_table_exists($pdo)) {
        return null;
    }

    try {
        $stmt = $pdo->prepare(
            'SELECT d.id, d.name AS district_name, g.name AS governorate_name
             FROM districts d
             INNER JOIN governorates g ON g.id = d.governorate_id
             WHERE d.id = :id AND d.is_active = 1
             LIMIT 1'
        );
        $stmt->execute([':id' => $districtId]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        return null;
    }

    if (!is_array($row)) {
        return null;
    }

    $gov = trim((string) ($row['governorate_name'] ?? ''));
    $name = trim((string) ($row['district_name'] ?? ''));
    if ($gov === '' || $name === '') {
        return null;
    }

    try {
        $existing = $pdo->prepare('SELECT id, governorate, parcel_name, parcel_no FROM parcels WHERE id = :id LIMIT 1');
        $existing->execute([':id' => $districtId]);
        $parcel = $existing->fetch(PDO::FETCH_ASSOC);
        if (is_array($parcel)) {
            try {
                if (vewo_parcels_has_district_id_column($pdo)) {
                    $upd = $pdo->prepare(
                        'UPDATE parcels SET governorate = :g, district_id = :did, parcel_name = :n, is_active = 1
                         WHERE id = :id LIMIT 1'
                    );
                    $upd->execute([':g' => $gov, ':did' => $districtId, ':n' => $name, ':id' => $districtId]);
                } else {
                    $upd = $pdo->prepare(
                        'UPDATE parcels SET governorate = :g, parcel_name = :n, is_active = 1 WHERE id = :id LIMIT 1'
                    );
                    $upd->execute([':g' => $gov, ':n' => $name, ':id' => $districtId]);
                }
            } catch (Throwable $e) {
            }
            return [
                'id' => (string) ($parcel['id'] ?? $districtId),
                'governorate' => $gov,
                'parcel_name' => $name,
                'parcel_no' => (string) ($parcel['parcel_no'] ?? ''),
            ];
        }
    } catch (Throwable $e) {
        return [
            'id' => $districtId,
            'governorate' => $gov,
            'parcel_name' => $name,
            'parcel_no' => '',
        ];
    }

    try {
        if (vewo_parcels_has_district_id_column($pdo)) {
            $ins = $pdo->prepare(
                'INSERT INTO parcels (id, governorate, district_id, parcel_name, parcel_no, sort_order, is_active, created_at)
                 VALUES (:id, :g, :did, :n, \'\', 0, 1, NOW(3))'
            );
            $ins->execute([':id' => $districtId, ':g' => $gov, ':did' => $districtId, ':n' => $name]);
        } else {
            $ins = $pdo->prepare(
                'INSERT INTO parcels (id, governorate, parcel_name, parcel_no, sort_order, is_active, created_at)
                 VALUES (:id, :g, :n, \'\', 0, 1, NOW(3))'
            );
            $ins->execute([':id' => $districtId, ':g' => $gov, ':n' => $name]);
        }
    } catch (Throwable $e) {
        // وجود Unique قد يعني أن الصف أُضيف باسم مشابه. ما يهم هنا أن نُرجع
        // بيانات صالحة ليُحفظ المنشور مرتبطاً بالمعرف الذي اختاره المستخدم.
    }

    return [
        'id' => $districtId,
        'governorate' => $gov,
        'parcel_name' => $name,
        'parcel_no' => '',
    ];
}

function vewo_reels_has_comments_enabled_column(PDO $pdo): bool
{
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'reels' AND column_name = 'comments_enabled'"
        );

        return $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_normalize_staff_permissions(mixed $raw): string
{
    $allowed = ['promotions', 'news', 'offices', 'parcels', 'properties', 'reels', 'engagement', 'chats', 'users', 'settings'];
    $items = [];
    if (is_array($raw)) {
        $items = $raw;
    } elseif (is_string($raw) && $raw !== '') {
        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            $items = $decoded;
        }
    }
    $clean = [];
    foreach ($items as $item) {
        $p = is_string($item) ? trim($item) : '';
        if ($p !== '' && in_array($p, $allowed, true) && !in_array($p, $clean, true)) {
            $clean[] = $p;
        }
    }

    return json_encode(array_values($clean), JSON_UNESCAPED_UNICODE);
}

function vewo_require_admin_permission(PDO $pdo, string $permission): void
{
    $admin = require_admin_from_bearer($pdo);
    if (($admin['role'] ?? '') === 'admin') {
        return;
    }
    $decoded = json_decode((string) ($admin['staff_permissions_json'] ?? '[]'), true);
    $permissions = is_array($decoded) ? $decoded : [];
    if (!in_array($permission, $permissions, true)) {
        json_error(403, 'لا تملك صلاحية هذا القسم');
    }
}

function users_me_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $user = user_public_json($me);
    if (($user['role'] ?? '') === 'office' && function_exists('vewo_users_has_posting_quota_columns') && vewo_users_has_posting_quota_columns($pdo)) {
        try {
            $q = $pdo->prepare(
                'SELECT posting_trial_unlimited, posting_listings_remaining FROM users WHERE id = :id LIMIT 1'
            );
            $q->execute([':id' => (string) $user['id']]);
            $pr = $q->fetch(PDO::FETCH_ASSOC);
            if (is_array($pr)) {
                $user['posting_trial_unlimited'] = (int) ($pr['posting_trial_unlimited'] ?? 1) === 1;
                $pv = $pr['posting_listings_remaining'] ?? null;
                $user['posting_listings_remaining'] = ($pv === null || $pv === '') ? null : (int) $pv;
            }
        } catch (Throwable $e) {
        }
    }
    echo json_encode([
        'ok' => true,
        'user' => $user,
    ], JSON_UNESCAPED_UNICODE);
}

function users_update_profile_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $uid = (string) ($me['id'] ?? '');
    if ($uid === '') {
        json_error(401, 'رمز غير صالح أو منتهٍ');
    }
    $in = read_json_body();
    $fullName = trim((string) ($in['full_name'] ?? ''));
    if (mb_strlen($fullName, 'UTF-8') < 2) {
        json_error(400, 'الاسم قصير جداً');
    }
    $profilePhoto = trim((string) ($in['profile_photo_url'] ?? ''));
    $officePhoto = trim((string) ($in['office_photo_url'] ?? ''));
    $officeName = trim((string) ($in['office_name'] ?? ''));
    $hasProfilePhoto = vewo_users_has_profile_photo_column($pdo);
    $isOffice = (string) ($me['role'] ?? '') === 'office';

    if ($profilePhoto !== '' && !$hasProfilePhoto) {
        json_error(400, 'تحديث صورة الحساب يحتاج تشغيل باتش profile_photo_url');
    }
    if (($profilePhoto !== '' && !preg_match('#^https?://#i', $profilePhoto)) || ($officePhoto !== '' && !preg_match('#^https?://#i', $officePhoto))) {
        json_error(400, 'رابط الصورة غير صالح');
    }

    $sets = ['full_name = :fn'];
    $params = [':fn' => $fullName, ':id' => $uid];
    if ($profilePhoto !== '') {
        $sets[] = 'profile_photo_url = :pp';
        $params[':pp'] = $profilePhoto;
    }
    if ($isOffice && $officePhoto !== '') {
        $sets[] = 'office_photo_url = :op';
        $params[':op'] = $officePhoto;
    }
    if ($isOffice && $officeName !== '') {
        $sets[] = 'office_name = :oname';
        $params[':oname'] = $officeName;
    }
    $stmt = $pdo->prepare('UPDATE users SET ' . implode(', ', $sets) . ' WHERE id = :id LIMIT 1');
    $stmt->execute($params);

    $emailSelect = vewo_users_has_email_column($pdo) ? 'email' : "'' AS email";
    $profileSelect = $hasProfilePhoto ? 'profile_photo_url' : "'' AS profile_photo_url";
    $quotaSelect = function_exists('vewo_users_has_posting_quota_columns') && vewo_users_has_posting_quota_columns($pdo)
        ? 'posting_trial_unlimited, posting_listings_remaining,'
        : '';
    $fresh = $pdo->prepare(
        'SELECT id, full_name, phone, ' . $emailSelect . ', role, office_approved, office_name, office_photo_url,
                ' . $profileSelect . ', ' . $quotaSelect . '
                is_active
         FROM users WHERE id = :id LIMIT 1'
    );
    $fresh->execute([':id' => $uid]);
    echo json_encode([
        'ok' => true,
        'user' => user_public_json($fresh->fetch(PDO::FETCH_ASSOC)),
    ], JSON_UNESCAPED_UNICODE);
}

function admin_stats_route(PDO $pdo): void
{
    require_admin_from_bearer($pdo);
    vewo_engagement_process_due_rules($pdo);
    $pendingProps = (int) $pdo->query(
        "SELECT COUNT(*) FROM properties WHERE approval_status = 'pending'"
    )->fetchColumn();
    $approvedProps = (int) $pdo->query(
        "SELECT COUNT(*) FROM properties WHERE approval_status = 'approved'"
    )->fetchColumn();
    $totalProps = (int) $pdo->query(
        'SELECT COUNT(*) FROM properties'
    )->fetchColumn();
    $pendingOffices = (int) $pdo->query(
        "SELECT COUNT(*) FROM users WHERE role = 'office' AND office_approved = 0 AND is_active = 1"
    )->fetchColumn();
    $activeUsers = (int) $pdo->query(
        'SELECT COUNT(*) FROM users WHERE is_active = 1'
    )->fetchColumn();
    $activeCustomers = (int) $pdo->query(
        "SELECT COUNT(*) FROM users WHERE role = 'customer' AND is_active = 1"
    )->fetchColumn();
    $activeOffices = (int) $pdo->query(
        "SELECT COUNT(*) FROM users WHERE role = 'office' AND is_active = 1"
    )->fetchColumn();
    $activeStaff = (int) $pdo->query(
        "SELECT COUNT(*) FROM users WHERE role = 'staff' AND is_active = 1"
    )->fetchColumn();
    $activeAdmins = (int) $pdo->query(
        "SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1"
    )->fetchColumn();
    $threads = (int) $pdo->query(
        'SELECT COUNT(*) FROM chat_threads'
    )->fetchColumn();
    $readThreads = (int) $pdo->query(
        'SELECT COUNT(*) FROM chat_threads WHERE COALESCE(admin_unread_count, 0) = 0'
    )->fetchColumn();
    $unreadThreads = (int) $pdo->query(
        'SELECT COUNT(*) FROM chat_threads WHERE COALESCE(admin_unread_count, 0) > 0'
    )->fetchColumn();
    $adminUnread = (int) $pdo->query(
        'SELECT COALESCE(SUM(admin_unread_count), 0) FROM chat_threads'
    )->fetchColumn();

    $pendingReels = 0;
    $approvedReels = 0;
    $totalReels = 0;
    $totalPropertyViews = 0;
    $totalReelViews = 0;
    $totalReelLikesReal = 0;
    $top_property = null;
    $top_reel = null;
    $urgentSaleItems = [];
    try {
        $pendingReels = (int) $pdo->query(
            "SELECT COUNT(*) FROM reels WHERE approval_status = 'pending'"
        )->fetchColumn();
        $approvedReels = (int) $pdo->query(
            "SELECT COUNT(*) FROM reels WHERE approval_status = 'approved'"
        )->fetchColumn();
        $totalReels = (int) $pdo->query('SELECT COUNT(*) FROM reels')->fetchColumn();
    } catch (Throwable $e) {
    }
    try {
        $totalPropertyViews = (int) $pdo->query(
            'SELECT COALESCE(SUM(views), 0) FROM properties'
        )->fetchColumn();
    } catch (Throwable $e) {
    }
    if (vewo_reels_has_engagement_columns($pdo)) {
        try {
            $totalReelViews = (int) $pdo->query('SELECT COALESCE(SUM(view_count), 0) FROM reels')->fetchColumn();
        } catch (Throwable $e) {
        }
    }
    try {
        $totalReelLikesReal = (int) $pdo->query('SELECT COUNT(*) FROM reel_reactions')->fetchColumn();
    } catch (Throwable $e) {
    }
    try {
        $tp = $pdo->query(
            "SELECT p.id, p.title, p.property_public_no, p.views,
                    (SELECT m.public_url FROM property_media m WHERE m.property_id = p.id AND m.media_type = 'image' ORDER BY m.created_at ASC LIMIT 1) AS thumb_url
             FROM properties p
             WHERE p.approval_status = 'approved'
             ORDER BY p.views DESC
             LIMIT 1"
        )->fetch(PDO::FETCH_ASSOC);
        if (is_array($tp)) {
            $top_property = $tp;
        }
    } catch (Throwable $e) {
    }
    if (vewo_reels_has_engagement_columns($pdo)) {
        try {
            $tr = $pdo->query(
                "SELECT r.id, r.caption, r.reel_public_no, r.video_public_url, r.view_count, r.synthetic_likes,
                        (SELECT COUNT(*) FROM reel_reactions rr WHERE rr.reel_id = r.id) AS real_likes
                 FROM reels r
                 WHERE r.approval_status = 'approved'
                 ORDER BY (r.view_count + (SELECT COUNT(*) FROM reel_reactions rr2 WHERE rr2.reel_id = r.id) + r.synthetic_likes) DESC
                 LIMIT 1"
            )->fetch(PDO::FETCH_ASSOC);
            if (is_array($tr)) {
                $top_reel = $tr;
            }
        } catch (Throwable $e) {
        }
    }
    try {
        $urgentRows = $pdo->query(
            "SELECT p.id, p.title, p.property_public_no, p.details_json,
                    (SELECT m.public_url FROM property_media m WHERE m.property_id = p.id AND m.media_type = 'image' ORDER BY m.created_at ASC LIMIT 1) AS thumb_url
             FROM properties p
             WHERE p.approval_status = 'approved' AND p.details_json LIKE '%urgent_sale%'
             ORDER BY p.created_at DESC"
        )->fetchAll(PDO::FETCH_ASSOC);
        $now = new DateTimeImmutable('now');
        foreach ($urgentRows as $row) {
            $details = json_decode((string) ($row['details_json'] ?? ''), true);
            if (!is_array($details) || empty($details['urgent_sale'])) {
                continue;
            }
            $expiresRaw = trim((string) ($details['urgent_sale_expires_at'] ?? ''));
            $expiresAt = null;
            if ($expiresRaw !== '') {
                try {
                    $expiresAt = new DateTimeImmutable($expiresRaw);
                } catch (Throwable $e) {
                    $expiresAt = null;
                }
            }
            if ($expiresAt !== null && $expiresAt <= $now) {
                continue;
            }
            $urgentSaleItems[] = [
                'id' => (string) ($row['id'] ?? ''),
                'title' => (string) ($row['title'] ?? ''),
                'property_public_no' => $row['property_public_no'] ?? null,
                'thumb_url' => (string) ($row['thumb_url'] ?? ''),
                'urgent_sale_days' => (int) ($details['urgent_sale_days'] ?? 0),
                'urgent_sale_expires_at' => $expiresRaw,
            ];
        }
    } catch (Throwable $e) {
    }

    echo json_encode([
        'ok' => true,
        'pending_properties' => $pendingProps,
        'approved_properties' => $approvedProps,
        'total_properties' => $totalProps,
        'pending_offices' => $pendingOffices,
        'active_users' => $activeUsers,
        'active_customers' => $activeCustomers,
        'active_offices' => $activeOffices,
        'active_staff' => $activeStaff,
        'active_admins' => $activeAdmins,
        'chat_threads' => $threads,
        'chat_read_threads' => $readThreads,
        'chat_unread_threads' => $unreadThreads,
        'chat_unread' => $adminUnread,
        'pending_reels' => $pendingReels,
        'approved_reels' => $approvedReels,
        'total_reels' => $totalReels,
        'total_property_views' => $totalPropertyViews,
        'total_reel_views' => $totalReelViews,
        'total_reel_reaction_likes' => $totalReelLikesReal,
        'top_property' => $top_property,
        'top_reel' => $top_reel,
        'urgent_sale_count' => count($urgentSaleItems),
        'urgent_sale_items' => $urgentSaleItems,
    ], JSON_UNESCAPED_UNICODE);
}

function vewo_app_notifications_ensure(PDO $pdo): bool
{
    static $ok = null;
    if ($ok !== null) {
        return $ok;
    }
    try {
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS app_notifications (
                id CHAR(36) NOT NULL PRIMARY KEY,
                user_id CHAR(36) NOT NULL,
                event_type VARCHAR(80) NOT NULL,
                title VARCHAR(180) NOT NULL,
                body TEXT NULL,
                payload_json TEXT NULL,
                created_at DATETIME(3) NOT NULL,
                KEY idx_app_notifications_user_created (user_id, created_at),
                KEY idx_app_notifications_type_created (event_type, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        try {
            $chkRead = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'app_notifications' AND column_name = 'read_at'"
            );
            if ($chkRead !== false && (int) $chkRead->fetchColumn() === 0) {
                $pdo->exec(
                    "ALTER TABLE app_notifications
                     ADD COLUMN read_at DATETIME(3) NULL,
                     ADD KEY idx_app_notifications_user_read (user_id, read_at)"
                );
            }
        } catch (Throwable $e) {
        }
        $ok = true;
    } catch (Throwable $e) {
        $ok = false;
    }
    return $ok;
}

/**
 * @param array<string,mixed> $payload
 */
function vewo_app_notification_add(PDO $pdo, string $userId, string $eventType, string $title, string $body = '', array $payload = []): void
{
    if ($userId === '' || $title === '' || !vewo_app_notifications_ensure($pdo)) {
        return;
    }
    try {
        $stmt = $pdo->prepare(
            'INSERT INTO app_notifications (id, user_id, event_type, title, body, payload_json, created_at)
             VALUES (:id, :u, :t, :ti, :b, :p, NOW(3))'
        );
        $stmt->execute([
            ':id' => uuid_v4(),
            ':u' => $userId,
            ':t' => $eventType !== '' ? $eventType : 'system',
            ':ti' => $title,
            ':b' => $body,
            ':p' => !empty($payload) ? json_encode($payload, JSON_UNESCAPED_UNICODE) : null,
        ]);
    } catch (Throwable $e) {
    }
}

/**
 * إحصاءات وسجل إشعارات التطبيق.
 * - تتطلب تسجيل الدخول (Bearer token).
 * - الرسائل تبقى في قسم المحادثات فقط، ولا تُعاد ضمن سجل الإشعارات العامة.
 */
function app_notifications_poll_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $uid = (string) ($me['id'] ?? '');
    $role = (string) ($me['role'] ?? '');

    $sinceMs = (int) ($_GET['since_ms'] ?? $_GET['sinceMs'] ?? 0);
    $markRead = (string) ($_GET['mark_read'] ?? $_GET['markRead'] ?? '') === '1';
    if ($sinceMs < 0) {
        $sinceMs = 0;
    }
    // حد أقصى للرجوع: 30 يوم لتجنب استعلامات ثقيلة.
    $maxBackMs = 30 * 24 * 60 * 60 * 1000;
    $nowMs = (int) floor(microtime(true) * 1000);
    if ($sinceMs > $nowMs) {
        $sinceMs = $nowMs;
    }
    if ($nowMs - $sinceMs > $maxBackMs) {
        $sinceMs = $nowMs - $maxBackMs;
    }

    $sinceSec = $sinceMs / 1000.0;

    $out = [
        'ok' => true,
        'now_ms' => $nowMs,
        'since_ms' => $sinceMs,
        'counts' => [
            'chat_unread' => 0,
            'reel_new_comments_on_my_reels' => 0,
            'reel_new_replies_to_my_comments' => 0,
            'reel_new_likes_on_my_comments' => 0,
            'properties_new_sold' => 0,
        ],
        'items' => [],
    ];

    // 1) المحادثات: عدد غير المقروء بحسب خانة المستخدم:
    // customer_user_id = المستفسر، office_user_id = المعلن.
    try {
        if (in_array($role, ['customer', 'office', 'marketer'], true)) {
            $stmt = $pdo->prepare(
                "SELECT COALESCE(SUM(
                    CASE WHEN t.office_user_id = :uid1 THEN COALESCE(t.office_unread_count, 0)
                         WHEN t.customer_user_id = :uid2 THEN COALESCE(t.customer_unread_count, 0)
                         ELSE COALESCE(t.customer_unread_count, 0)
                    END
                 ), 0) AS u
                 FROM chat_threads t
                 WHERE ((t.thread_type = 'mediated' AND (t.customer_user_id = :uid3 OR t.office_user_id = :uid4))
                    OR (t.thread_type = 'direct' AND (t.customer_user_id = :uid5 OR t.office_user_id = :uid6)))"
            );
            $stmt->execute([
                ':uid1' => $uid,
                ':uid2' => $uid,
                ':uid3' => $uid,
                ':uid4' => $uid,
                ':uid5' => $uid,
                ':uid6' => $uid,
            ]);
            $out['counts']['chat_unread'] = (int) ($stmt->fetchColumn() ?: 0);
        } else {
            $out['counts']['chat_unread'] = 0;
        }
    } catch (Throwable $e) {
        // تجاهل: قد لا تكون جداول المحادثات موجودة في بعض البيئات.
    }

    // 2) تعليقات جديدة على ريلز المملوكة للمستخدم.
    try {
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM reel_comments c
             INNER JOIN reels r ON r.id = c.reel_id
             WHERE r.owner_user_id = :uid AND c.created_at > FROM_UNIXTIME(:since)"
        );
        $stmt->execute([':uid' => $uid, ':since' => $sinceSec]);
        $out['counts']['reel_new_comments_on_my_reels'] = (int) ($stmt->fetchColumn() ?: 0);
    } catch (Throwable $e) {
        // تجاهل: قد لا تكون الجداول مثبتة.
    }

    // 3) ردود جديدة على تعليقاتي.
    try {
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM reel_comments c
             INNER JOIN reel_comments p ON p.id = c.parent_comment_id
             WHERE p.user_id = :uid AND c.created_at > FROM_UNIXTIME(:since)"
        );
        $stmt->execute([':uid' => $uid, ':since' => $sinceSec]);
        $out['counts']['reel_new_replies_to_my_comments'] = (int) ($stmt->fetchColumn() ?: 0);
    } catch (Throwable $e) {
    }

    // 4) إعجابات جديدة على تعليقاتي.
    try {
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM reel_comment_likes l
             INNER JOIN reel_comments c ON c.id = l.comment_id
             WHERE c.user_id = :uid AND l.created_at > FROM_UNIXTIME(:since)"
        );
        $stmt->execute([':uid' => $uid, ':since' => $sinceSec]);
        $out['counts']['reel_new_likes_on_my_comments'] = (int) ($stmt->fetchColumn() ?: 0);
    } catch (Throwable $e) {
    }

    // 5) تم البيع: منشورات المالك التي تم تعليمها كمباعة منذ since.
    try {
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM properties
             WHERE owner_user_id = :uid AND is_sold = 1 AND sold_at IS NOT NULL
               AND sold_at > FROM_UNIXTIME(:since)"
        );
        $stmt->execute([':uid' => $uid, ':since' => $sinceSec]);
        $out['counts']['properties_new_sold'] = (int) ($stmt->fetchColumn() ?: 0);
    } catch (Throwable $e) {
    }

    try {
        if (vewo_app_notifications_ensure($pdo)) {
            if ($markRead) {
                $mr = $pdo->prepare(
                    'UPDATE app_notifications SET read_at = COALESCE(read_at, NOW(3)) WHERE user_id = :uid'
                );
                $mr->execute([':uid' => $uid]);
            }
            try {
                $uc = $pdo->prepare(
                    'SELECT COUNT(*) FROM app_notifications WHERE user_id = :uid AND read_at IS NULL'
                );
                $uc->execute([':uid' => $uid]);
                $out['counts']['unread_app_notifications'] = (int) ($uc->fetchColumn() ?: 0);
            } catch (Throwable $e) {
                $out['counts']['unread_app_notifications'] = 0;
            }
            $stmt = $pdo->prepare(
                'SELECT id, event_type, title, body, payload_json, created_at, read_at
                 FROM app_notifications
                 WHERE user_id = :uid
                 ORDER BY created_at DESC
                 LIMIT 100'
            );
            $stmt->execute([':uid' => $uid]);
            $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
            foreach ($rows as &$r) {
                $payload = [];
                $rawPayload = trim((string) ($r['payload_json'] ?? ''));
                if ($rawPayload !== '') {
                    $decoded = json_decode($rawPayload, true);
                    if (is_array($decoded)) {
                        $payload = $decoded;
                    }
                }
                unset($r['payload_json']);
                $r['payload'] = $payload;
                $propId = trim((string) ($payload['property_id'] ?? ''));
                if ($propId !== '') {
                    $summary = vewo_property_summary_array($pdo, $propId);
                    if (is_array($summary)) {
                        $r['property'] = [
                            'id' => $summary['id'] ?? $propId,
                            'property_public_no' => $summary['property_public_no'] ?? null,
                            'title' => $summary['title'] ?? '',
                            'thumb_url' => $summary['thumb_url'] ?? '',
                            'approval_status' => $summary['approval_status'] ?? '',
                            'reject_note' => $summary['reject_note'] ?? '',
                            'resubmission_allowed' => $summary['resubmission_allowed'] ?? 0,
                        ];
                    }
                }
            }
            unset($r);
            $out['items'] = $rows;
        }
    } catch (Throwable $e) {
    }

    echo json_encode($out, JSON_UNESCAPED_UNICODE);
}

/**
 * قائمة المحافظات (للتطبيق) — قابلة للتعطيل/التعديل من الأدمن.
 * - GET فقط
 * - إن لم تكن الجداول مثبتة: يعيد قائمة فارغة (التطبيق يستخدم fallback).
 */
function app_governorates_list_route(PDO $pdo): void
{
    try {
        $stmt = $pdo->query(
            "SELECT name FROM governorates WHERE is_active = 1
             ORDER BY sort_order ASC, name ASC LIMIT 200"
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        $items = [];
        foreach ($rows as $r) {
            $n = trim((string) ($r['name'] ?? ''));
            if ($n !== '') $items[] = $n;
        }
        echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
    } catch (Throwable $e) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);
    }
}

/**
 * محافظات مع معرف (للتطبيق: ربط قضاء/ناحية).
 */
function app_governorates_full_route(PDO $pdo): void
{
    try {
        $stmt = $pdo->query(
            "SELECT id, name FROM governorates WHERE is_active = 1
             ORDER BY sort_order ASC, name ASC LIMIT 200"
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        $items = [];
        foreach ($rows as $r) {
            $id = trim((string) ($r['id'] ?? ''));
            $n = trim((string) ($r['name'] ?? ''));
            if ($id !== '' && $n !== '') {
                $items[] = ['id' => $id, 'name' => $n];
            }
        }
        echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
    } catch (Throwable $e) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);
    }
}

function vewo_property_requests_ensure(PDO $pdo): bool
{
    try {
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS property_requests (
                id CHAR(36) NOT NULL PRIMARY KEY,
                request_no INT NOT NULL UNIQUE,
                user_id CHAR(36) NOT NULL,
                purpose VARCHAR(20) NOT NULL,
                category VARCHAR(40) NOT NULL,
                area_min INT NULL,
                area_max INT NULL,
                price_min BIGINT NULL,
                price_max BIGINT NULL,
                governorate VARCHAR(120) NOT NULL,
                phone VARCHAR(32) NOT NULL,
                description TEXT NULL,
                status VARCHAR(30) NOT NULL DEFAULT 'pending',
                created_at DATETIME(3) NOT NULL,
                updated_at DATETIME(3) NULL,
                closed_at DATETIME(3) NULL,
                KEY idx_property_requests_user_created (user_id, created_at),
                KEY idx_property_requests_status_created (status, created_at),
                KEY idx_property_requests_no (request_no)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        return true;
    } catch (Throwable $e) {
        return false;
    }
}

function vewo_property_request_next_no(PDO $pdo): int
{
    $pdo->query("SELECT GET_LOCK('vewo_property_request_no', 5)");
    try {
        return (int) $pdo->query(
            'SELECT COALESCE(MAX(request_no), 50000000) + 1 FROM property_requests'
        )->fetchColumn();
    } finally {
        $pdo->query("SELECT RELEASE_LOCK('vewo_property_request_no')");
    }
}

function vewo_property_request_public(array $r): array
{
    return [
        'id' => (string) ($r['id'] ?? ''),
        'request_no' => (int) ($r['request_no'] ?? 0),
        'user_id' => (string) ($r['user_id'] ?? ''),
        'customer_name' => (string) ($r['customer_name'] ?? ''),
        'purpose' => (string) ($r['purpose'] ?? ''),
        'category' => (string) ($r['category'] ?? ''),
        'area_min' => $r['area_min'] === null ? null : (int) $r['area_min'],
        'area_max' => $r['area_max'] === null ? null : (int) $r['area_max'],
        'price_min' => $r['price_min'] === null ? null : (int) $r['price_min'],
        'price_max' => $r['price_max'] === null ? null : (int) $r['price_max'],
        'governorate' => (string) ($r['governorate'] ?? ''),
        'phone' => (string) ($r['phone'] ?? ''),
        'description' => (string) ($r['description'] ?? ''),
        'status' => (string) ($r['status'] ?? 'pending'),
        'created_at' => (string) ($r['created_at'] ?? ''),
        'updated_at' => $r['updated_at'] ?? null,
        'closed_at' => $r['closed_at'] ?? null,
    ];
}

function property_requests_create_route(PDO $pdo): void
{
    if (!vewo_property_requests_ensure($pdo)) json_error(500, 'تعذر تجهيز جدول طلبات العقار');
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $purpose = trim((string) ($in['purpose'] ?? ''));
    $category = trim((string) ($in['category'] ?? ''));
    $governorate = trim((string) ($in['governorate'] ?? ''));
    $phone = trim((string) ($in['phone'] ?? $me['phone'] ?? ''));
    $description = trim((string) ($in['description'] ?? ''));
    if (!in_array($purpose, ['sale', 'rent'], true)) json_error(400, 'حدد بيعاً أو إيجاراً');
    if (!in_array($category, ['land', 'house', 'apartment', 'shop', 'villa', 'compound', 'parcel'], true)) json_error(400, 'اختر قسماً صحيحاً');
    if ($governorate === '') json_error(400, 'اختر المحافظة');
    if (!preg_match('/^07[0-9]{9}$/', $phone)) json_error(400, 'رقم الموبايل غير صالح');
    if ($description !== '' && mb_strlen($description, 'UTF-8') > 7000) json_error(400, 'الوصف طويل جداً');
    $toInt = static function (mixed $v): ?int {
        if ($v === null || $v === '') return null;
        $n = (int) $v;
        return $n > 0 ? $n : null;
    };
    $areaMin = $toInt($in['area_min'] ?? null);
    $areaMax = $toInt($in['area_max'] ?? null);
    $priceMin = $toInt($in['price_min'] ?? null);
    $priceMax = $toInt($in['price_max'] ?? null);
    if ($areaMin !== null && $areaMax !== null && $areaMin > $areaMax) json_error(400, 'مدى المساحة غير صحيح');
    if ($priceMin !== null && $priceMax !== null && $priceMin > $priceMax) json_error(400, 'مدى السعر غير صحيح');
    $id = uuid_v4();
    $no = vewo_property_request_next_no($pdo);
    $stmt = $pdo->prepare(
        'INSERT INTO property_requests
            (id, request_no, user_id, purpose, category, area_min, area_max, price_min, price_max, governorate, phone, description, status, created_at)
         VALUES
            (:id, :no, :u, :purpose, :category, :amin, :amax, :pmin, :pmax, :gov, :phone, :descr, \'pending\', NOW(3))'
    );
    $stmt->execute([
        ':id' => $id,
        ':no' => $no,
        ':u' => (string) ($me['id'] ?? ''),
        ':purpose' => $purpose,
        ':category' => $category,
        ':amin' => $areaMin,
        ':amax' => $areaMax,
        ':pmin' => $priceMin,
        ':pmax' => $priceMax,
        ':gov' => $governorate,
        ':phone' => $phone,
        ':descr' => $description,
    ]);
    try {
        $adminId = first_admin_user_id($pdo);
        if ($adminId !== '') {
            vewo_fcm_send(
                vewo_device_tokens_for_user($pdo, $adminId, true),
                'طلب عقار جديد',
                'وصل طلب عقار رقم #' . $no,
                ['type' => 'property_request', 'section' => 'property_requests', 'request_no' => $no]
            );
        }
    } catch (Throwable $e) {
    }
    echo json_encode(['ok' => true, 'id' => $id, 'request_no' => $no], JSON_UNESCAPED_UNICODE);
}

function property_requests_my_route(PDO $pdo): void
{
    if (!vewo_property_requests_ensure($pdo)) json_error(500, 'تعذر تجهيز جدول طلبات العقار');
    $me = require_auth_user($pdo);
    $q = trim((string) ($_GET['q'] ?? ''));
    $sql = 'SELECT pr.*, u.full_name AS customer_name
            FROM property_requests pr
            INNER JOIN users u ON u.id = pr.user_id
            WHERE pr.user_id = :u';
    $params = [':u' => (string) ($me['id'] ?? '')];
    if ($q !== '' && ctype_digit(ltrim($q, '#'))) {
        $sql .= ' AND pr.request_no = :no';
        $params[':no'] = (int) ltrim($q, '#');
    }
    $sql .= ' ORDER BY pr.created_at DESC LIMIT 100';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $items = array_map('vewo_property_request_public', $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []);
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}

function admin_property_requests_route(PDO $pdo): void
{
    if (!vewo_property_requests_ensure($pdo)) json_error(500, 'تعذر تجهيز جدول طلبات العقار');
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        $status = trim((string) ($_GET['status'] ?? ''));
        $q = trim((string) ($_GET['q'] ?? ''));
        $from = trim((string) ($_GET['from'] ?? ''));
        $to = trim((string) ($_GET['to'] ?? ''));
        $sql = 'SELECT pr.*, u.full_name AS customer_name
                FROM property_requests pr
                INNER JOIN users u ON u.id = pr.user_id
                WHERE 1=1';
        $params = [];
        if (in_array($status, ['pending', 'in_progress', 'closed'], true)) {
            $sql .= ' AND pr.status = :status';
            $params[':status'] = $status;
        }
        if ($q !== '' && ctype_digit(ltrim($q, '#'))) {
            $sql .= ' AND pr.request_no = :no';
            $params[':no'] = (int) ltrim($q, '#');
        }
        if ($from !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $from)) {
            $sql .= ' AND pr.created_at >= :from_date';
            $params[':from_date'] = $from . ' 00:00:00';
        }
        if ($to !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $to)) {
            $sql .= ' AND pr.created_at <= :to_date';
            $params[':to_date'] = $to . ' 23:59:59';
        }
        $sql .= ' ORDER BY pr.created_at DESC LIMIT 200';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        $items = array_map('vewo_property_request_public', $stmt->fetchAll(PDO::FETCH_ASSOC) ?: []);
        echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
        return;
    }
    if ($method === 'POST') {
        $in = read_json_body();
        $id = trim((string) ($in['id'] ?? ''));
        $status = trim((string) ($in['status'] ?? ''));
        if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) json_error(400, 'id غير صالح');
        if (!in_array($status, ['pending', 'in_progress', 'closed'], true)) json_error(400, 'الحالة غير صالحة');
        $stmt = $pdo->prepare(
            "UPDATE property_requests
             SET status = :s, updated_at = NOW(3), closed_at = CASE WHEN :s2 = 'closed' THEN NOW(3) ELSE closed_at END
             WHERE id = :id LIMIT 1"
        );
        $stmt->execute([':s' => $status, ':s2' => $status, ':id' => $id]);
        echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
        return;
    }
    json_error(405, 'Method not allowed');
}

/**
 * قائمة الأقضية/النواحي لمحافظة (عامة — للنشر في التطبيق).
 */
function app_districts_public_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    $gid = trim((string) ($_GET['governorate_id'] ?? ''));
    if ($gid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $gid)) {
        json_error(400, 'governorate_id مطلوب');
    }
    try {
        $stmt = $pdo->prepare(
            'SELECT id, governorate_id, name, sort_order
             FROM districts WHERE governorate_id = :g AND is_active = 1
             ORDER BY sort_order ASC, name ASC LIMIT 500'
        );
        $stmt->execute([':g' => $gid]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);

        return;
    }
    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}

/**
 * إدارة المحافظات (لوحة الأدمن).
 * - GET: جميع المحافظات
 * - POST: upsert (تعديل الاسم/التفعيل/الترتيب) أو create.
 */
function admin_governorates_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        try {
            $stmt = $pdo->query(
                "SELECT id, name, is_active, sort_order, created_at
                 FROM governorates
                 ORDER BY sort_order ASC, name ASC LIMIT 500"
            );
            $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
            echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            json_error(400, 'جدول المحافظات غير مثبت');
        }
        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? 'upsert'));
        if ($action === 'delete') {
            $id = trim((string) ($in['id'] ?? ''));
            if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
                json_error(400, 'id غير صالح');
            }
            try {
                $stmt = $pdo->prepare('DELETE FROM governorates WHERE id = :id LIMIT 1');
                $stmt->execute([':id' => $id]);
                echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
            } catch (Throwable $e) {
                json_error(500, 'تعذر الحذف');
            }
            return;
        }
        if ($action === 'create') {
            $name = trim((string) ($in['name'] ?? ''));
            if ($name === '') json_error(400, 'الاسم مطلوب');
            $active = (int) ($in['is_active'] ?? 1) === 1 ? 1 : 0;
            $sort = (int) ($in['sort_order'] ?? 0);
            try {
                $id = uuid_v4();
                $stmt = $pdo->prepare(
                    'INSERT INTO governorates (id, name, is_active, sort_order, created_at)
                     VALUES (:id, :n, :a, :s, NOW())'
                );
                $stmt->execute([':id' => $id, ':n' => $name, ':a' => $active, ':s' => $sort]);
                echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);
            } catch (Throwable $e) {
                json_error(500, 'تعذر إنشاء المحافظة');
            }
            return;
        }
        // upsert/update
        $id = trim((string) ($in['id'] ?? ''));
        if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            json_error(400, 'id غير صالح');
        }
        $name = trim((string) ($in['name'] ?? ''));
        if ($name === '') json_error(400, 'الاسم مطلوب');
        $active = (int) ($in['is_active'] ?? 1) === 1 ? 1 : 0;
        $sort = (int) ($in['sort_order'] ?? 0);
        try {
            $stmt = $pdo->prepare(
                'UPDATE governorates SET name = :n, is_active = :a, sort_order = :s
                 WHERE id = :id LIMIT 1'
            );
            $stmt->execute([':n' => $name, ':a' => $active, ':s' => $sort, ':id' => $id]);
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            json_error(500, 'تعذر حفظ التعديل');
        }
        return;
    }
    json_error(405, 'Method not allowed');
}

/**
 * أقضية / نواحي تحت محافظة (لوحة الأدمن).
 */
function admin_districts_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        $gid = trim((string) ($_GET['governorate_id'] ?? ''));
        if ($gid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $gid)) {
            json_error(400, 'governorate_id مطلوب');
        }
        if (!vewo_districts_table_exists($pdo)) {
            json_error(
                500,
                'جدول districts غير موجود على قاعدة البيانات. نفّذ ملف SQL: backend/db/patch_districts_ensure_mysql.sql (بعد التأكد من وجود جدول governorates).'
            );

            return;
        }
        try {
            $hasKind = vewo_districts_has_kind_column($pdo);
            $kindExpr = $hasKind ? '`kind`' : "'qada' AS kind";
            $stmt = $pdo->prepare(
                'SELECT id, governorate_id, name, ' . $kindExpr . ', sort_order, is_active, created_at
                 FROM `districts` WHERE governorate_id = :g
                 ORDER BY sort_order ASC, name ASC LIMIT 500'
            );
            $stmt->execute([':g' => $gid]);
            $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        } catch (Throwable $e) {
            json_error(
                500,
                'خطأ في قراءة districts — تأكد من تنفيذ patch_districts_ensure_mysql.sql وأن جدول governorates موجود.'
            );

            return;
        }
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? 'upsert'));
        if ($action === 'delete') {
            $id = trim((string) ($in['id'] ?? ''));
            if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
                json_error(400, 'id غير صالح');
            }
            try {
                $stmt = $pdo->prepare('DELETE FROM `districts` WHERE id = :id LIMIT 1');
                $stmt->execute([':id' => $id]);
                echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
            } catch (Throwable $e) {
                json_error(500, 'تعذر الحذف — تأكد من تثبيت جدول districts');
            }

            return;
        }
        $gid = trim((string) ($in['governorate_id'] ?? ''));
        if ($gid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $gid)) {
            json_error(400, 'governorate_id غير صالح');
        }
        $name = trim((string) ($in['name'] ?? ''));
        if ($name === '' || mb_strlen($name) < 2) {
            json_error(400, 'اسم القضاء أو الناحية مطلوب');
        }
        $sort = (int) ($in['sort_order'] ?? 0);
        $active = (int) ($in['is_active'] ?? 1) === 1 ? 1 : 0;
        $kindIn = trim((string) ($in['kind'] ?? 'qada'));
        if (!in_array($kindIn, ['qada', 'nahi'], true)) {
            $kindIn = 'qada';
        }
        $hasKind = vewo_districts_has_kind_column($pdo);
        $id = trim((string) ($in['id'] ?? ''));
        try {
            if ($id === '') {
                $id = uuid_v4();
                if ($hasKind) {
                    $stmt = $pdo->prepare(
                        'INSERT INTO `districts` (id, governorate_id, name, `kind`, sort_order, is_active, created_at)
                         VALUES (:id, :g, :n, :k, :s, :a, NOW())'
                    );
                    $stmt->execute([
                        ':id' => $id,
                        ':g' => $gid,
                        ':n' => $name,
                        ':k' => $kindIn,
                        ':s' => $sort,
                        ':a' => $active,
                    ]);
                } else {
                    $stmt = $pdo->prepare(
                        'INSERT INTO `districts` (id, governorate_id, name, sort_order, is_active, created_at)
                         VALUES (:id, :g, :n, :s, :a, NOW())'
                    );
                    $stmt->execute([':id' => $id, ':g' => $gid, ':n' => $name, ':s' => $sort, ':a' => $active]);
                }
            } else {
                if (!preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
                    json_error(400, 'id غير صالح');
                }
                if ($hasKind) {
                    $stmt = $pdo->prepare(
                        'UPDATE `districts` SET name = :n, `kind` = :k, sort_order = :s, is_active = :a
                         WHERE id = :id AND governorate_id = :g LIMIT 1'
                    );
                    $stmt->execute([
                        ':n' => $name,
                        ':k' => $kindIn,
                        ':s' => $sort,
                        ':a' => $active,
                        ':id' => $id,
                        ':g' => $gid,
                    ]);
                } else {
                    $stmt = $pdo->prepare(
                        'UPDATE `districts` SET name = :n, sort_order = :s, is_active = :a
                         WHERE id = :id AND governorate_id = :g LIMIT 1'
                    );
                    $stmt->execute([':n' => $name, ':s' => $sort, ':a' => $active, ':id' => $id, ':g' => $gid]);
                }
            }
            echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            json_error(500, 'تعذر الحفظ — نفّذ patch_users_profile_marketer_districts_mysql.sql');
        }

        return;
    }
    json_error(405, 'Method not allowed');
}

/**
 * تقارير مجمّعة للوحة (من — إلى).
 */
function admin_reports_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    require_admin_from_bearer($pdo);
    $from = trim((string) ($_GET['from'] ?? ''));
    $to = trim((string) ($_GET['to'] ?? ''));
    $fromDt = $from !== '' ? DateTimeImmutable::createFromFormat('Y-m-d', $from) : null;
    $toDt = $to !== '' ? DateTimeImmutable::createFromFormat('Y-m-d', $to) : null;
    if ($fromDt === false || $toDt === false) {
        $toDt = new DateTimeImmutable('today');
        $fromDt = $toDt->modify('-30 days');
    }
    if ($fromDt === null) {
        $fromDt = new DateTimeImmutable('-30 days');
    }
    if ($toDt === null) {
        $toDt = new DateTimeImmutable('today');
    }
    $start = $fromDt->setTime(0, 0, 0)->format('Y-m-d H:i:s');
    $end = $toDt->setTime(23, 59, 59)->format('Y-m-d H:i:s');

    try {
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM properties WHERE created_at BETWEEN :a AND :b"
        );
        $stmt->execute([':a' => $start, ':b' => $end]);
        $newProps = (int) $stmt->fetchColumn();

        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM properties WHERE COALESCE(is_sold,0)=1 AND sold_at BETWEEN :a AND :b"
        );
        $stmt->execute([':a' => $start, ':b' => $end]);
        $soldProps = (int) $stmt->fetchColumn();

        $stmt = $pdo->prepare(
            "SELECT COUNT(*) FROM users WHERE created_at BETWEEN :a AND :b"
        );
        $stmt->execute([':a' => $start, ':b' => $end]);
        $newUsers = (int) $stmt->fetchColumn();

        $stmt = $pdo->prepare(
            "SELECT role, COUNT(*) AS c FROM users WHERE created_at BETWEEN :a AND :b GROUP BY role"
        );
        $stmt->execute([':a' => $start, ':b' => $end]);
        $byRole = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        json_error(500, 'تعذر حساب التقارير');
    }

    echo json_encode([
        'ok' => true,
        'range' => ['from' => $start, 'to' => $end],
        'new_properties' => $newProps,
        'sold_properties' => $soldProps,
        'new_users' => $newUsers,
        'new_users_by_role' => $byRole,
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * تفاصيل مستخدم واحد للأدمن (صفحة تعريفية).
 */
function admin_user_detail_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    require_admin_from_bearer($pdo);
    $id = trim((string) ($_GET['id'] ?? ''));
    if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'id مطلوب');
    }
    $stmt = $pdo->prepare('SELECT * FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row)) {
        json_error(404, 'المستخدم غير موجود');
    }
    unset($row['password_hash']);
    echo json_encode(['ok' => true, 'user' => $row], JSON_UNESCAPED_UNICODE);
}

/**
 * بث رسالة عامة لكل المستخدمين (Polling + Local Notifications).
 * - GET (للتطبيق): يعيد الرسائل النشطة بعد since_ms.
 */
function app_broadcast_poll_route(PDO $pdo): void
{
    $sinceMs = (int) ($_GET['since_ms'] ?? $_GET['sinceMs'] ?? 0);
    if ($sinceMs < 0) $sinceMs = 0;
    $sinceSec = $sinceMs / 1000.0;
    try {
        $stmt = $pdo->prepare(
            "SELECT id, title, body, created_at
             FROM broadcast_messages
             WHERE is_active = 1 AND created_at > FROM_UNIXTIME(:since)
             ORDER BY created_at ASC
             LIMIT 50"
        );
        $stmt->execute([':since' => $sinceSec]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode([
            'ok' => true,
            'now_ms' => (int) floor(microtime(true) * 1000),
            'items' => $rows,
        ], JSON_UNESCAPED_UNICODE);
    } catch (Throwable $e) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);
    }
}

/**
 * إرسال رسالة عامة من الأدمن.
 * - POST: create broadcast message.
 */
function admin_broadcast_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $title = trim((string) ($in['title'] ?? ''));
        $body = trim((string) ($in['body'] ?? ''));
        if ($title === '' && $body === '') {
            json_error(400, 'النص مطلوب');
        }
        try {
            $id = uuid_v4();
            $stmt = $pdo->prepare(
                'INSERT INTO broadcast_messages (id, title, body, is_active, created_at)
                 VALUES (:id, :t, :b, 1, NOW())'
            );
            $stmt->execute([':id' => $id, ':t' => $title, ':b' => $body]);
            echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            json_error(500, 'تعذر إرسال الرسالة');
        }
        return;
    }
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        try {
            $stmt = $pdo->query(
                "SELECT id, title, body, is_active, created_at
                 FROM broadcast_messages
                 ORDER BY created_at DESC LIMIT 50"
            );
            $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
            echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);
        }
        return;
    }
    json_error(405, 'Method not allowed');
}

function admin_offices_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        $scope = trim((string) ($_GET['scope'] ?? 'pending'));
        $mkt = vewo_users_has_is_marketer_column($pdo) ? 'u.is_marketer' : '0 AS is_marketer';
        $pp = vewo_users_has_profile_photo_column($pdo) ? 'u.profile_photo_url' : "'' AS profile_photo_url";
        $em = vewo_users_has_email_column($pdo) ? 'u.email' : "'' AS email";
        $ov = 'u.office_verified';
        try {
            $pdo->query('SELECT office_verified FROM users LIMIT 1');
        } catch (Throwable $e) {
            $ov = '0 AS office_verified';
        }
        $orderApproved = str_contains((string) $ov, ' AS ')
            ? 'u.created_at DESC'
            : 'u.office_verified DESC, u.created_at DESC';
        if ($scope === 'approved') {
            $sql = "SELECT u.id, u.full_name, u.phone, {$em}, u.office_name, u.office_address, u.office_license_no,
                           u.office_photo_url, {$pp}, {$ov}, {$mkt}, u.created_at
                    FROM users u
                    WHERE u.role = 'office' AND u.office_approved = 1 AND u.is_active = 1
                    ORDER BY {$orderApproved}
                    LIMIT 200";
            try {
                $stmt = $pdo->query($sql);
            } catch (Throwable $e) {
                $stmt = $pdo->query(
                    "SELECT u.id, u.full_name, u.phone, u.office_name, u.office_address, u.office_license_no,
                            u.office_photo_url, {$mkt}, u.created_at
                     FROM users u
                     WHERE u.role = 'office' AND u.office_approved = 1 AND u.is_active = 1
                     ORDER BY u.created_at DESC LIMIT 200"
                );
            }
        } else {
            $sql = "SELECT u.id, u.full_name, u.phone, {$em}, u.office_name, u.office_address, u.office_license_no,
                           u.office_photo_url, {$pp}, {$mkt}, u.created_at
                    FROM users u
                    WHERE u.role = 'office' AND u.office_approved = 0 AND u.is_active = 1
                    ORDER BY u.created_at DESC LIMIT 100";
            try {
                $stmt = $pdo->query($sql);
            } catch (Throwable $e) {
                $stmt = $pdo->query(
                    "SELECT u.id, u.full_name, u.phone, u.office_name, u.office_address, u.office_license_no,
                            u.office_photo_url, {$mkt}, u.created_at
                     FROM users u
                     WHERE u.role = 'office' AND u.office_approved = 0 AND u.is_active = 1
                     ORDER BY u.created_at DESC LIMIT 100"
                );
            }
        }
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $uid = trim((string) ($in['user_id'] ?? ''));
        if ($uid === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $uid)) {
            json_error(400, 'user_id غير صالح');
        }
        $action = trim((string) ($in['action'] ?? 'approve'));
        if ($action === 'set_verified') {
            $ver = (int) ($in['verified'] ?? 0) === 1 ? 1 : 0;
            try {
                $stmt = $pdo->prepare(
                    'UPDATE users SET office_verified = :v WHERE id = :id AND role = \'office\' AND office_approved = 1 LIMIT 1'
                );
                $stmt->execute([':v' => $ver, ':id' => $uid]);
                echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
            } catch (Throwable $e) {
                json_error(400, 'عمود التوثيق غير مثبت — نفّذ patch_users_office_verified_mysql.sql');
            }

            return;
        }
        $stmt = $pdo->prepare(
            "UPDATE users SET office_approved = 1 WHERE id = :id AND role = 'office' LIMIT 1"
        );
        $stmt->execute([':id' => $uid]);
        echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    json_error(405, 'Method not allowed');
}

function admin_users_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        $q = trim((string) ($_GET['q'] ?? ''));
        $hasVerified = false;
        try {
            $chk = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_verified'"
            );
            $hasVerified = $chk !== false && (int) $chk->fetchColumn() > 0;
        } catch (Throwable $e) {
            $hasVerified = false;
        }
        $verCol = $hasVerified ? 'u.office_verified' : '0 AS office_verified';
        $permCol = vewo_users_has_staff_permissions_column($pdo)
            ? 'u.staff_permissions_json'
            : 'NULL AS staff_permissions_json';
        $emailCol = vewo_users_has_email_column($pdo) ? 'u.email' : "'' AS email";
        $ppCol = vewo_users_has_profile_photo_column($pdo) ? 'u.profile_photo_url' : 'NULL AS profile_photo_url';
        $mktCol = vewo_users_has_is_marketer_column($pdo) ? 'u.is_marketer' : '0 AS is_marketer';
        if ($q === '') {
            $stmt = $pdo->query(
                "SELECT u.id, u.full_name, u.office_name, u.phone, {$emailCol}, u.role, u.office_approved, u.is_active, u.created_at,
                        {$verCol}, {$permCol}, {$ppCol}, {$mktCol}
                 FROM users u
                 ORDER BY u.created_at DESC
                 LIMIT 500"
            );
        } else {
            $like = '%' . $q . '%';
            $exactUuid = preg_match('/^[0-9a-fA-F-]{36}$/', $q) === 1 ? $q : null;
            $sql = "SELECT u.id, u.full_name, u.office_name, u.phone, {$emailCol}, u.role, u.office_approved, u.is_active, u.created_at,
                           {$verCol}, {$permCol}, {$ppCol}, {$mktCol}
                    FROM users u
                    WHERE u.phone LIKE :q OR u.full_name LIKE :q2 OR u.office_name LIKE :q3";
            if (vewo_users_has_email_column($pdo)) {
                $sql .= ' OR u.email LIKE :q4';
            }
            if ($exactUuid !== null) {
                $sql .= ' OR u.id = :idex';
            }
            $sql .= ' ORDER BY u.created_at DESC LIMIT 500';
            $stmt = $pdo->prepare($sql);
            $stmt->bindValue(':q', $like, PDO::PARAM_STR);
            $stmt->bindValue(':q2', $like, PDO::PARAM_STR);
            $stmt->bindValue(':q3', $like, PDO::PARAM_STR);
            if (vewo_users_has_email_column($pdo)) {
                $stmt->bindValue(':q4', $like, PDO::PARAM_STR);
            }
            if ($exactUuid !== null) {
                $stmt->bindValue(':idex', $exactUuid, PDO::PARAM_STR);
            }
            $stmt->execute();
        }
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST') {
        $admin = require_admin_from_bearer($pdo);
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? ''));

        if ($action === 'create_customer' || $action === 'create_office') {
            if (($admin['role'] ?? '') !== 'admin') {
                json_error(403, 'إنشاء حسابات المستخدمين متاح للمسؤول الرئيسي فقط');
            }
            $fullName = trim((string) ($in['full_name'] ?? ''));
            $phone = trim((string) ($in['phone'] ?? ''));
            $email = trim(strtolower((string) ($in['email'] ?? '')));
            $password = (string) ($in['password'] ?? '');
            $officeName = trim((string) ($in['office_name'] ?? ''));
            if ($fullName === '' || mb_strlen($fullName) < 3) {
                json_error(400, 'الاسم غير صالح');
            }
            if (!preg_match('/^07[0-9]{9}$/', $phone)) {
                json_error(400, 'رقم الهاتف غير صالح');
            }
            if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                json_error(400, 'البريد الإلكتروني غير صالح');
            }
            if (strlen($password) < 4) {
                json_error(400, 'كلمة المرور قصيرة جداً');
            }
            if ($action === 'create_office' && mb_strlen($officeName) < 2) {
                json_error(400, 'اسم المكتب مطلوب');
            }
            $role = $action === 'create_office' ? 'office' : 'customer';
            $id = uuid_v4();
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $pdo->prepare(
                'INSERT INTO users (id, full_name, office_name, phone, email, password_hash, role, office_approved, is_active, created_by, created_at)
                 VALUES (:id, :fn, :on, :ph, :email, :pw, :rl, :oa, 1, :cb, NOW(3))'
            );
            $stmt->execute([
                ':id' => $id,
                ':fn' => $fullName,
                ':on' => $role === 'office' ? $officeName : null,
                ':ph' => $phone,
                ':email' => $email !== '' ? $email : null,
                ':pw' => $hash,
                ':rl' => $role,
                ':oa' => $role === 'office' ? 1 : 0,
                ':cb' => $admin['id'],
            ]);
            if ($action === 'create_office' && vewo_users_has_is_marketer_column($pdo)
                && (int) ($in['is_marketer'] ?? 0) === 1) {
                try {
                    $pdo->prepare('UPDATE users SET is_marketer = 1 WHERE id = :id LIMIT 1')->execute([':id' => $id]);
                } catch (Throwable $e) {
                }
            }
            echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);

            return;
        }

        if ($action === 'create_staff') {
            if (($admin['role'] ?? '') !== 'admin') {
                json_error(403, 'إنشاء موظفين متاح للمسؤول الرئيسي فقط');
            }
            $fullName = trim((string) ($in['full_name'] ?? ''));
            $phone = trim((string) ($in['phone'] ?? ''));
            $email = trim(strtolower((string) ($in['email'] ?? '')));
            $password = (string) ($in['password'] ?? '');
            $permissionsJson = vewo_normalize_staff_permissions($in['permissions'] ?? []);
            if ($fullName === '' || mb_strlen($fullName) < 3) {
                json_error(400, 'اسم الموظف غير صالح');
            }
            if (!preg_match('/^07[0-9]{9}$/', $phone)) {
                json_error(400, 'رقم الهاتف غير صالح');
            }
            if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                json_error(400, 'البريد الإلكتروني غير صالح');
            }
            if (strlen($password) < 4) {
                json_error(400, 'كلمة المرور قصيرة جداً');
            }
            $id = uuid_v4();
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $params = [
                ':id' => $id,
                ':fn' => $fullName,
                ':ph' => $phone,
                ':pw' => $hash,
                ':cb' => $admin['id'],
            ];
            if (vewo_users_has_staff_permissions_column($pdo)) {
                $stmt = $pdo->prepare(
                    'INSERT INTO users (id, full_name, phone, email, password_hash, role, office_approved, is_active, created_by, staff_permissions_json, created_at)
                     VALUES (:id, :fn, :ph, :email, :pw, \'staff\', 0, 1, :cb, :perm, NOW(3))'
                );
                $params[':perm'] = $permissionsJson;
            } else {
                $stmt = $pdo->prepare(
                    'INSERT INTO users (id, full_name, phone, email, password_hash, role, office_approved, is_active, created_by, created_at)
                     VALUES (:id, :fn, :ph, :email, :pw, \'staff\', 0, 1, :cb, NOW(3))'
                );
            }
            $params[':email'] = $email !== '' ? $email : null;
            $stmt->execute($params);
            echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);

            return;
        }

        if ($action === 'create_admin') {
            if (($admin['role'] ?? '') !== 'admin') {
                json_error(403, 'إنشاء مسؤولين فرعيين متاح للمسؤول الرئيسي فقط');
            }
            $fullName = trim((string) ($in['full_name'] ?? ''));
            $phone = trim((string) ($in['phone'] ?? ''));
            $email = trim(strtolower((string) ($in['email'] ?? '')));
            $password = (string) ($in['password'] ?? '');
            if ($fullName === '' || mb_strlen($fullName) < 3) {
                json_error(400, 'الاسم غير صالح');
            }
            if (!preg_match('/^07[0-9]{9}$/', $phone)) {
                json_error(400, 'رقم الهاتف غير صالح');
            }
            if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                json_error(400, 'البريد الإلكتروني غير صالح');
            }
            if (strlen($password) < 8) {
                json_error(400, 'كلمة المرور يجب ألا تقل عن 8 أحرف');
            }
            $id = uuid_v4();
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $pdo->prepare(
                'INSERT INTO users (id, full_name, phone, email, password_hash, role, office_approved, is_active, created_by, created_at)
                 VALUES (:id, :fn, :ph, :email, :pw, \'admin\', 0, 1, :cb, NOW(3))'
            );
            $stmt->execute([
                ':id' => $id,
                ':fn' => $fullName,
                ':ph' => $phone,
                ':email' => $email !== '' ? $email : null,
                ':pw' => $hash,
                ':cb' => $admin['id'],
            ]);
            echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);

            return;
        }

        if ($action === 'update_user') {
            if (($admin['role'] ?? '') !== 'admin' && ($admin['role'] ?? '') !== 'staff') {
                json_error(403, 'غير مسموح');
            }
            $targetId = trim((string) ($in['user_id'] ?? ''));
            if ($targetId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $targetId)) {
                json_error(400, 'user_id غير صالح');
            }
            $fullName = trim((string) ($in['full_name'] ?? ''));
            $officeName = trim((string) ($in['office_name'] ?? ''));
            $email = trim(strtolower((string) ($in['email'] ?? '')));
            $permissionsJson = vewo_normalize_staff_permissions($in['permissions'] ?? []);
            if ($fullName === '' || mb_strlen($fullName) < 2) {
                json_error(400, 'الاسم غير صالح');
            }
            if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
                json_error(400, 'البريد الإلكتروني غير صالح');
            }
            $roleStmt = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
            $roleStmt->execute([':id' => $targetId]);
            $tr = (string) ($roleStmt->fetchColumn() ?: '');
            if ($tr === 'office') {
                $stmt = $pdo->prepare(
                    'UPDATE users SET full_name = :fn, email = :email, office_name = :on WHERE id = :id LIMIT 1'
                );
                $stmt->execute([':fn' => $fullName, ':email' => $email !== '' ? $email : null, ':on' => $officeName, ':id' => $targetId]);
            } elseif ($tr === 'staff' && vewo_users_has_staff_permissions_column($pdo)) {
                $stmt = $pdo->prepare(
                    'UPDATE users SET full_name = :fn, email = :email, staff_permissions_json = :perm WHERE id = :id LIMIT 1'
                );
                $stmt->execute([':fn' => $fullName, ':email' => $email !== '' ? $email : null, ':perm' => $permissionsJson, ':id' => $targetId]);
            } else {
                $stmt = $pdo->prepare('UPDATE users SET full_name = :fn, email = :email WHERE id = :id LIMIT 1');
                $stmt->execute([':fn' => $fullName, ':email' => $email !== '' ? $email : null, ':id' => $targetId]);
            }
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }

        if ($action === 'reset_password') {
            if (($admin['role'] ?? '') !== 'admin') {
                json_error(403, 'تغيير كلمة المرور متاح للمسؤول الرئيسي فقط');
            }
            $targetId = trim((string) ($in['user_id'] ?? ''));
            $password = (string) ($in['password'] ?? '');
            if ($targetId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $targetId)) {
                json_error(400, 'user_id غير صالح');
            }
            if (strlen($password) < 4) {
                json_error(400, 'كلمة المرور قصيرة جداً');
            }
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $stmt = $pdo->prepare('UPDATE users SET password_hash = :pw WHERE id = :id LIMIT 1');
            $stmt->execute([':pw' => $hash, ':id' => $targetId]);
            $pdo->prepare('DELETE FROM user_session_tokens WHERE user_id = :u')->execute([':u' => $targetId]);
            $pdo->prepare('DELETE FROM admin_api_tokens WHERE user_id = :u')->execute([':u' => $targetId]);
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }

        if ($action === 'delete_user_permanent') {
            if (($admin['role'] ?? '') !== 'admin') {
                json_error(403, 'الحذف الجذري متاح للمسؤول الرئيسي فقط');
            }
            $pin = trim((string) ($in['pin'] ?? ''));
            if ($pin !== '1111') {
                json_error(403, 'رمز التأكيد غير صحيح');
            }
            $targetId = trim((string) ($in['user_id'] ?? ''));
            if ($targetId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $targetId)) {
                json_error(400, 'user_id غير صالح');
            }
            if ($targetId === (string) $admin['id']) {
                json_error(400, 'لا يمكن حذف حسابك الحالي');
            }
            try {
                vewo_admin_delete_user_cascade($pdo, $targetId);
                echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
            } catch (Throwable $e) {
                json_error(500, 'تعذر الحذف الجذري — تحقق من القيود أو السجلات المرتبطة');
            }

            return;
        }

        if ($action === 'delete_user') {
            if (($admin['role'] ?? '') !== 'admin') {
                json_error(403, 'تعطيل الحسابات متاح للمسؤول الرئيسي فقط');
            }
            $targetId = trim((string) ($in['user_id'] ?? ''));
            if ($targetId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $targetId)) {
                json_error(400, 'user_id غير صالح');
            }
            if ($targetId === (string) $admin['id']) {
                json_error(400, 'لا يمكنك تعطيل حسابك الحالي');
            }
            $roleStmt = $pdo->prepare('SELECT role FROM users WHERE id = :id LIMIT 1');
            $roleStmt->execute([':id' => $targetId]);
            $r = (string) ($roleStmt->fetchColumn() ?: '');
            if ($r === 'admin') {
                $cnt = (int) $pdo->query(
                    "SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1"
                )->fetchColumn();
                if ($cnt <= 1) {
                    json_error(400, 'لا يمكن تعطيل آخر مسؤول نشط');
                }
            }
            $pdo->prepare('DELETE FROM user_session_tokens WHERE user_id = :u')->execute([':u' => $targetId]);
            $pdo->prepare('DELETE FROM admin_api_tokens WHERE user_id = :u')->execute([':u' => $targetId]);
            $stmt = $pdo->prepare('UPDATE users SET is_active = 0 WHERE id = :id LIMIT 1');
            $stmt->execute([':id' => $targetId]);
            echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

            return;
        }

        $targetId = trim((string) ($in['user_id'] ?? ''));
        if ($targetId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $targetId)) {
            json_error(400, 'user_id غير صالح');
        }
        if ($targetId === (string) $admin['id']) {
            json_error(400, 'لا يمكنك تعديل حسابك الحالي بهذه الطريقة');
        }
        $active = (int) ($in['is_active'] ?? 0) === 1 ? 1 : 0;
        $stmt = $pdo->prepare('UPDATE users SET is_active = :a WHERE id = :id LIMIT 1');
        $stmt->execute([':a' => $active, ':id' => $targetId]);
        echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    json_error(405, 'Method not allowed');
}

function public_properties_list_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    // إن كان المستخدم مسجلاً يمكنه رؤية منشوراته غير المعتمدة (اختياري) عند الطلب.
    $me = vewo_try_session_user($pdo);
    $meId = $me ? (string) ($me['id'] ?? '') : '';
    $includeMine = (string) ($_GET['include_mine'] ?? $_GET['includeMine'] ?? '') === '1';
    $cat = trim((string) ($_GET['category'] ?? ''));
    $segment = trim((string) ($_GET['segment'] ?? ''));
    $qRaw = trim((string) ($_GET['q'] ?? $_GET['search'] ?? ''));
    $qNo = ltrim($qRaw, '#');
    $publicNoFilter = ($qNo !== '' && ctype_digit($qNo)) ? (int) $qNo : null;
    $limit = (int) ($_GET['limit'] ?? 120);
    $limit = max(1, min(300, $limit));
    $offset = (int) ($_GET['offset'] ?? 0);
    $offset = max(0, min(10000, $offset));

    $allowed = ['land', 'house', 'apartment', 'shop', 'compound', 'villa', ''];
    if ($cat !== '' && !in_array($cat, $allowed, true)) {
        json_error(400, 'فئة غير صالحة');
    }
    if ($segment !== '' && !in_array($segment, ['standard', 'parcel'], true)) {
        json_error(400, 'segment غير صالح');
    }

    $ownerId = trim((string) ($_GET['owner_id'] ?? ''));
    if ($ownerId !== '' && !preg_match('/^[0-9a-fA-F-]{36}$/', $ownerId)) {
        json_error(400, 'owner_id غير صالح');
    }
    $parcelId = trim((string) ($_GET['parcel_id'] ?? ''));
    if ($parcelId !== '' && !preg_match('/^[0-9a-fA-F-]{36}$/', $parcelId)) {
        json_error(400, 'parcel_id غير صالح');
    }
    $compoundId = trim((string) ($_GET['compound_id'] ?? ''));
    if ($compoundId !== '' && !preg_match('/^[0-9a-fA-F-]{36}$/', $compoundId)) {
        json_error(400, 'compound_id غير صالح');
    }
    $compoundNameFilter = '';
    if ($compoundId !== '') {
        try {
            $cnStmt = $pdo->prepare('SELECT compound_name FROM compounds WHERE id = :id LIMIT 1');
            $cnStmt->execute([':id' => $compoundId]);
            $compoundNameFilter = trim((string) ($cnStmt->fetchColumn() ?: ''));
        } catch (Throwable $e) {
            $compoundNameFilter = '';
        }
    }

    // هل لدينا عمود parcel_id؟ (بعض قواعد البيانات القديمة تخزّنه داخل details_json)
    $hasParcelCol = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id'"
        );
        $hasParcelCol = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasParcelCol = false;
    }

    $hasCompoundCol = false;
    try {
        $chkCompound = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'"
        );
        $hasCompoundCol = $chkCompound !== false && (int) $chkCompound->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasCompoundCol = false;
    }

    $hasOfficeVerifiedCol = false;
    try {
        $ovChk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_verified'"
        );
        $hasOfficeVerifiedCol = $ovChk !== false && (int) $ovChk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasOfficeVerifiedCol = false;
    }
    $ownerVerifiedExpr = $hasOfficeVerifiedCol
        ? 'COALESCE(ou.office_verified, 0) AS owner_office_verified'
        : '0 AS owner_office_verified';
    $ownerMarketerExpr = function_exists('vewo_users_has_is_marketer_column') && vewo_users_has_is_marketer_column($pdo)
        ? 'COALESCE(ou.is_marketer, 0) AS owner_is_marketer'
        : '0 AS owner_is_marketer';
    $ownerPhoneExpr = 'COALESCE(ou.phone, \'\') AS owner_phone';

    $hasPropPub = vewo_properties_has_public_no_column($pdo);
    $propPubExpr = $hasPropPub ? 'p.property_public_no' : 'NULL AS property_public_no';

    $listExtras = [];
    if ($hasParcelCol) {
        $listExtras[] = 'p.parcel_id';
    }
    if ($hasCompoundCol) {
        $listExtras[] = 'p.compound_id';
        $listExtras[] = "(SELECT c.compound_name FROM compounds c
            WHERE c.id = COALESCE(NULLIF(p.compound_id, ''), NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p.details_json, '$.compound_id')), ''))
            LIMIT 1) AS compound_name";
    } else {
        $listExtras[] = "(SELECT c.compound_name FROM compounds c
            WHERE c.id = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p.details_json, '$.compound_id')), '')
            LIMIT 1) AS compound_name";
    }
    if (function_exists('vewo_properties_has_synthetic_likes') && vewo_properties_has_synthetic_likes($pdo)) {
        $listExtras[] = 'COALESCE(p.synthetic_likes, 0) AS synthetic_likes';
    }
    $extraListSql = $listExtras === [] ? '' : ', ' . implode(', ', $listExtras);

    $where = "p.approval_status = 'approved'";
    if ($includeMine && $meId !== '') {
        // نُبقي العام معتمد فقط، ونضيف كل منشورات المستخدم نفسه بكل الحالات لصفحة الحساب.
        $where = "(p.approval_status = 'approved' OR p.owner_user_id = :me)";
    }

    $sql = 'SELECT p.id, ' . $propPubExpr . ', p.owner_user_id, p.title, p.governorate, p.address_line, p.category, p.segment,
            p.purpose, p.price_iqd, p.area_sqm, p.description, p.details_json, p.views, p.approval_status,
            p.is_sold, p.sold_at, p.created_at' . $extraListSql . ',
            ou.role AS owner_role,
            ou.full_name AS owner_full_name,
            ' . $ownerPhoneExpr . ',
            NULLIF(TRIM(ou.office_name), \'\') AS owner_office_name,
            ' . $ownerVerifiedExpr . ',
            ' . $ownerMarketerExpr . ',
            (SELECT m.public_url FROM property_media m WHERE m.property_id = p.id AND m.media_type = \'image\'
             ORDER BY m.created_at ASC LIMIT 1) AS thumb_url,
            (SELECT mv.public_url FROM property_media mv WHERE mv.property_id = p.id AND mv.media_type = \'video\'
             ORDER BY mv.created_at ASC LIMIT 1) AS video_url
            FROM properties p
            INNER JOIN users ou ON ou.id = p.owner_user_id
            WHERE ' . $where;
    if ($cat !== '') {
        $sql .= ' AND p.category = :cat';
    }
    if ($segment !== '') {
        $sql .= ' AND p.segment = :seg';
    }
    if ($qRaw !== '') {
        if ($publicNoFilter !== null && $hasPropPub) {
            $sql .= ' AND p.property_public_no = :pubq';
        } else {
            $sql .= ' AND (p.title LIKE :q OR p.address_line LIKE :q OR p.governorate LIKE :q)';
        }
    }
    if ($ownerId !== '') {
        $sql .= ' AND p.owner_user_id = :ow';
    }
    if ($parcelId !== '') {
        if ($hasParcelCol) {
            // عمود parcel_id أو احتياطاً JSON (منشورات قديمة / إدراج بدون عمود)
            $sql .= ' AND (p.parcel_id = :pid OR IFNULL(JSON_UNQUOTE(JSON_EXTRACT(p.details_json, \'$.parcel_id\')), \'\') = :pid2)';
        } else {
            // fallback: parcel_id مخزّن داخل details_json
            $sql .= " AND JSON_UNQUOTE(JSON_EXTRACT(p.details_json, '$.parcel_id')) = :pid";
        }
    }
    if ($compoundId !== '') {
        if ($hasCompoundCol) {
            $sql .= ' AND (p.compound_id = :cid OR IFNULL(JSON_UNQUOTE(JSON_EXTRACT(p.details_json, \'$.compound_id\')), \'\') = :cid2';
        } else {
            $sql .= " AND (JSON_UNQUOTE(JSON_EXTRACT(p.details_json, '$.compound_id')) = :cid";
        }
        if ($compoundNameFilter !== '') {
            $sql .= " OR JSON_UNQUOTE(JSON_EXTRACT(p.details_json, '$.compound_name')) LIKE :cname
                OR p.title LIKE :cname2 OR p.address_line LIKE :cname3";
        }
        $sql .= ')';
    }
    // غير المباع أولاً دائماً (تم البيع في النهاية)
    $sql .= ' ORDER BY COALESCE(p.is_sold, 0) ASC, p.created_at DESC LIMIT :lim OFFSET :off';

    $stmt = $pdo->prepare($sql);
    if ($includeMine && $meId !== '') {
        $stmt->bindValue(':me', $meId, PDO::PARAM_STR);
    }
    if ($cat !== '') {
        $stmt->bindValue(':cat', $cat, PDO::PARAM_STR);
    }
    if ($segment !== '') {
        $stmt->bindValue(':seg', $segment, PDO::PARAM_STR);
    }
    if ($qRaw !== '') {
        if ($publicNoFilter !== null && $hasPropPub) {
            $stmt->bindValue(':pubq', $publicNoFilter, PDO::PARAM_INT);
        } else {
            $stmt->bindValue(':q', '%' . $qRaw . '%', PDO::PARAM_STR);
        }
    }
    if ($ownerId !== '') {
        $stmt->bindValue(':ow', $ownerId, PDO::PARAM_STR);
    }
    if ($parcelId !== '') {
        $stmt->bindValue(':pid', $parcelId, PDO::PARAM_STR);
        if ($hasParcelCol) {
            $stmt->bindValue(':pid2', $parcelId, PDO::PARAM_STR);
        }
    }
    if ($compoundId !== '') {
        $stmt->bindValue(':cid', $compoundId, PDO::PARAM_STR);
        if ($hasCompoundCol) {
            $stmt->bindValue(':cid2', $compoundId, PDO::PARAM_STR);
        }
        if ($compoundNameFilter !== '') {
            $likeCompoundName = '%' . $compoundNameFilter . '%';
            $stmt->bindValue(':cname', $likeCompoundName, PDO::PARAM_STR);
            $stmt->bindValue(':cname2', $likeCompoundName, PDO::PARAM_STR);
            $stmt->bindValue(':cname3', $likeCompoundName, PDO::PARAM_STR);
        }
    }
    $stmt->bindValue(':lim', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':off', $offset, PDO::PARAM_INT);
    $stmt->execute();
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    vewo_attach_image_urls_to_property_rows($pdo, $rows);

    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}

/**
 * يُرفق مصفوفة image_urls لكل صف عقار (لتعدد الصور في التطبيق).
 *
 * @param list<array<string,mixed>> $rows
 */
function vewo_attach_image_urls_to_property_rows(PDO $pdo, array &$rows): void
{
    if ($rows === []) {
        return;
    }
    $ids = [];
    foreach ($rows as $r) {
        $id = trim((string) ($r['id'] ?? ''));
        if ($id !== '' && preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            $ids[] = $id;
        }
    }
    if ($ids === []) {
        return;
    }
    $byId = [];
    try {
        $placeholders = implode(',', array_fill(0, count($ids), '?'));
        $mst = $pdo->prepare(
            "SELECT property_id, public_url FROM property_media
             WHERE media_type = 'image' AND property_id IN ($placeholders)
             ORDER BY created_at ASC"
        );
        $mst->execute($ids);
        while ($mr = $mst->fetch(PDO::FETCH_ASSOC)) {
            $pid = (string) ($mr['property_id'] ?? '');
            $u = trim((string) ($mr['public_url'] ?? ''));
            if ($pid === '' || $u === '') {
                continue;
            }
            if (!isset($byId[$pid])) {
                $byId[$pid] = [];
            }
            $byId[$pid][] = $u;
        }
    } catch (Throwable $e) {
        return;
    }
    foreach ($rows as &$r) {
        $pid = trim((string) ($r['id'] ?? ''));
        $urls = $byId[$pid] ?? [];
        if ($urls === []) {
            $thumb = trim((string) ($r['thumb_url'] ?? ''));
            if ($thumb !== '') {
                $urls = [$thumb];
            }
        }
        $r['image_urls'] = $urls;
        $r['images'] = $urls;
    }
    unset($r);
}

function public_parcels_list_route(PDO $pdo): void
{
    // إن وُجد عمود parcel_id في properties سنُظهر عدد منشورات المقاطعة (المعتمدة فقط).
    $hasParcelCol = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id'"
        );
        $hasParcelCol = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasParcelCol = false;
    }
    $useDistJoin = vewo_parcels_has_district_id_column($pdo) && vewo_districts_table_exists($pdo);
    // عدّ المنشورات المرتبطة بالمقاطعة (معتمد أو قيد المراجعة — يظهر للجمهور ضمن «المحتوى الوارد»).
    $fcExpr = 'COALESCE(pa.follower_count,0) + COALESCE(pa.synthetic_follower_boost,0) AS follower_count';
    $countExpr = $hasParcelCol
        ? "(SELECT COUNT(*) FROM properties pr WHERE pr.parcel_id = pa.id AND pr.approval_status = 'approved') AS posts_count"
        : "0 AS posts_count";
    $distCols = $useDistJoin ? 'pa.district_id, d.name AS district_name, ' : '';
    $join = $useDistJoin ? ' LEFT JOIN districts d ON d.id = pa.district_id ' : ' ';
    $districtMirrorFilter = $useDistJoin
        ? " AND NOT (pa.district_id = pa.id AND COALESCE(pa.parcel_no, '') = '')"
        : '';
    try {
        $stmt = $pdo->query(
            "SELECT pa.id, pa.governorate, pa.parcel_name, pa.parcel_no, {$distCols}{$fcExpr}, {$countExpr}
             FROM parcels pa{$join}
             WHERE pa.is_active = 1{$districtMirrorFilter}
             ORDER BY pa.sort_order ASC, pa.parcel_name ASC
             LIMIT 500"
        );
    } catch (Throwable $e) {
        $stmt = $pdo->query(
            "SELECT pa.id, pa.governorate, pa.parcel_name, pa.parcel_no, {$countExpr}
             FROM parcels pa
             WHERE pa.is_active = 1
             ORDER BY pa.sort_order ASC, pa.parcel_name ASC
             LIMIT 500"
        );
    }
    $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}

function public_compounds_list_route(PDO $pdo): void
{
    $hasCompoundCol = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'"
        );
        $hasCompoundCol = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasCompoundCol = false;
    }
    $hasCompoundsTable = false;
    try {
        $t = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = 'compounds'"
        );
        $hasCompoundsTable = $t !== false && (int) $t->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasCompoundsTable = false;
    }
    if (!$hasCompoundsTable) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);

        return;
    }
    $fcExpr = 'COALESCE(c.follower_count,0) + COALESCE(c.synthetic_follower_boost,0) AS follower_count';
    $useDistJoin = false;
    try {
        $chkDid = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'district_id'"
        );
        $useDistJoin = $chkDid !== false && (int) $chkDid->fetchColumn() > 0
            && function_exists('vewo_districts_table_exists') && vewo_districts_table_exists($pdo);
    } catch (Throwable $e) {
    }
    $distCols = $useDistJoin
        ? 'c.district_id, COALESCE(d.name, c.district_name) AS district_name, '
        : 'c.district_name, ';
    $distJoin = $useDistJoin ? ' LEFT JOIN districts d ON d.id = c.district_id ' : '';
    $countExpr = $hasCompoundCol
        ? "(SELECT COUNT(*) FROM properties pr
            WHERE pr.approval_status = 'approved'
              AND (
                pr.compound_id = c.id
                OR IFNULL(JSON_UNQUOTE(JSON_EXTRACT(pr.details_json, '$.compound_id')), '') = c.id
                OR JSON_UNQUOTE(JSON_EXTRACT(pr.details_json, '$.compound_name')) LIKE CONCAT('%', c.compound_name, '%')
                OR pr.title LIKE CONCAT('%', c.compound_name, '%')
                OR pr.address_line LIKE CONCAT('%', c.compound_name, '%')
              )) AS posts_count"
        : "(SELECT COUNT(*) FROM properties pr
            WHERE pr.approval_status = 'approved'
              AND (
                IFNULL(JSON_UNQUOTE(JSON_EXTRACT(pr.details_json, '$.compound_id')), '') = c.id
                OR JSON_UNQUOTE(JSON_EXTRACT(pr.details_json, '$.compound_name')) LIKE CONCAT('%', c.compound_name, '%')
                OR pr.title LIKE CONCAT('%', c.compound_name, '%')
                OR pr.address_line LIKE CONCAT('%', c.compound_name, '%')
              )) AS posts_count";
    try {
        $stmt = $pdo->query(
            "SELECT c.id, c.governorate, c.compound_name, c.photo_url, {$distCols}{$fcExpr}, {$countExpr}
             FROM compounds c{$distJoin}
             WHERE c.is_active = 1
             ORDER BY c.sort_order ASC, c.compound_name ASC
             LIMIT 500"
        );
    } catch (Throwable $e) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);

        return;
    }
    $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}

function admin_compounds_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $hasCompoundsTable = false;
    try {
        $t = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = 'compounds'"
        );
        $hasCompoundsTable = $t !== false && (int) $t->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasCompoundsTable = false;
    }
    if (!$hasCompoundsTable) {
        json_error(503, 'جدول المجمعات غير مُثبّت — نفّذ patch_compounds_mysql.sql');
    }
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        $hasCompoundCol = false;
        try {
            $chk = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'"
            );
            $hasCompoundCol = $chk !== false && (int) $chk->fetchColumn() > 0;
        } catch (Throwable $e) {
            $hasCompoundCol = false;
        }
        $countExpr = $hasCompoundCol
            ? '(SELECT COUNT(*) FROM properties pr WHERE pr.compound_id = c.id) AS property_count'
            : '0 AS property_count';
        $distAdmin = '';
        try {
            $chkD = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'district_name'"
            );
            if ($chkD !== false && (int) $chkD->fetchColumn() > 0) {
                $distAdmin = 'c.district_id, c.district_name, COALESCE(c.follower_count,0) AS follower_count,
                    COALESCE(c.synthetic_follower_boost,0) AS synthetic_follower_boost,';
            }
        } catch (Throwable $e) {
        }
        $stmt = $pdo->query(
            "SELECT c.id, c.governorate, c.compound_name, c.photo_url, {$distAdmin} c.sort_order, c.is_active, c.created_at,
                    {$countExpr}
             FROM compounds c
             ORDER BY c.sort_order ASC, c.created_at DESC
             LIMIT 1000"
        );
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? ''));
        if ($action !== 'upsert') {
            json_error(400, 'action غير صالح');
        }
        $id = trim((string) ($in['id'] ?? ''));
        $gov = trim((string) ($in['governorate'] ?? ''));
        $name = trim((string) ($in['compound_name'] ?? ''));
        $photo = trim((string) ($in['photo_url'] ?? ''));
        $districtId = trim((string) ($in['district_id'] ?? ''));
        $districtName = trim((string) ($in['district_name'] ?? ''));
        $sort = (int) ($in['sort_order'] ?? 0);
        $active = (int) ($in['is_active'] ?? 1) === 1 ? 1 : 0;
        $hasDistCols = false;
        try {
            $chkD = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'compounds' AND column_name = 'district_id'"
            );
            $hasDistCols = $chkD !== false && (int) $chkD->fetchColumn() > 0;
        } catch (Throwable $e) {
        }
        if ($gov === '' || mb_strlen($gov) < 2) {
            json_error(400, 'المحافظة مطلوبة');
        }
        if ($name === '' || mb_strlen($name) < 2) {
            json_error(400, 'اسم المجمع مطلوب');
        }
        if ($photo !== '' && strlen($photo) > 1000) {
            json_error(400, 'رابط الصورة طويل جداً');
        }
        if ($hasDistCols && $districtId !== '' && preg_match('/^[0-9a-fA-F-]{36}$/', $districtId)) {
            try {
                $dnStmt = $pdo->prepare('SELECT name FROM districts WHERE id = :id LIMIT 1');
                $dnStmt->execute([':id' => $districtId]);
                $dnRow = $dnStmt->fetch(PDO::FETCH_ASSOC);
                if (is_array($dnRow) && trim((string) ($dnRow['name'] ?? '')) !== '') {
                    $districtName = trim((string) $dnRow['name']);
                }
            } catch (Throwable $e) {
            }
        }
        if ($id === '') {
            $id = uuid_v4();
            if ($hasDistCols) {
                $stmt = $pdo->prepare(
                    'INSERT INTO compounds (id, governorate, district_id, district_name, compound_name, photo_url, sort_order, is_active, created_at)
                     VALUES (:id, :g, :did, :dn, :n, :ph, :s, :a, NOW(3))'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':did' => $districtId !== '' ? $districtId : null,
                    ':dn' => $districtName,
                    ':n' => $name,
                    ':ph' => $photo,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            } else {
                $stmt = $pdo->prepare(
                    'INSERT INTO compounds (id, governorate, compound_name, photo_url, sort_order, is_active, created_at)
                     VALUES (:id, :g, :n, :ph, :s, :a, NOW(3))'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':n' => $name,
                    ':ph' => $photo,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            }
        } else {
            if (!preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
                json_error(400, 'id غير صالح');
            }
            if ($hasDistCols) {
                $stmt = $pdo->prepare(
                    'UPDATE compounds SET governorate = :g, district_id = :did, district_name = :dn,
                     compound_name = :n, photo_url = :ph, sort_order = :s, is_active = :a WHERE id = :id LIMIT 1'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':did' => $districtId !== '' ? $districtId : null,
                    ':dn' => $districtName,
                    ':n' => $name,
                    ':ph' => $photo,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            } else {
                $stmt = $pdo->prepare(
                    'UPDATE compounds SET governorate = :g, compound_name = :n, photo_url = :ph,
                     sort_order = :s, is_active = :a WHERE id = :id LIMIT 1'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':n' => $name,
                    ':ph' => $photo,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            }
        }
        echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'DELETE') {
        require_admin_from_bearer($pdo);
        $id = trim((string) ($_GET['id'] ?? ''));
        if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            json_error(400, 'id غير صالح');
        }
        try {
            $chk = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'"
            );
            if ($chk !== false && (int) $chk->fetchColumn() > 0) {
                $countStmt = $pdo->prepare('SELECT COUNT(*) FROM properties WHERE compound_id = :id');
                $countStmt->execute([':id' => $id]);
                if ((int) $countStmt->fetchColumn() > 0) {
                    json_error(400, 'لا يمكن حذف مجمع يحتوي منشورات');
                }
            }
        } catch (Throwable $e) {
            json_error(500, 'تعذر التحقق من المنشورات المرتبطة بالمجمع');
        }
        $stmt = $pdo->prepare('DELETE FROM compounds WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    json_error(405, 'Method not allowed');
}

function admin_parcels_route(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        require_admin_from_bearer($pdo);
        $hasParcelCol = false;
        try {
            $chk = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id'"
            );
            $hasParcelCol = $chk !== false && (int) $chk->fetchColumn() > 0;
        } catch (Throwable $e) {
            $hasParcelCol = false;
        }
        $countExpr = $hasParcelCol
            ? '(SELECT COUNT(*) FROM properties pr WHERE pr.parcel_id = pa.id) AS property_count'
            : '0 AS property_count';
        $useDistJoin = vewo_parcels_has_district_id_column($pdo) && vewo_districts_table_exists($pdo);
        $distCols = $useDistJoin ? 'pa.district_id, d.name AS district_name, ' : '';
        $join = $useDistJoin ? ' LEFT JOIN districts d ON d.id = pa.district_id ' : ' ';
        try {
            $stmt = $pdo->query(
                "SELECT pa.id, pa.governorate, pa.parcel_name, pa.parcel_no, pa.sort_order, pa.is_active, pa.created_at,
                        {$distCols}{$countExpr}
                 FROM parcels pa{$join}
                 ORDER BY pa.sort_order ASC, pa.created_at DESC
                 LIMIT 1000"
            );
        } catch (Throwable $e) {
            $stmt = $pdo->query(
                "SELECT pa.id, pa.governorate, pa.parcel_name, pa.parcel_no, pa.sort_order, pa.is_active, pa.created_at,
                        {$countExpr}
                 FROM parcels pa
                 ORDER BY pa.sort_order ASC, pa.created_at DESC
                 LIMIT 1000"
            );
        }
        $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
        echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'POST') {
        require_admin_from_bearer($pdo);
        $in = read_json_body();
        $action = trim((string) ($in['action'] ?? ''));
        if ($action !== 'upsert') {
            json_error(400, 'action غير صالح');
        }
        $id = trim((string) ($in['id'] ?? ''));
        $gov = trim((string) ($in['governorate'] ?? ''));
        $name = trim((string) ($in['parcel_name'] ?? ''));
        $no = trim((string) ($in['parcel_no'] ?? ''));
        $sort = (int) ($in['sort_order'] ?? 0);
        $active = (int) ($in['is_active'] ?? 1) === 1 ? 1 : 0;
        $districtId = trim((string) ($in['district_id'] ?? ''));
        $hasDistCol = vewo_parcels_has_district_id_column($pdo) && vewo_districts_table_exists($pdo);
        if ($hasDistCol) {
            if ($districtId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $districtId)) {
                json_error(400, 'اختر القضاء أو الناحية');
            }
            try {
                $ds = $pdo->prepare(
                    'SELECT g.name AS governorate_name
                     FROM districts d
                     INNER JOIN governorates g ON g.id = d.governorate_id
                     WHERE d.id = :id AND d.is_active = 1 LIMIT 1'
                );
                $ds->execute([':id' => $districtId]);
                $drow = $ds->fetch(PDO::FETCH_ASSOC);
                if (!is_array($drow) || trim((string) ($drow['governorate_name'] ?? '')) === '') {
                    json_error(400, 'القضاء أو الناحية غير صالحة');
                }
                $gov = trim((string) $drow['governorate_name']);
            } catch (Throwable $e) {
                json_error(500, 'تعذر التحقق من القضاء/الناحية');
            }
        }
        if ($gov === '' || mb_strlen($gov) < 2) {
            json_error(400, 'المحافظة مطلوبة');
        }
        if ($name === '' || mb_strlen($name) < 2) {
            json_error(400, 'اسم المقاطعة مطلوب');
        }
        if ($id === '') {
            $id = uuid_v4();
            if ($hasDistCol) {
                $stmt = $pdo->prepare(
                    'INSERT INTO parcels (id, governorate, district_id, parcel_name, parcel_no, sort_order, is_active, created_at)
                     VALUES (:id, :g, :did, :n, :no, :s, :a, NOW(3))'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':did' => $districtId,
                    ':n' => $name,
                    ':no' => $no,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            } else {
                $stmt = $pdo->prepare(
                    'INSERT INTO parcels (id, governorate, parcel_name, parcel_no, sort_order, is_active, created_at)
                     VALUES (:id, :g, :n, :no, :s, :a, NOW(3))'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':n' => $name,
                    ':no' => $no,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            }
        } else {
            if (!preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
                json_error(400, 'id غير صالح');
            }
            if ($hasDistCol) {
                $stmt = $pdo->prepare(
                    'UPDATE parcels SET governorate = :g, district_id = :did, parcel_name = :n, parcel_no = :no,
                     sort_order = :s, is_active = :a WHERE id = :id LIMIT 1'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':did' => $districtId,
                    ':n' => $name,
                    ':no' => $no,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            } else {
                $stmt = $pdo->prepare(
                    'UPDATE parcels SET governorate = :g, parcel_name = :n, parcel_no = :no,
                     sort_order = :s, is_active = :a WHERE id = :id LIMIT 1'
                );
                $stmt->execute([
                    ':id' => $id,
                    ':g' => $gov,
                    ':n' => $name,
                    ':no' => $no,
                    ':s' => $sort,
                    ':a' => $active,
                ]);
            }
        }
        echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'DELETE') {
        require_admin_from_bearer($pdo);
        $id = trim((string) ($_GET['id'] ?? ''));
        if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            json_error(400, 'id غير صالح');
        }
        try {
            $chk = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id'"
            );
            if ($chk !== false && (int) $chk->fetchColumn() > 0) {
                $countStmt = $pdo->prepare('SELECT COUNT(*) FROM properties WHERE parcel_id = :id');
                $countStmt->execute([':id' => $id]);
                if ((int) $countStmt->fetchColumn() > 0) {
                    json_error(400, 'لا يمكن حذف مقاطعة تحتوي منشورات');
                }
            }
        } catch (Throwable $e) {
            json_error(500, 'تعذر التحقق من المنشورات المرتبطة بالمقاطعة');
        }
        $stmt = $pdo->prepare('DELETE FROM parcels WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $id]);
        echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    json_error(405, 'Method not allowed');
}

function public_properties_get_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        json_error(405, 'Method not allowed');
    }
    $id = trim((string) ($_GET['id'] ?? ''));
    if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'id مطلوب');
    }
    $hasOfficeVerifiedCol = false;
    try {
        $ovChk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_verified'"
        );
        $hasOfficeVerifiedCol = $ovChk !== false && (int) $ovChk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasOfficeVerifiedCol = false;
    }
    $ownerVerifiedExpr = $hasOfficeVerifiedCol
        ? 'COALESCE(ou.office_verified, 0) AS owner_office_verified'
        : '0 AS owner_office_verified';
    $hasPropPub = vewo_properties_has_public_no_column($pdo);
    $propPubExpr = $hasPropPub ? 'p.property_public_no' : 'NULL AS property_public_no';
    $hasParcelCol = false;
    $hasCompoundCol = false;
    try {
        $pc = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id'"
        );
        $hasParcelCol = $pc !== false && (int) $pc->fetchColumn() > 0;
    } catch (Throwable $e) {
    }
    try {
        $cc = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'"
        );
        $hasCompoundCol = $cc !== false && (int) $cc->fetchColumn() > 0;
    } catch (Throwable $e) {
    }
    $idCols = '';
    if ($hasParcelCol) {
        $idCols .= ', p.parcel_id';
    }
    if ($hasCompoundCol) {
        $idCols .= ', p.compound_id';
        $idCols .= ", (SELECT c.compound_name FROM compounds c
            WHERE c.id = COALESCE(NULLIF(p.compound_id, ''), NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p.details_json, '$.compound_id')), ''))
            LIMIT 1) AS compound_name";
    } else {
        $idCols .= ", (SELECT c.compound_name FROM compounds c
            WHERE c.id = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(p.details_json, '$.compound_id')), '')
            LIMIT 1) AS compound_name";
    }
    $stmt = $pdo->prepare(
        'SELECT p.id, ' . $propPubExpr . ', p.owner_user_id, p.title, p.governorate, p.address_line, p.category, p.segment, p.purpose,
                p.price_iqd, p.area_sqm, p.description, p.details_json, p.views, p.approval_status, p.is_sold, p.sold_at,
                p.created_at' . $idCols . ',
                ou.role AS owner_role,
                ou.full_name AS owner_full_name,
                COALESCE(ou.phone, \'\') AS owner_phone,
                NULLIF(TRIM(ou.office_name), \'\') AS owner_office_name,
                ' . $ownerVerifiedExpr . ',
                (SELECT mv.public_url FROM property_media mv WHERE mv.property_id = p.id AND mv.media_type = \'video\'
                 ORDER BY mv.created_at ASC LIMIT 1) AS video_url
         FROM properties p
         INNER JOIN users ou ON ou.id = p.owner_user_id
         WHERE p.id = :id LIMIT 1'
    );
    $stmt->execute([':id' => $id]);
    $prop = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($prop)) {
        json_error(404, 'العقار غير موجود');
    }
    if (($prop['approval_status'] ?? '') !== 'approved') {
        json_error(404, 'العقار غير متاح');
    }

    $m = $pdo->prepare(
        "SELECT public_url FROM property_media WHERE property_id = :id AND media_type = 'image' ORDER BY created_at ASC"
    );
    $m->execute([':id' => $id]);
    $images = array_column($m->fetchAll(PDO::FETCH_ASSOC), 'public_url');
    $v = $pdo->prepare(
        "SELECT public_url FROM property_media WHERE property_id = :id AND media_type = 'video' ORDER BY created_at ASC LIMIT 1"
    );
    $v->execute([':id' => $id]);
    $videoUrl = (string) ($v->fetchColumn() ?: '');
    if ($videoUrl !== '') {
        $prop['video_url'] = $videoUrl;
    }

    echo json_encode([
        'ok' => true,
        'property' => $prop,
        'images' => $images,
        'video_url' => $videoUrl,
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * تعليم عقار كمباع (صاحب المنشور، مكتب، أو فريق الأدمن).
 */
function properties_mark_sold_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $in = read_json_body();
    $id = trim((string) ($in['property_id'] ?? $in['id'] ?? ''));
    if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'معرّف العقار غير صالح');
    }
    $isSold = (int) ($in['is_sold'] ?? 1) === 1;

    $pStmt = $pdo->prepare('SELECT owner_user_id, approval_status FROM properties WHERE id = :id LIMIT 1');
    $pStmt->execute([':id' => $id]);
    $row = $pStmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row)) {
        json_error(404, 'العقار غير موجود');
    }
    $ownerId = (string) ($row['owner_user_id'] ?? '');
    if (($row['approval_status'] ?? '') !== 'approved') {
        json_error(400, 'لا يمكن تعليم هذا المنشور قبل الموافقة عليه');
    }

    $sessionUser = vewo_try_session_user($pdo);
    $adminUser = vewo_try_admin_staff_user($pdo);
    $allowed = false;
    if ($sessionUser !== null && (string) ($sessionUser['id'] ?? '') === $ownerId) {
        $allowed = true;
    }
    if ($adminUser !== null) {
        $allowed = true;
    }
    if (!$allowed) {
        json_error(403, 'ليست لديك صلاحية تعديل هذا المنشور');
    }

    if ($isSold) {
        $u = $pdo->prepare('UPDATE properties SET is_sold = 1, sold_at = NOW(3) WHERE id = :id LIMIT 1');
        $u->execute([':id' => $id]);
        vewo_app_notification_add(
            $pdo,
            $ownerId,
            'property_sold',
            'تم بيع العقار',
            'تم تعليم منشورك كمباع.',
            ['type' => 'property_sold', 'property_id' => $id]
        );
        $tokens = vewo_device_tokens_for_user($pdo, $ownerId, false);
        vewo_fcm_send(
            $tokens,
            'تم بيع العقار',
            'تم تعليم منشورك كمباع.',
            ['type' => 'property_sold', 'property_id' => $id]
        );
    } else {
        $u = $pdo->prepare('UPDATE properties SET is_sold = 0, sold_at = NULL WHERE id = :id LIMIT 1');
        $u->execute([':id' => $id]);
    }
    echo json_encode(['ok' => true, 'is_sold' => $isSold ? 1 : 0], JSON_UNESCAPED_UNICODE);
}

function public_offices_list_route(PDO $pdo): void
{
    $hasOfficeName = false;
    $hasOfficeVerified = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_name'"
        );
        $hasOfficeName = $chk !== false && (int) $chk->fetchColumn() > 0;
        $chk2 = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_verified'"
        );
        $hasOfficeVerified = $chk2 !== false && (int) $chk2->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasOfficeName = false;
        $hasOfficeVerified = false;
    }
    $nameExpr = $hasOfficeName
        ? "NULLIF(TRIM(office_name), '')"
        : "NULL";
    $verCol = $hasOfficeVerified ? 'office_verified' : '0 AS office_verified';
    $stmt = $pdo->query(
        "SELECT id, full_name, phone, created_at,
                office_photo_url, office_address, $verCol,
                COALESCE($nameExpr, full_name) AS display_name
         FROM users
         WHERE role = 'office' AND office_approved = 1 AND is_active = 1
         ORDER BY COALESCE($nameExpr, full_name) ASC
         LIMIT 200"
    );
    $rows = $stmt !== false ? $stmt->fetchAll(PDO::FETCH_ASSOC) : [];
    echo json_encode(['ok' => true, 'items' => $rows], JSON_UNESCAPED_UNICODE);
}

/**
 * تفاصيل مكتب معتمد (للعنوان في شاشة منشورات المكتب).
 */
function public_office_detail_route(PDO $pdo): void
{
    $id = trim((string) ($_GET['id'] ?? ''));
    if ($id === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'id غير صالح');
    }
    $hasOfficeName = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_name'"
        );
        $hasOfficeName = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasOfficeName = false;
    }
    $hasOfficeVerified = false;
    try {
        $chk2 = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'office_verified'"
        );
        $hasOfficeVerified = $chk2 !== false && (int) $chk2->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasOfficeVerified = false;
    }
    $cols = 'id, full_name, phone, office_photo_url, office_address, created_at';
    if ($hasOfficeName) {
        $cols .= ', office_name';
    }
    if ($hasOfficeVerified) {
        $cols .= ', office_verified';
    }
    $stmt = $pdo->prepare(
        "SELECT $cols
         FROM users
         WHERE id = :id AND role = 'office' AND office_approved = 1 AND is_active = 1
         LIMIT 1"
    );
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$row) {
        json_error(404, 'المكتب غير موجود أو غير معتمد');
    }
    if (!$hasOfficeVerified) {
        $row['office_verified'] = 0;
    }
    $on = trim((string) ($row['office_name'] ?? ''));
    $row['display_name'] = $on !== '' ? $on : (string) ($row['full_name'] ?? '');
    echo json_encode(['ok' => true, 'office' => $row], JSON_UNESCAPED_UNICODE);
}

/**
 * رفع صورة شعار المكتب أثناء التسجيل (بدون Bearer) — صور فقط، حد 8 ميجا.
 *
 * @param array<string,mixed> $config
 */
function register_office_photo_upload_route(PDO $pdo, array $config): void
{
    unset($pdo);
    if (!isset($_FILES['file']) || !is_array($_FILES['file'])) {
        json_error(400, 'لم يُرفع ملف (استخدم الحقل file)');
    }
    $f = $_FILES['file'];
    if ((int) ($f['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        json_error(400, 'فشل الرفع');
    }
    $tmp = (string) ($f['tmp_name'] ?? '');
    if ($tmp === '' || !is_uploaded_file($tmp)) {
        json_error(400, 'ملف غير صالح');
    }
    $size = (int) ($f['size'] ?? 0);
    if ($size > 8 * 1024 * 1024) {
        json_error(400, 'الصورة كبيرة جداً (الحد 8 ميجابايت)');
    }
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($tmp);
    if (!is_string($mime)) {
        json_error(400, 'تعذر تحديد نوع الملف');
    }
    $map = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
    ];
    if (!isset($map[$mime])) {
        json_error(400, 'يُقبل صورة فقط (jpeg/png/webp/gif)');
    }
    $ext = $map[$mime];
    $dir = dirname(__DIR__) . '/uploads';
    if (!is_dir($dir)) {
        if (!@mkdir($dir, 0755, true) && !is_dir($dir)) {
            json_error(500, 'تعذر إنشاء مجلد الرفع');
        }
    }
    $name = uuid_v4() . '.' . $ext;
    $dest = $dir . '/' . $name;
    if (!move_uploaded_file($tmp, $dest)) {
        json_error(500, 'تعذر حفظ الملف');
    }
    $publicBase = rtrim((string) ($config['public_base_url'] ?? ''), '/');
    if ($publicBase === '') {
        $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && strtolower((string) $_SERVER['HTTP_X_FORWARDED_PROTO']) === 'https');
        $scheme = $https ? 'https' : 'http';
        $host = (string) ($_SERVER['HTTP_HOST'] ?? 'localhost');
        $script = (string) ($_SERVER['SCRIPT_NAME'] ?? '/index.php');
        $basePath = rtrim(str_replace('\\', '/', dirname($script)), '/');
        $publicBase = $scheme . '://' . $host . $basePath;
    }
    $publicUrl = $publicBase . '/uploads/' . $name;

    echo json_encode([
        'ok' => true,
        'public_url' => $publicUrl,
        'mime' => $mime,
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * حرق علامة مائية على ملف صورة (نسخة احتياطية إذا لم تُدمج من التطبيق).
 */
function vewo_burn_watermark_on_image_path(string $path): void
{
    if (!function_exists('imagecreatefromjpeg') || !is_file($path)) {
        return;
    }
    $info = @getimagesize($path);
    if ($info === false) {
        return;
    }
    $w = (int) ($info[0] ?? 0);
    $h = (int) ($info[1] ?? 0);
    if ($w < 1 || $h < 1) {
        return;
    }
    $mime = (string) ($info['mime'] ?? '');
    $im = null;
    switch ($mime) {
        case 'image/jpeg':
            $im = @imagecreatefromjpeg($path);
            break;
        case 'image/png':
            $im = @imagecreatefrompng($path);
            break;
        case 'image/webp':
            if (function_exists('imagecreatefromwebp')) {
                $im = @imagecreatefromwebp($path);
            }
            break;
        case 'image/gif':
            $im = @imagecreatefromgif($path);
            break;
        default:
            return;
    }
    if ($im === false) {
        return;
    }
    imagealphablending($im, true);
    imagesavealpha($im, true);
    // بيج شفاف (#F5E6C8) — بدون ظل أسود
    $beige = imagecolorallocatealpha($im, 245, 230, 200, 70);
    $line1 = 'VIEW';
    $line2 = '07871456361';
    $font = 5;
    $cx = (int) ($w / 2);
    $cy = (int) ($h / 2);
    $x1 = max(8, $cx - (int) (strlen($line1) * 4.5));
    $x2 = max(8, $cx - (int) (strlen($line2) * 4.5));
    imagestring($im, $font, $x1, $cy - 20, $line1, $beige);
    imagestring($im, $font, $x2, $cy + 2, $line2, $beige);
    if ($mime === 'image/png') {
        @imagepng($im, $path, 6);
    } elseif ($mime === 'image/webp' && function_exists('imagewebp')) {
        @imagewebp($im, $path, 88);
    } elseif ($mime === 'image/gif') {
        @imagegif($im, $path);
    } else {
        @imagejpeg($im, $path, 88);
    }
    imagedestroy($im);
}

/**
 * رفع صورة أو فيديو لمسار المنشورات (multipart، الحقل: file) — جلسة زبون/مكتب.
 *
 * @param array<string,mixed> $config
 */
function user_properties_upload_route(PDO $pdo, array $config): void
{
    require_auth_user($pdo);
    if (!isset($_FILES['file']) || !is_array($_FILES['file'])) {
        json_error(400, 'لم يُرفع ملف (استخدم الحقل file)');
    }
    $f = $_FILES['file'];
    if ((int) ($f['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        json_error(400, 'فشل الرفع');
    }
    $tmp = (string) ($f['tmp_name'] ?? '');
    if ($tmp === '' || !is_uploaded_file($tmp)) {
        json_error(400, 'ملف غير صالح');
    }
    $size = (int) ($f['size'] ?? 0);
    if ($size > 40 * 1024 * 1024) {
        json_error(400, 'الملف كبير جداً (الحد 40 ميجابايت)');
    }
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->file($tmp);
    if (!is_string($mime)) {
        json_error(400, 'تعذر تحديد نوع الملف');
    }
    $map = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/gif' => 'gif',
        'video/mp4' => 'mp4',
        'video/webm' => 'webm',
    ];
    if (!isset($map[$mime])) {
        json_error(400, 'نوع الملف غير مدعوم (صورة أو فيديو شائع فقط)');
    }
    $ext = $map[$mime];
    $dir = dirname(__DIR__) . '/uploads';
    if (!is_dir($dir)) {
        if (!@mkdir($dir, 0755, true) && !is_dir($dir)) {
            json_error(500, 'تعذر إنشاء مجلد الرفع');
        }
    }
    $name = uuid_v4() . '.' . $ext;
    $dest = $dir . '/' . $name;
    if (!move_uploaded_file($tmp, $dest)) {
        json_error(500, 'تعذر حفظ الملف');
    }
    // العلامة تُدمج من التطبيق — تجنّب التكرار على السيرفر.
    $publicBase = rtrim((string) ($config['public_base_url'] ?? ''), '/');
    if ($publicBase === '') {
        $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
            || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && strtolower((string) $_SERVER['HTTP_X_FORWARDED_PROTO']) === 'https');
        $scheme = $https ? 'https' : 'http';
        $host = (string) ($_SERVER['HTTP_HOST'] ?? 'localhost');
        $script = (string) ($_SERVER['SCRIPT_NAME'] ?? '/index.php');
        $basePath = rtrim(str_replace('\\', '/', dirname($script)), '/');
        $publicBase = $scheme . '://' . $host . $basePath;
    }
    $publicUrl = $publicBase . '/uploads/' . $name;

    echo json_encode([
        'ok' => true,
        'public_url' => $publicUrl,
        'mime' => $mime,
    ], JSON_UNESCAPED_UNICODE);
}

function properties_create_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $me = require_auth_user($pdo);
    $role = (string) ($me['role'] ?? '');
    if ($role === 'admin') {
        json_error(403, 'المسؤول يضيف العقارات عبر أدوات أخرى');
    }
    if (!in_array($role, ['customer', 'office'], true)) {
        json_error(403, 'غير مسموح');
    }
    if ($role === 'office') {
        $approved = (int) ($me['office_approved'] ?? 0) === 1;
        if (!$approved) {
            json_error(403, 'لا يمكن نشر منشورات قبل موافقة حساب المكتب');
        }
    }

    $in = read_json_body();
    $title = trim((string) ($in['title'] ?? ''));
    $gov = trim((string) ($in['governorate'] ?? ''));
    $addr = trim((string) ($in['address_line'] ?? $in['addressLine'] ?? ''));
    $cat = trim((string) ($in['category'] ?? ''));
    $seg = trim((string) ($in['segment'] ?? 'standard'));
    $parcelId = trim((string) ($in['parcel_id'] ?? ''));
    $purpose = trim((string) ($in['purpose'] ?? 'sale'));
    if (!in_array($purpose, ['sale', 'rent'], true)) {
        $purpose = 'sale';
    }
    $desc = trim((string) ($in['description'] ?? ''));
    $price = (int) ($in['price_iqd'] ?? $in['priceIqd'] ?? 0);
    $area = (int) ($in['area_sqm'] ?? $in['areaSqm'] ?? 0);
    $imageUrl = trim((string) ($in['image_url'] ?? ''));
    $imageUrlsIn = $in['image_urls'] ?? null;
    $imageUrls = [];
    if (is_array($imageUrlsIn)) {
        foreach ($imageUrlsIn as $u) {
            $s = trim((string) $u);
            if ($s !== '' && strlen($s) < 2000) {
                $imageUrls[] = $s;
            }
        }
    }
    if (count($imageUrls) === 0 && $imageUrl !== '') {
        $imageUrls[] = $imageUrl;
    }
    if (count($imageUrls) < 1) {
        json_error(400, 'صورة واحدة على الأقل مطلوبة');
    }
    if (count($imageUrls) > 15) {
        json_error(400, '15 صورة كحد أقصى');
    }
    $videoUrl = trim((string) ($in['video_url'] ?? ''));
    if ($videoUrl !== '' && strlen($videoUrl) > 2000) {
        json_error(400, 'رابط الفيديو غير صالح');
    }

    $detailsRaw = $in['details_json'] ?? $in['detailsJson'] ?? null;
    $detailsJson = null;
    if (is_array($detailsRaw)) {
        $detailsJson = json_encode($detailsRaw, JSON_UNESCAPED_UNICODE);
    } elseif (is_string($detailsRaw) && $detailsRaw !== '') {
        $decoded = json_decode($detailsRaw, true);
        $detailsJson = is_array($decoded) ? json_encode($decoded, JSON_UNESCAPED_UNICODE) : null;
    }

    if ($title === '' || mb_strlen($title) < 3) {
        json_error(400, 'العنوان قصير جداً');
    }
    if ($gov === '' || $addr === '') {
        json_error(400, 'المحافظة والعنوان مطلوبان');
    }
    if (!in_array($cat, ['land', 'house', 'apartment', 'shop', 'compound', 'villa'], true)) {
        json_error(400, 'فئة غير صالحة');
    }
    if (!in_array($seg, ['standard', 'parcel'], true)) {
        json_error(400, 'segment غير صالح');
    }
    if ($seg === 'parcel') {
        // منشور مقاطعات: يختار مقاطعة + وصف + صورة واحدة.
        if ($parcelId === '' || !preg_match('/^[0-9a-fA-F-]{36}$/', $parcelId)) {
            json_error(400, 'اختر المقاطعة');
        }
        if (count($imageUrls) !== 1) {
            json_error(400, 'منشور المقاطعات: صورة واحدة فقط');
        }
        // السعر/المساحة تصبح اختيارية (مخزنة كصفر لتوافق الشِما).
        if ($price < 0) $price = 0;
        if ($area < 0) $area = 0;
    } else {
        if ($price < 1 || $area < 1) {
            json_error(400, 'السعر والمساحة مطلوبان');
        }
        $parcelId = '';
    }
    if (mb_strlen($desc) < 5) {
        json_error(400, 'الوصف قصير جداً');
    }

    $compoundIdIn = trim((string) ($in['compound_id'] ?? ''));
    $compoundValue = null;
    $hasCompoundColCreate = false;
    try {
        $chkCo = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'"
        );
        $hasCompoundColCreate = $chkCo !== false && (int) $chkCo->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasCompoundColCreate = false;
    }
    $hasCompoundsTableCreate = false;
    try {
        $tb = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = DATABASE() AND table_name = 'compounds'"
        );
        $hasCompoundsTableCreate = $tb !== false && (int) $tb->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasCompoundsTableCreate = false;
    }
    if ($compoundIdIn !== '') {
        if (!$hasCompoundColCreate || !$hasCompoundsTableCreate) {
            json_error(503, 'المجمعات غير مهيأة في السيرفر — نفّذ patch_compounds_mysql.sql');
        }
        if (!preg_match('/^[0-9a-fA-F-]{36}$/', $compoundIdIn)) {
            json_error(400, 'اختر المجمع السكني');
        }
        $cstmt = $pdo->prepare(
            'SELECT governorate, compound_name FROM compounds WHERE id = :id AND is_active = 1 LIMIT 1'
        );
        $cstmt->execute([':id' => $compoundIdIn]);
        $crow = $cstmt->fetch(PDO::FETCH_ASSOC);
        if (!$crow) {
            json_error(400, 'المجمع غير موجود أو غير مفعل');
        }
        $compoundValue = $compoundIdIn;
    } elseif ($cat === 'compound' && $seg === 'standard') {
        json_error(400, 'اختر المجمع السكني');
    }

    vewo_office_assert_can_post($pdo, (string) $me['id'], $role);

    $pid = uuid_v4();
    $owner = (string) $me['id'];
    /** منشورات المكتب تُنشر مباشرة؛ الحساب الشخصي يبقى قيد المراجعة. */
    $approvalStatus = $role === 'office' ? 'approved' : 'pending';

    $hasDetailsCol = false;
    try {
        $chk = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'details_json'"
        );
        $hasDetailsCol = $chk !== false && (int) $chk->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasDetailsCol = false;
    }

    $hasPurposeCol = false;
    try {
        $chk2 = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'purpose'"
        );
        $hasPurposeCol = $chk2 !== false && (int) $chk2->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasPurposeCol = false;
    }

    $hasParcelCol = false;
    try {
        $chk3 = $pdo->query(
            "SELECT COUNT(*) FROM information_schema.columns
             WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'parcel_id'"
        );
        $hasParcelCol = $chk3 !== false && (int) $chk3->fetchColumn() > 0;
    } catch (Throwable $e) {
        $hasParcelCol = false;
    }

    $parcelValue = null;
    if ($hasParcelCol && $seg === 'parcel' && $parcelId !== '') {
        // تأكد أن المقاطعة موجودة وفعالة، واجلب governorate/address إن كانت ناقصة.
        $pstmt = $pdo->prepare(
            "SELECT governorate, parcel_name, parcel_no FROM parcels WHERE id = :id AND is_active = 1 LIMIT 1"
        );
        $pstmt->execute([':id' => $parcelId]);
        $prow = $pstmt->fetch(PDO::FETCH_ASSOC);
        if (!$prow) {
            json_error(400, 'المقاطعة غير موجودة أو غير مفعلة');
        }
        $parcelValue = $parcelId;
        if ($gov === '') {
            $gov = (string) ($prow['governorate'] ?? '');
        }
        if ($addr === '') {
            $pn = trim((string) ($prow['parcel_name'] ?? ''));
            $pno = trim((string) ($prow['parcel_no'] ?? ''));
            $addr = $pno !== '' ? ($pn . ' — ' . $pno) : $pn;
        }
    }

    if ($gov === '' || $addr === '') {
        json_error(400, 'المحافظة والعنوان مطلوبان');
    }

    if ($hasDetailsCol && ($compoundValue !== null || $parcelValue !== null)) {
        $djArr = [];
        if (is_string($detailsJson) && $detailsJson !== '') {
            $tmp = json_decode($detailsJson, true);
            if (is_array($tmp)) {
                $djArr = $tmp;
            }
        }
        if ($compoundValue !== null && $compoundValue !== '') {
            $djArr['compound_id'] = $compoundValue;
            $compoundName = trim((string) ($crow['compound_name'] ?? ''));
            if ($compoundName !== '') {
                $djArr['compound_name'] = $compoundName;
            }
        }
        if ($parcelValue !== null && $parcelValue !== '') {
            $djArr['parcel_id'] = $parcelValue;
        }
        $detailsJson = json_encode($djArr, JSON_UNESCAPED_UNICODE);
    }

    $hasPublicNo = vewo_properties_has_public_no_column($pdo);
    $pubNo = $hasPublicNo ? vewo_allocate_property_public_no($pdo) : null;

    if ($hasPurposeCol && $hasDetailsCol && $hasParcelCol) {
        if ($hasPublicNo) {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, property_public_no, owner_user_id, parcel_id, title, governorate, address_line, category, segment, purpose,
                 price_iqd, area_sqm, description, details_json, views, approval_status, created_at)
                 VALUES (:id, :pub, :ow, :pid, :ti, :go, :ad, :ca, :sg, :pu, :pr, :ar, :de, :dj, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':pub' => $pubNo,
                ':ow' => $owner,
                ':pid' => $parcelValue,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pu' => $purpose,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
                ':dj' => $detailsJson,
            ]);
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, owner_user_id, parcel_id, title, governorate, address_line, category, segment, purpose,
                 price_iqd, area_sqm, description, details_json, views, approval_status, created_at)
                 VALUES (:id, :ow, :pid, :ti, :go, :ad, :ca, :sg, :pu, :pr, :ar, :de, :dj, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':ow' => $owner,
                ':pid' => $parcelValue,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pu' => $purpose,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
                ':dj' => $detailsJson,
            ]);
        }
    } elseif ($hasPurposeCol && $hasParcelCol) {
        if ($hasPublicNo) {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, property_public_no, owner_user_id, parcel_id, title, governorate, address_line, category, segment, purpose,
                 price_iqd, area_sqm, description, views, approval_status, created_at)
                 VALUES (:id, :pub, :ow, :pid, :ti, :go, :ad, :ca, :sg, :pu, :pr, :ar, :de, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':pub' => $pubNo,
                ':ow' => $owner,
                ':pid' => $parcelValue,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pu' => $purpose,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
            ]);
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, owner_user_id, parcel_id, title, governorate, address_line, category, segment, purpose,
                 price_iqd, area_sqm, description, views, approval_status, created_at)
                 VALUES (:id, :ow, :pid, :ti, :go, :ad, :ca, :sg, :pu, :pr, :ar, :de, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':ow' => $owner,
                ':pid' => $parcelValue,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pu' => $purpose,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
            ]);
        }
    } elseif ($hasParcelCol) {
        if ($hasPublicNo) {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, property_public_no, owner_user_id, parcel_id, title, governorate, address_line, category, segment,
                 price_iqd, area_sqm, description, views, approval_status, created_at)
                 VALUES (:id, :pub, :ow, :pid, :ti, :go, :ad, :ca, :sg, :pr, :ar, :de, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':pub' => $pubNo,
                ':ow' => $owner,
                ':pid' => $parcelValue,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
            ]);
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, owner_user_id, parcel_id, title, governorate, address_line, category, segment,
                 price_iqd, area_sqm, description, views, approval_status, created_at)
                 VALUES (:id, :ow, :pid, :ti, :go, :ad, :ca, :sg, :pr, :ar, :de, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':ow' => $owner,
                ':pid' => $parcelValue,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
            ]);
        }
    } else {
        // مخطط قديم بدون parcel_id
        if ($seg === 'parcel' && $parcelId !== '') {
            // نخزّن parcel_id داخل details_json كحل احتياطي
            $extra = ['parcel_id' => $parcelId];
            $djArr = [];
            if (is_string($detailsJson) && $detailsJson !== '') {
                $tmp = json_decode($detailsJson, true);
                if (is_array($tmp)) $djArr = $tmp;
            }
            if (!is_array($djArr)) $djArr = [];
            $detailsJson = json_encode([...$djArr, ...$extra], JSON_UNESCAPED_UNICODE);
        }
        $djLegacy = ($hasDetailsCol && is_string($detailsJson) && $detailsJson !== '')
            ? $detailsJson
            : null;
        if ($hasPublicNo) {
            if ($djLegacy !== null) {
                $stmt = $pdo->prepare(
                    'INSERT INTO properties (id, property_public_no, owner_user_id, title, governorate, address_line, category, segment,
                     price_iqd, area_sqm, description, details_json, views, approval_status, created_at)
                     VALUES (:id, :pub, :ow, :ti, :go, :ad, :ca, :sg, :pr, :ar, :de, :dj, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
                );
                $stmt->execute([
                    ':id' => $pid,
                    ':pub' => $pubNo,
                    ':ow' => $owner,
                    ':ti' => $title,
                    ':go' => $gov,
                    ':ad' => $addr,
                    ':ca' => $cat,
                    ':sg' => $seg,
                    ':pr' => $price,
                    ':ar' => $area,
                    ':de' => $desc,
                    ':dj' => $djLegacy,
                ]);
            } else {
                $stmt = $pdo->prepare(
                    'INSERT INTO properties (id, property_public_no, owner_user_id, title, governorate, address_line, category, segment,
                     price_iqd, area_sqm, description, views, approval_status, created_at)
                     VALUES (:id, :pub, :ow, :ti, :go, :ad, :ca, :sg, :pr, :ar, :de, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
                );
                $stmt->execute([
                    ':id' => $pid,
                    ':pub' => $pubNo,
                    ':ow' => $owner,
                    ':ti' => $title,
                    ':go' => $gov,
                    ':ad' => $addr,
                    ':ca' => $cat,
                    ':sg' => $seg,
                    ':pr' => $price,
                    ':ar' => $area,
                    ':de' => $desc,
                ]);
            }
        } elseif ($djLegacy !== null) {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, owner_user_id, title, governorate, address_line, category, segment,
                 price_iqd, area_sqm, description, details_json, views, approval_status, created_at)
                 VALUES (:id, :ow, :ti, :go, :ad, :ca, :sg, :pr, :ar, :de, :dj, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':ow' => $owner,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
                ':dj' => $djLegacy,
            ]);
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO properties (id, owner_user_id, title, governorate, address_line, category, segment,
                 price_iqd, area_sqm, description, views, approval_status, created_at)
                 VALUES (:id, :ow, :ti, :go, :ad, :ca, :sg, :pr, :ar, :de, 0, ' . $pdo->quote($approvalStatus) . ', NOW(3))'
            );
            $stmt->execute([
                ':id' => $pid,
                ':ow' => $owner,
                ':ti' => $title,
                ':go' => $gov,
                ':ad' => $addr,
                ':ca' => $cat,
                ':sg' => $seg,
                ':pr' => $price,
                ':ar' => $area,
                ':de' => $desc,
            ]);
        }
    }

    if ($compoundValue !== null && $compoundValue !== '') {
        try {
            $chkUp = $pdo->query(
                "SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = 'properties' AND column_name = 'compound_id'"
            );
            if ($chkUp !== false && (int) $chkUp->fetchColumn() > 0) {
                $upCompound = $pdo->prepare('UPDATE properties SET compound_id = :c WHERE id = :id LIMIT 1');
                $upCompound->execute([':c' => $compoundValue, ':id' => $pid]);
            }
        } catch (Throwable $e) {
        }
    }

    $insMedia = $pdo->prepare(
        'INSERT INTO property_media (id, property_id, media_type, storage_key, public_url, created_at)
         VALUES (:id, :pid, :mt, :sk, :url, NOW(3))'
    );
    foreach ($imageUrls as $u) {
        $mid = uuid_v4();
        $insMedia->execute([
            ':id' => $mid,
            ':pid' => $pid,
            ':mt' => 'image',
            ':sk' => 'remote:' . $mid,
            ':url' => $u,
        ]);
    }
    if ($videoUrl !== '') {
        $midv = uuid_v4();
        $insMedia->execute([
            ':id' => $midv,
            ':pid' => $pid,
            ':mt' => 'video',
            ':sk' => 'remote:' . $midv,
            ':url' => $videoUrl,
        ]);
    }

    vewo_office_consume_posting_quota($pdo, $owner, $role);

    try {
        $adminId = first_admin_user_id($pdo);
        if ($adminId !== '') {
            $tokens = vewo_device_tokens_for_user($pdo, $adminId, true);
            $noLabel = $pubNo !== null ? '#' . $pubNo : $title;
            vewo_fcm_send(
                $tokens,
                'منشور جديد',
                'يوجد منشور جديد للمراجعة: ' . $noLabel,
                [
                    'type' => 'admin_property_pending',
                    'section' => 'properties',
                    'property_id' => $pid,
                    'property_public_no' => $pubNo,
                ]
            );
        }
    } catch (Throwable $e) {
    }

    $out = ['ok' => true, 'id' => $pid, 'approval_status' => $approvalStatus];
    if ($pubNo !== null) {
        $out['property_public_no'] = $pubNo;
    }
    echo json_encode($out, JSON_UNESCAPED_UNICODE);
}

/**
 * قائمة الريلز المعتمدة للتطبيق (عمومي) — مشاهدات ولايكات حقيقية من قاعدة البيانات.
 */
function public_reels_list_route(PDO $pdo): void
{
    $lim = (int) ($_GET['limit'] ?? 30);
    if ($lim < 1) {
        $lim = 1;
    }
    if ($lim > 80) {
        $lim = 80;
    }
    $ownerFilter = trim((string) ($_GET['owner_id'] ?? $_GET['user_id'] ?? ''));
    if ($ownerFilter !== '' && !preg_match('/^[0-9a-fA-F-]{36}$/', $ownerFilter)) {
        json_error(400, 'owner_id غير صالح');
    }
    $uid = null;
    $su = vewo_try_session_user($pdo);
    if (is_array($su)) {
        $uid = (string) ($su['id'] ?? '');
        if ($uid === '') {
            $uid = null;
        }
    }
    $hasEng = vewo_reels_has_engagement_columns($pdo);
    try {
        if ($hasEng) {
            $likedExpr = $uid !== null
                ? "(SELECT COUNT(*) FROM reel_reactions rx WHERE rx.reel_id = r.id AND rx.user_id = :uid AND rx.reaction_type = 'like') AS liked_me"
                : '0 AS liked_me';
            $ownerWhere = $ownerFilter !== '' ? ' AND r.owner_user_id = :owner_filter' : '';
            $sql = "SELECT r.id, r.property_id, r.video_public_url, r.caption, r.comments_enabled, r.created_at,
                    r.view_count, r.synthetic_likes,
                    u.id AS owner_user_id, u.full_name, u.role, u.office_name, u.office_photo_url,
                    COALESCE((SELECT COUNT(*) FROM reel_comments c WHERE c.reel_id = r.id), 0) AS comments_count,
                    ((SELECT COUNT(*) FROM reel_reactions rr WHERE rr.reel_id = r.id AND rr.reaction_type = 'like')
                      + COALESCE(r.synthetic_likes, 0)) AS likes_count,
                    {$likedExpr}
             FROM reels r
             INNER JOIN users u ON u.id = r.owner_user_id
             WHERE r.approval_status = 'approved'{$ownerWhere}
             ORDER BY r.created_at DESC
             LIMIT {$lim}";
            $stmt = $pdo->prepare($sql);
            if ($uid !== null) {
                $stmt->bindValue(':uid', $uid, PDO::PARAM_STR);
            }
            if ($ownerFilter !== '') {
                $stmt->bindValue(':owner_filter', $ownerFilter, PDO::PARAM_STR);
            }
            $stmt->execute();
        } else {
            $ownerWhere = $ownerFilter !== '' ? ' AND r.owner_user_id = :owner_filter' : '';
            $stmt = $pdo->prepare(
                "SELECT r.id, r.property_id, r.video_public_url, r.caption, r.comments_enabled, r.created_at,
                    u.id AS owner_user_id, u.full_name, u.role, u.office_name, u.office_photo_url,
                    COALESCE((SELECT COUNT(*) FROM reel_comments c WHERE c.reel_id = r.id), 0) AS comments_count,
                    0 AS view_count,
                    (SELECT COUNT(*) FROM reel_reactions rr WHERE rr.reel_id = r.id AND rr.reaction_type = 'like') AS likes_count,
                    0 AS liked_me
             FROM reels r
             INNER JOIN users u ON u.id = r.owner_user_id
             WHERE r.approval_status = 'approved'{$ownerWhere}
             ORDER BY r.created_at DESC
             LIMIT {$lim}"
            );
            if ($ownerFilter !== '') {
                $stmt->bindValue(':owner_filter', $ownerFilter, PDO::PARAM_STR);
            }
            $stmt->execute();
        }
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Throwable $e) {
        echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);

        return;
    }
    $items = [];
    foreach ($rows as $row) {
        $role = (string) ($row['role'] ?? '');
        $officeName = trim((string) ($row['office_name'] ?? ''));
        $isOffice = $role === 'office' && $officeName !== '';
        $likedRaw = (int) ($row['liked_me'] ?? 0);
        $items[] = [
            'id' => (string) $row['id'],
            'property_id' => $row['property_id'] !== null && (string) $row['property_id'] !== ''
                ? (string) $row['property_id'] : null,
            'video_public_url' => (string) $row['video_public_url'],
            'caption' => (string) $row['caption'],
            'comments_enabled' => false,
            'comments_count' => 0,
            'view_count' => (int) ($row['view_count'] ?? 0),
            'likes_count' => (int) ($row['likes_count'] ?? 0),
            'liked_by_me' => $likedRaw > 0,
            'created_at' => (string) $row['created_at'],
            'publisher_display' => $isOffice ? $officeName : null,
            'publisher_avatar_url' => $isOffice ? trim((string) ($row['office_photo_url'] ?? '')) : null,
            'publisher_is_office' => $isOffice,
        ];
    }
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}

/**
 * تفاصيل ريل واحد (للمحادثة والمشاركة).
 */
function public_reel_detail_route(PDO $pdo): void
{
    $id = trim((string) ($_GET['id'] ?? $_GET['reel_id'] ?? ''));
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'معرّف الريل غير صالح');
    }
    $hasEng = vewo_reels_has_engagement_columns($pdo);
    $likedExpr = '0 AS liked_me';
    $uid = null;
    $su = vewo_try_session_user($pdo);
    if (is_array($su)) {
        $uid = trim((string) ($su['id'] ?? ''));
        if ($uid === '') {
            $uid = null;
        }
    }
    if ($uid !== null) {
        $likedExpr = "(SELECT COUNT(*) FROM reel_reactions rx WHERE rx.reel_id = r.id AND rx.user_id = :uid AND rx.reaction_type = 'like') AS liked_me";
    }
    $engCols = $hasEng ? 'r.view_count, r.synthetic_likes,' : '0 AS view_count, 0 AS synthetic_likes,';
    $likesExpr = $hasEng
        ? '((SELECT COUNT(*) FROM reel_reactions rr WHERE rr.reel_id = r.id AND rr.reaction_type = \'like\') + COALESCE(r.synthetic_likes, 0))'
        : '(SELECT COUNT(*) FROM reel_reactions rr WHERE rr.reel_id = r.id AND rr.reaction_type = \'like\')';
    $sql = "SELECT r.id, r.property_id, r.video_public_url, r.caption, r.comments_enabled, r.created_at,
            {$engCols}
            u.id AS owner_user_id, u.full_name, u.role, u.office_name, u.office_photo_url,
            COALESCE((SELECT COUNT(*) FROM reel_comments c WHERE c.reel_id = r.id), 0) AS comments_count,
            {$likesExpr} AS likes_count,
            {$likedExpr}
     FROM reels r
     INNER JOIN users u ON u.id = r.owner_user_id
     WHERE r.id = :id AND r.approval_status = 'approved'
     LIMIT 1";
    $stmt = $pdo->prepare($sql);
    $stmt->bindValue(':id', $id, PDO::PARAM_STR);
    if ($uid !== null) {
        $stmt->bindValue(':uid', $uid, PDO::PARAM_STR);
    }
    $stmt->execute();
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($row)) {
        json_error(404, 'الريل غير موجود');
    }
    $role = (string) ($row['role'] ?? '');
    $officeName = trim((string) ($row['office_name'] ?? ''));
    $isOffice = $role === 'office' && $officeName !== '';
    $item = [
        'id' => (string) $row['id'],
        'property_id' => $row['property_id'] !== null && (string) $row['property_id'] !== ''
            ? (string) $row['property_id'] : null,
        'video_public_url' => (string) $row['video_public_url'],
        'caption' => (string) $row['caption'],
        'comments_enabled' => false,
        'comments_count' => 0,
        'view_count' => (int) ($row['view_count'] ?? 0),
        'likes_count' => (int) ($row['likes_count'] ?? 0),
        'liked_by_me' => (int) ($row['liked_me'] ?? 0) > 0,
        'created_at' => (string) $row['created_at'],
        'publisher_display' => $isOffice ? $officeName : (string) ($row['full_name'] ?? ''),
        'publisher_avatar_url' => $isOffice ? trim((string) ($row['office_photo_url'] ?? '')) : null,
        'publisher_is_office' => $isOffice,
    ];
    echo json_encode(['ok' => true, 'item' => $item], JSON_UNESCAPED_UNICODE);
}

/**
 * تسجيل مشاهدة للريل (زيادة view_count عند توفر العمود).
 */
function reels_record_view_route(PDO $pdo): void
{
    $in = read_json_body();
    $reelId = trim((string) ($in['reel_id'] ?? $in['reelId'] ?? ''));
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $reelId)) {
        json_error(400, 'معرّف الريل غير صالح');
    }
    $chk = $pdo->prepare("SELECT id FROM reels WHERE id = :id AND approval_status = 'approved' LIMIT 1");
    $chk->execute([':id' => $reelId]);
    if (!$chk->fetch(PDO::FETCH_ASSOC)) {
        json_error(404, 'الريل غير موجود');
    }
    if (vewo_reels_has_engagement_columns($pdo)) {
        try {
            $u = $pdo->prepare('UPDATE reels SET view_count = view_count + 1 WHERE id = :id LIMIT 1');
            $u->execute([':id' => $reelId]);
        } catch (Throwable $e) {
        }
    }
    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
}

/**
 * لايك / إلغاء لايك على الريل (جدول reel_reactions).
 */
function reels_react_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $role = (string) ($me['role'] ?? '');
    if (!in_array($role, ['customer', 'office'], true)) {
        json_error(403, 'غير مسموح');
    }
    $in = read_json_body();
    $reelId = trim((string) ($in['reel_id'] ?? $in['reelId'] ?? ''));
    $liked = (int) ($in['liked'] ?? $in['like'] ?? 1) === 1;
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $reelId)) {
        json_error(400, 'معرّف الريل غير صالح');
    }
    $chk = $pdo->prepare("SELECT id FROM reels WHERE id = :id AND approval_status = 'approved' LIMIT 1");
    $chk->execute([':id' => $reelId]);
    if (!$chk->fetch(PDO::FETCH_ASSOC)) {
        json_error(404, 'الريل غير موجود');
    }
    $uid = (string) $me['id'];
    if ($liked) {
        try {
            $ins = $pdo->prepare(
                "INSERT INTO reel_reactions (id, reel_id, user_id, reaction_type, created_at)
                 VALUES (:id, :rid, :uid, 'like', NOW(3))"
            );
            $ins->execute([':id' => uuid_v4(), ':rid' => $reelId, ':uid' => $uid]);
        } catch (PDOException $e) {
            // duplicate unique — already liked
        }
    } else {
        $del = $pdo->prepare(
            "DELETE FROM reel_reactions WHERE reel_id = :rid AND user_id = :uid AND reaction_type = 'like'"
        );
        $del->execute([':rid' => $reelId, ':uid' => $uid]);
    }
    $cntStmt = $pdo->prepare(
        "SELECT COUNT(*) FROM reel_reactions WHERE reel_id = :rid AND reaction_type = 'like'"
    );
    $cntStmt->execute([':rid' => $reelId]);
    $likes = (int) ($cntStmt->fetchColumn() ?: 0);
    $mine = $pdo->prepare(
        "SELECT COUNT(*) FROM reel_reactions WHERE reel_id = :rid AND user_id = :uid AND reaction_type = 'like'"
    );
    $mine->execute([':rid' => $reelId, ':uid' => $uid]);
    $likedMe = ((int) ($mine->fetchColumn() ?: 0)) > 0;
    echo json_encode(['ok' => true, 'likes_count' => $likes, 'liked_by_me' => $likedMe], JSON_UNESCAPED_UNICODE);
}

/**
 * إنشاء ريل: يرفع العميل الفيديو عبر `properties/upload` ثم يرسل `video_public_url`.
 * المكتب يُعتمد مباشرة؛ الحساب الشخصي قيد المراجعة.
 */
function reels_create_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $role = (string) ($me['role'] ?? '');
    if ($role === 'admin') {
        json_error(403, 'لا يمكن نشر ريلز من حساب المسؤول هنا');
    }
    if (!in_array($role, ['customer', 'office'], true)) {
        json_error(403, 'غير مسموح');
    }
    if ($role === 'office') {
        $approved = (int) ($me['office_approved'] ?? 0) === 1;
        if (!$approved) {
            json_error(403, 'لا يمكن نشر ريلز قبل موافقة حساب المكتب');
        }
    }

    $in = read_json_body();
    $videoUrl = trim((string) ($in['video_public_url'] ?? $in['videoPublicUrl'] ?? ''));
    if ($videoUrl === '' || strlen($videoUrl) > 1000) {
        json_error(400, 'رابط الفيديو مطلوب');
    }
    if (!preg_match('#^https?://#i', $videoUrl)) {
        json_error(400, 'رابط الفيديو غير صالح');
    }
    $caption = mb_substr(trim((string) ($in['caption'] ?? '')), 0, 500);
    $commentsEnabled = 0;
    $propertyId = trim((string) ($in['property_id'] ?? $in['propertyId'] ?? ''));
    if ($propertyId !== '' && !preg_match('/^[0-9a-fA-F-]{36}$/', $propertyId)) {
        json_error(400, 'معرّف عقار غير صالح');
    }
    if ($propertyId !== '') {
        $chk = $pdo->prepare('SELECT id FROM properties WHERE id = :id LIMIT 1');
        $chk->execute([':id' => $propertyId]);
        if (!$chk->fetch(PDO::FETCH_ASSOC)) {
            json_error(400, 'العقار غير موجود');
        }
    } else {
        $propertyId = null;
    }

    $path = parse_url($videoUrl, PHP_URL_PATH);
    $storageKey = is_string($path) && $path !== '' ? basename($path) : '';
    if ($storageKey === '' || strlen($storageKey) > 500) {
        json_error(400, 'تعذر استخراج اسم الملف من الرابط');
    }

    $approvalStatus = $role === 'office' ? 'approved' : 'pending';
    $rid = uuid_v4();
    $owner = (string) $me['id'];
    $hasCommentsEnabled = vewo_reels_has_comments_enabled_column($pdo);

    try {
        $params = [
            ':id' => $rid,
            ':pid' => $propertyId,
            ':ow' => $owner,
            ':sk' => $storageKey,
            ':url' => $videoUrl,
            ':cap' => $caption,
            ':ap' => $approvalStatus,
        ];
        if ($hasCommentsEnabled) {
            $stmt = $pdo->prepare(
                'INSERT INTO reels (id, property_id, owner_user_id, video_storage_key, video_public_url, caption, comments_enabled, approval_status, created_at)
                 VALUES (:id, :pid, :ow, :sk, :url, :cap, :ce, :ap, NOW(3))'
            );
            $params[':ce'] = $commentsEnabled;
        } else {
            $stmt = $pdo->prepare(
                'INSERT INTO reels (id, property_id, owner_user_id, video_storage_key, video_public_url, caption, approval_status, created_at)
                 VALUES (:id, :pid, :ow, :sk, :url, :cap, :ap, NOW(3))'
            );
        }
        $stmt->execute($params);
    } catch (Throwable $e) {
        json_error(500, 'تعذر حفظ الريل — تأكد من تثبيت جدول reels');
    }

    echo json_encode([
        'ok' => true,
        'id' => $rid,
        'approval_status' => $approvalStatus,
    ], JSON_UNESCAPED_UNICODE);
}

function reels_comments_list_route(PDO $pdo): void
{
    $reelId = trim((string) ($_GET['reel_id'] ?? $_GET['reelId'] ?? ''));
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $reelId)) {
        json_error(400, 'معرّف الريل غير صالح');
    }

    $stmt = $pdo->prepare(
        "SELECT c.id, c.reel_id, c.parent_comment_id, c.user_id, c.body, c.created_at,
                u.full_name, u.role, u.office_name, u.office_verified,
                COALESCE((SELECT COUNT(*) FROM reel_comment_likes l WHERE l.comment_id = c.id), 0) AS likes_count
         FROM reel_comments c
         INNER JOIN users u ON u.id = c.user_id
         INNER JOIN reels r ON r.id = c.reel_id
         WHERE c.reel_id = :rid AND r.approval_status = 'approved'
         ORDER BY COALESCE(c.parent_comment_id, c.id), c.created_at ASC
         LIMIT 300"
    );
    $stmt->execute([':rid' => $reelId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    $items = [];
    foreach ($rows as $row) {
        $role = (string) ($row['role'] ?? '');
        $officeName = trim((string) ($row['office_name'] ?? ''));
        $isOffice = $role === 'office';
        $items[] = [
            'id' => (string) $row['id'],
            'reel_id' => (string) $row['reel_id'],
            'parent_comment_id' => $row['parent_comment_id'] ? (string) $row['parent_comment_id'] : null,
            'body' => (string) $row['body'],
            'created_at' => (string) $row['created_at'],
            'author_name' => $isOffice && $officeName !== '' ? $officeName : (string) $row['full_name'],
            'author_role' => $role,
            'author_user_id' => (string) $row['user_id'],
            'can_open_profile' => $isOffice,
            'office_verified' => $isOffice && ((int) ($row['office_verified'] ?? 0)) === 1,
            'likes_count' => (int) ($row['likes_count'] ?? 0),
        ];
    }
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}

function reels_comments_create_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $role = (string) ($me['role'] ?? '');
    if (!in_array($role, ['customer', 'office'], true)) {
        json_error(403, 'غير مسموح');
    }
    $in = read_json_body();
    $reelId = trim((string) ($in['reel_id'] ?? $in['reelId'] ?? ''));
    $parentId = trim((string) ($in['parent_comment_id'] ?? $in['parentCommentId'] ?? ''));
    $body = trim((string) ($in['body'] ?? ''));
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $reelId)) {
        json_error(400, 'معرّف الريل غير صالح');
    }
    if ($parentId !== '' && !preg_match('/^[0-9a-fA-F-]{36}$/', $parentId)) {
        json_error(400, 'معرّف التعليق غير صالح');
    }
    if (mb_strlen($body) < 1 || mb_strlen($body) > 1000) {
        json_error(400, 'نص التعليق غير صالح');
    }
    $commentsSelect = vewo_reels_has_comments_enabled_column($pdo)
        ? 'comments_enabled'
        : '1 AS comments_enabled';
    $chk = $pdo->prepare("SELECT id, {$commentsSelect} FROM reels WHERE id = :id AND approval_status = 'approved' LIMIT 1");
    $chk->execute([':id' => $reelId]);
    $reel = $chk->fetch(PDO::FETCH_ASSOC);
    if (!is_array($reel)) {
        json_error(404, 'الريل غير موجود');
    }
    if (((int) ($reel['comments_enabled'] ?? 1)) !== 1) {
        json_error(403, 'التعليقات متوقفة لهذا الريل');
    }
    if ($parentId !== '') {
        $pc = $pdo->prepare('SELECT id FROM reel_comments WHERE id = :id AND reel_id = :rid LIMIT 1');
        $pc->execute([':id' => $parentId, ':rid' => $reelId]);
        if (!$pc->fetch(PDO::FETCH_ASSOC)) {
            json_error(400, 'التعليق الأصلي غير موجود');
        }
    }
    $id = uuid_v4();
    $stmt = $pdo->prepare(
        'INSERT INTO reel_comments (id, reel_id, parent_comment_id, user_id, body, created_at)
         VALUES (:id, :rid, :pid, :uid, :body, NOW(3))'
    );
    $stmt->execute([
        ':id' => $id,
        ':rid' => $reelId,
        ':pid' => $parentId !== '' ? $parentId : null,
        ':uid' => (string) $me['id'],
        ':body' => $body,
    ]);
    echo json_encode(['ok' => true, 'id' => $id], JSON_UNESCAPED_UNICODE);
}

function reels_comment_like_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $commentId = trim((string) ($in['comment_id'] ?? $in['commentId'] ?? ''));
    $liked = (int) ($in['liked'] ?? 1) === 1;
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $commentId)) {
        json_error(400, 'معرّف التعليق غير صالح');
    }
    $chk = $pdo->prepare('SELECT id FROM reel_comments WHERE id = :id LIMIT 1');
    $chk->execute([':id' => $commentId]);
    if (!$chk->fetch(PDO::FETCH_ASSOC)) {
        json_error(404, 'التعليق غير موجود');
    }
    if ($liked) {
        try {
            $stmt = $pdo->prepare(
                'INSERT INTO reel_comment_likes (id, comment_id, user_id, created_at)
                 VALUES (:id, :cid, :uid, NOW(3))'
            );
            $stmt->execute([':id' => uuid_v4(), ':cid' => $commentId, ':uid' => (string) $me['id']]);
        } catch (PDOException $e) {
            // Already liked.
        }
    } else {
        $stmt = $pdo->prepare('DELETE FROM reel_comment_likes WHERE comment_id = :cid AND user_id = :uid');
        $stmt->execute([':cid' => $commentId, ':uid' => (string) $me['id']]);
    }
    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
}

function admin_reels_route(PDO $pdo): void
{
    require_admin_from_bearer($pdo);
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        vewo_engagement_process_due_rules($pdo);
        $status = trim((string) ($_GET['status'] ?? 'pending'));
        if (!in_array($status, ['pending', 'approved', 'rejected'], true)) {
            $status = 'pending';
        }
        $qRaw = trim((string) ($_GET['q'] ?? ''));
        $qRaw = ltrim($qRaw, '#');
        $filterPub = ($qRaw !== '' && ctype_digit($qRaw)) ? (int) $qRaw : null;
        $sortPopular = trim((string) ($_GET['sort'] ?? '')) === 'popular';
        $commentsSelect = vewo_reels_has_comments_enabled_column($pdo)
            ? 'r.comments_enabled'
            : '1 AS comments_enabled';
        $pubCol = vewo_reels_has_public_no_column($pdo)
            ? 'r.reel_public_no'
            : 'NULL AS reel_public_no';
        $engExtra = '';
        $orderBy = 'r.created_at DESC';
        if (vewo_reels_has_engagement_columns($pdo)) {
            $engExtra = ', r.view_count, r.synthetic_likes,
                (SELECT COUNT(*) FROM reel_reactions rr WHERE rr.reel_id = r.id) AS real_likes_count';
            if ($sortPopular && $status === 'approved') {
                $orderBy = '(r.view_count + r.synthetic_likes + (SELECT COUNT(*) FROM reel_reactions rr2 WHERE rr2.reel_id = r.id)) DESC, r.created_at DESC';
            }
        } else {
            $engExtra = ', 0 AS view_count, 0 AS synthetic_likes, 0 AS real_likes_count';
        }
        $sql = "SELECT r.id, {$pubCol}, r.video_public_url, r.caption, {$commentsSelect}, r.approval_status, r.created_at,
                    u.full_name, u.role, u.office_name, u.phone
                    {$engExtra}
             FROM reels r
             INNER JOIN users u ON u.id = r.owner_user_id
             WHERE r.approval_status = :st";
        if ($filterPub !== null && vewo_reels_has_public_no_column($pdo)) {
            $sql .= ' AND r.reel_public_no = :pubq';
        }
        $sql .= " ORDER BY {$orderBy} LIMIT 300";
        $stmt = $pdo->prepare($sql);
        $stmt->bindValue(':st', $status, PDO::PARAM_STR);
        if ($filterPub !== null && vewo_reels_has_public_no_column($pdo)) {
            $stmt->bindValue(':pubq', $filterPub, PDO::PARAM_INT);
        }
        $stmt->execute();
        echo json_encode(['ok' => true, 'items' => $stmt->fetchAll(PDO::FETCH_ASSOC)], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($method === 'DELETE') {
        $id = trim((string) ($_GET['id'] ?? ''));
        if (!preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
            json_error(400, 'معرّف الريل غير صالح');
        }
        try {
            $pdo->beginTransaction();
            try {
                $pdo->prepare(
                    'DELETE l FROM reel_comment_likes l
                     INNER JOIN reel_comments c ON c.id = l.comment_id
                     WHERE c.reel_id = :id'
                )->execute([':id' => $id]);
            } catch (Throwable $e) {
            }
            try {
                $pdo->prepare('DELETE FROM reel_comments WHERE reel_id = :id')->execute([':id' => $id]);
            } catch (Throwable $e) {
            }
            $stmt = $pdo->prepare('DELETE FROM reels WHERE id = :id LIMIT 1');
            $stmt->execute([':id' => $id]);
            $pdo->commit();
            echo json_encode(['ok' => true, 'deleted' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            json_error(500, 'تعذر حذف الريل');
        }

        return;
    }
    if ($method !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $in = read_json_body();
    $id = trim((string) ($in['id'] ?? ''));
    $action = trim((string) ($in['action'] ?? ''));
    if (!preg_match('/^[0-9a-fA-F-]{36}$/', $id)) {
        json_error(400, 'معرّف الريل غير صالح');
    }
    if ($action === 'approve') {
        $stmt = $pdo->prepare("UPDATE reels SET approval_status = 'approved' WHERE id = :id LIMIT 1");
        $stmt->execute([':id' => $id]);
        if (vewo_reels_has_public_no_column($pdo)) {
            try {
                $chk = $pdo->prepare('SELECT reel_public_no FROM reels WHERE id = :id LIMIT 1');
                $chk->execute([':id' => $id]);
                $existing = $chk->fetchColumn();
                if ($existing === false || $existing === null || (int) $existing < 1) {
                    $newNo = vewo_allocate_reel_public_no($pdo);
                    $u = $pdo->prepare('UPDATE reels SET reel_public_no = :n WHERE id = :id LIMIT 1');
                    $u->execute([':n' => $newNo, ':id' => $id]);
                }
            } catch (Throwable $e) {
            }
        }
        echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($action === 'reject') {
        $stmt = $pdo->prepare("UPDATE reels SET approval_status = 'rejected' WHERE id = :id LIMIT 1");
        $stmt->execute([':id' => $id]);
        echo json_encode(['ok' => true, 'updated' => $stmt->rowCount()], JSON_UNESCAPED_UNICODE);

        return;
    }
    json_error(400, 'إجراء غير صالح');
}

/**
 * حذف مستخدم وجميع البيانات المرتبطة به (خطر).
 */
function vewo_admin_delete_user_cascade(PDO $pdo, string $userId): void
{
    $pdo->beginTransaction();
    try {
        $pdo->exec('SET FOREIGN_KEY_CHECKS=0');
        try {
            $pdo->prepare('DELETE FROM chat_messages WHERE sender_user_id = :u')->execute([':u' => $userId]);
            $pdo->prepare(
                'DELETE FROM chat_threads WHERE customer_user_id = :u OR office_user_id = :u OR admin_user_id = :u'
            )->execute([':u' => $userId]);
            try {
                $pdo->prepare(
                    'DELETE FROM property_media WHERE property_id IN (SELECT id FROM properties WHERE owner_user_id = :u)'
                )->execute([':u' => $userId]);
            } catch (Throwable $e) {
            }
            try {
                $pdo->prepare('DELETE FROM favorites WHERE user_id = :u')->execute([':u' => $userId]);
            } catch (Throwable $e) {
            }
            try {
                $pdo->prepare('DELETE FROM properties WHERE owner_user_id = :u')->execute([':u' => $userId]);
            } catch (Throwable $e) {
            }
            try {
                $pdo->prepare('DELETE FROM reels WHERE owner_user_id = :u')->execute([':u' => $userId]);
            } catch (Throwable $e) {
            }
            $pdo->prepare('DELETE FROM user_session_tokens WHERE user_id = :u')->execute([':u' => $userId]);
            $pdo->prepare('DELETE FROM admin_api_tokens WHERE user_id = :u')->execute([':u' => $userId]);
            try {
                $pdo->prepare('DELETE FROM device_tokens WHERE user_id = :u')->execute([':u' => $userId]);
            } catch (Throwable $e) {
            }
            $pdo->prepare('DELETE FROM users WHERE id = :u LIMIT 1')->execute([':u' => $userId]);
        } finally {
            $pdo->exec('SET FOREIGN_KEY_CHECKS=1');
        }
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $e;
    }
}

/**
 * صيانة مؤقتة وتصفير مجمع — للمسؤول الرئيسي + رمز 1111.
 */
function admin_system_route(PDO $pdo): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $admin = require_admin_from_bearer($pdo);
    if (($admin['role'] ?? '') !== 'admin') {
        json_error(403, 'متاح للمسؤول الرئيسي فقط');
    }
    $in = read_json_body();
    $pin = trim((string) ($in['pin'] ?? ''));
    if ($pin !== '1111') {
        json_error(403, 'رمز التأكيد غير صحيح');
    }
    $action = trim((string) ($in['action'] ?? ''));
    $dataDir = dirname(__DIR__) . '/data';
    if (!is_dir($dataDir)) {
        @mkdir($dataDir, 0775, true);
    }
    $flagFile = $dataDir . '/maintenance.flag';

    if ($action === 'maintenance_on') {
        @file_put_contents($flagFile, (string) time());
        echo json_encode(['ok' => true, 'maintenance' => true], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($action === 'maintenance_off') {
        if (is_file($flagFile)) {
            @unlink($flagFile);
        }
        echo json_encode(['ok' => true, 'maintenance' => false], JSON_UNESCAPED_UNICODE);

        return;
    }
    if ($action === 'delete_all_properties') {
        try {
            $pdo->exec('SET FOREIGN_KEY_CHECKS=0');
            try {
                foreach (['reel_comments', 'reel_reactions', 'reels', 'property_media', 'properties'] as $tbl) {
                    try {
                        $pdo->exec('DELETE FROM ' . $tbl);
                    } catch (Throwable $e) {
                    }
                }
            } finally {
                $pdo->exec('SET FOREIGN_KEY_CHECKS=1');
            }
            echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            json_error(500, 'تعذر حذف المنشورات');
        }

        return;
    }
    if ($action === 'delete_all_users_except_me') {
        $keep = (string) ($admin['id'] ?? '');
        if ($keep === '') {
            json_error(400, 'معرّف المسؤول غير معروف');
        }
        try {
            $pdo->beginTransaction();
            $pdo->exec('SET FOREIGN_KEY_CHECKS=0');
            try {
                $pdo->exec('DELETE FROM chat_messages');
                $pdo->exec('DELETE FROM chat_threads');
                foreach (['reel_comments', 'reel_reactions', 'reels', 'property_media', 'properties'] as $tbl) {
                    try {
                        $pdo->exec('DELETE FROM ' . $tbl);
                    } catch (Throwable $e) {
                    }
                }
                try {
                    $pdo->exec('DELETE FROM favorites');
                } catch (Throwable $e) {
                }
                $pdo->prepare('DELETE FROM user_session_tokens WHERE user_id != :k')->execute([':k' => $keep]);
                $pdo->prepare('DELETE FROM admin_api_tokens WHERE user_id != :k')->execute([':k' => $keep]);
                try {
                    $pdo->prepare('DELETE FROM device_tokens WHERE user_id != :k')->execute([':k' => $keep]);
                } catch (Throwable $e) {
                }
                $pdo->prepare('DELETE FROM users WHERE id != :k')->execute([':k' => $keep]);
            } finally {
                $pdo->exec('SET FOREIGN_KEY_CHECKS=1');
            }
            $pdo->commit();
            echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            json_error(500, 'تعذر تصفير المستخدمين');
        }

        return;
    }

    json_error(400, 'إجراء غير معروف');
}
