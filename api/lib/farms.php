<?php
declare(strict_types=1);

function vewo_farms_ensure(PDO $pdo): bool
{
    static $ok = null;
    if ($ok !== null) {
        return $ok;
    }
    try {
        try {
            $pdo->exec('ALTER TABLE users ADD COLUMN is_farm TINYINT(1) NOT NULL DEFAULT 0');
        } catch (Throwable $e) {
        }
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farms (
              id CHAR(36) NOT NULL,
              owner_user_id CHAR(36) NOT NULL,
              name VARCHAR(255) NOT NULL,
              owner_display_name VARCHAR(255) NOT NULL DEFAULT '',
              phone VARCHAR(20) NOT NULL DEFAULT '',
              show_phone TINYINT(1) NOT NULL DEFAULT 1,
              governorate VARCHAR(100) NOT NULL DEFAULT '',
              city VARCHAR(120) NOT NULL DEFAULT '',
              district VARCHAR(120) NOT NULL DEFAULT '',
              address_line VARCHAR(500) NOT NULL DEFAULT '',
              lat DECIMAL(10,7) NULL,
              lng DECIMAL(10,7) NULL,
              description TEXT NULL,
              extra_info TEXT NULL,
              booking_terms TEXT NULL,
              cover_url VARCHAR(1000) NOT NULL DEFAULT '',
              capacity_people INT NOT NULL DEFAULT 0,
              capacity_cars INT NOT NULL DEFAULT 0,
              amenities_json TEXT NULL,
              status VARCHAR(20) NOT NULL DEFAULT 'pending',
              reject_note TEXT NULL,
              rating_avg DECIMAL(3,2) NOT NULL DEFAULT 0,
              rating_count INT NOT NULL DEFAULT 0,
              deposit_iqd BIGINT NOT NULL DEFAULT 0,
              allow_deposit TINYINT(1) NOT NULL DEFAULT 1,
              allow_full_payment TINYINT(1) NOT NULL DEFAULT 1,
              allow_pay_on_arrival TINYINT(1) NOT NULL DEFAULT 0,
              superqi_name VARCHAR(255) NOT NULL DEFAULT '',
              superqi_number VARCHAR(40) NOT NULL DEFAULT '',
              superqi_phone VARCHAR(20) NOT NULL DEFAULT '',
              superqi_notes TEXT NULL,
              hold_minutes INT NOT NULL DEFAULT 15,
              is_active TINYINT(1) NOT NULL DEFAULT 1,
              created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
              updated_at DATETIME(3) NULL,
              PRIMARY KEY (id),
              KEY idx_farms_owner (owner_user_id),
              KEY idx_farms_status (status, is_active),
              KEY idx_farms_geo (governorate, city, district)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farm_images (
              id CHAR(36) NOT NULL,
              farm_id CHAR(36) NOT NULL,
              url VARCHAR(1000) NOT NULL,
              sort_order INT NOT NULL DEFAULT 0,
              created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
              PRIMARY KEY (id),
              KEY idx_farm_images_farm (farm_id, sort_order)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farm_services (
              id CHAR(36) NOT NULL,
              farm_id CHAR(36) NOT NULL,
              name VARCHAR(180) NOT NULL,
              price_iqd BIGINT NOT NULL DEFAULT 0,
              is_active TINYINT(1) NOT NULL DEFAULT 1,
              created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
              PRIMARY KEY (id),
              KEY idx_farm_services_farm (farm_id, is_active)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farm_shifts (
              id CHAR(36) NOT NULL,
              farm_id CHAR(36) NOT NULL,
              name VARCHAR(120) NOT NULL,
              start_time CHAR(5) NOT NULL,
              end_time CHAR(5) NOT NULL,
              base_price_iqd BIGINT NOT NULL DEFAULT 0,
              available_days_json VARCHAR(80) NOT NULL DEFAULT '[0,1,2,3,4,5,6]',
              specific_date DATE NULL,
              is_active TINYINT(1) NOT NULL DEFAULT 1,
              sort_order INT NOT NULL DEFAULT 0,
              created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
              PRIMARY KEY (id),
              KEY idx_farm_shifts_farm (farm_id, is_active, sort_order)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        try {
            $pdo->exec('ALTER TABLE farm_shifts ADD COLUMN specific_date DATE NULL');
        } catch (Throwable $e) {
        }
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farm_shift_prices (
              id CHAR(36) NOT NULL,
              shift_id CHAR(36) NOT NULL,
              weekday TINYINT NOT NULL,
              price_iqd BIGINT NOT NULL,
              PRIMARY KEY (id),
              UNIQUE KEY uq_shift_weekday (shift_id, weekday)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farm_bookings (
              id CHAR(36) NOT NULL,
              public_code VARCHAR(40) NOT NULL,
              farm_id CHAR(36) NOT NULL,
              owner_user_id CHAR(36) NOT NULL,
              user_id CHAR(36) NOT NULL,
              shift_id CHAR(36) NOT NULL,
              booking_date DATE NOT NULL,
              start_time CHAR(5) NOT NULL,
              end_time CHAR(5) NOT NULL,
              people_count INT NOT NULL DEFAULT 0,
              cars_count INT NOT NULL DEFAULT 0,
              extras_json TEXT NULL,
              total_iqd BIGINT NOT NULL DEFAULT 0,
              deposit_iqd BIGINT NOT NULL DEFAULT 0,
              remaining_iqd BIGINT NOT NULL DEFAULT 0,
              paid_iqd BIGINT NOT NULL DEFAULT 0,
              payment_method VARCHAR(20) NOT NULL,
              booking_status VARCHAR(32) NOT NULL,
              payment_status VARCHAR(32) NOT NULL,
              hold_until DATETIME(3) NULL,
              slot_lock VARCHAR(80) NULL,
              reject_reason VARCHAR(80) NULL,
              reject_note TEXT NULL,
              proof_url VARCHAR(1000) NOT NULL DEFAULT '',
              created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
              updated_at DATETIME(3) NULL,
              PRIMARY KEY (id),
              UNIQUE KEY uq_farm_bookings_code (public_code),
              UNIQUE KEY uq_farm_bookings_slot (slot_lock),
              KEY idx_farm_bookings_farm_date (farm_id, booking_date, booking_status),
              KEY idx_farm_bookings_user (user_id, created_at),
              KEY idx_farm_bookings_owner (owner_user_id, booking_status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farm_reviews (
              id CHAR(36) NOT NULL,
              farm_id CHAR(36) NOT NULL,
              user_id CHAR(36) NOT NULL,
              booking_id CHAR(36) NOT NULL,
              stars TINYINT NOT NULL,
              comment TEXT NULL,
              created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
              PRIMARY KEY (id),
              UNIQUE KEY uq_farm_review_booking (booking_id),
              KEY idx_farm_reviews_farm (farm_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $pdo->exec(
            "CREATE TABLE IF NOT EXISTS farm_favorites (
              user_id CHAR(36) NOT NULL,
              farm_id CHAR(36) NOT NULL,
              created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
              PRIMARY KEY (user_id, farm_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
        );
        $ok = true;
    } catch (Throwable $e) {
        $ok = false;
    }

    return $ok;
}

function vewo_users_has_is_farm_column(PDO $pdo): bool
{
    static $has = null;
    if ($has !== null) {
        return $has;
    }
    try {
        $pdo->query('SELECT is_farm FROM users LIMIT 1');
        $has = true;
    } catch (Throwable $e) {
        $has = false;
    }

    return $has;
}

function vewo_farm_amenity_catalog(): array
{
    return [
        ['id' => 'pools', 'label' => 'المسابح', 'emoji' => '🏊', 'items' => [
            ['id' => 'pool_adult', 'label' => 'مسبح للكبار'],
            ['id' => 'pool_kids', 'label' => 'مسبح أطفال'],
            ['id' => 'pool_indoor', 'label' => 'مسبح داخلي'],
            ['id' => 'pool_outdoor', 'label' => 'مسبح خارجي'],
            ['id' => 'pool_closed', 'label' => 'مسبح مغلق'],
            ['id' => 'pool_open', 'label' => 'مسبح مكشوف'],
            ['id' => 'pool_heated', 'label' => 'مسبح مدفأ'],
            ['id' => 'pool_jacuzzi', 'label' => 'مسبح مع جاكوزي'],
            ['id' => 'pool_private', 'label' => 'مسبح خاص'],
            ['id' => 'pool_olympic', 'label' => 'مسبح أولمبي'],
        ]],
        ['id' => 'games', 'label' => 'الألعاب والترفيه', 'emoji' => '🎱', 'items' => [
            ['id' => 'billiards', 'label' => 'بليارد'],
            ['id' => 'foosball', 'label' => 'فيشة'],
            ['id' => 'table_game', 'label' => 'منضدة'],
            ['id' => 'table_tennis', 'label' => 'تنس طاولة'],
            ['id' => 'console_games', 'label' => 'بلايستيشن / Xbox'],
            ['id' => 'arcade', 'label' => 'ألعاب إلكترونية'],
            ['id' => 'trampoline', 'label' => 'ترامبولين'],
            ['id' => 'kids_games', 'label' => 'ألعاب أطفال'],
            ['id' => 'slide', 'label' => 'زحليقة'],
            ['id' => 'swings', 'label' => 'مراجيح'],
            ['id' => 'seesaw', 'label' => 'سيسو'],
            ['id' => 'sandbox', 'label' => 'رمل وألعاب أطفال'],
        ]],
        ['id' => 'sports', 'label' => 'الرياضة', 'emoji' => '⚽', 'items' => [
            ['id' => 'football_field', 'label' => 'ملعب كرة قدم'],
            ['id' => 'football_5', 'label' => 'كرة قدم خماسي'],
            ['id' => 'volleyball', 'label' => 'كرة طائرة'],
            ['id' => 'basketball', 'label' => 'ملعب كرة سلة'],
            ['id' => 'tennis_court', 'label' => 'ملعب تنس'],
            ['id' => 'badminton', 'label' => 'ريشة / بادمنتون'],
            ['id' => 'gym_equipment', 'label' => 'معدات رياضية'],
        ]],
        ['id' => 'bbq_kitchen', 'label' => 'الشواء والمطبخ', 'emoji' => '🍖', 'items' => [
            ['id' => 'bbq', 'label' => 'BBQ / باربيكيو'],
            ['id' => 'grill', 'label' => 'موقد شواء'],
            ['id' => 'kitchen_equipped', 'label' => 'مطبخ مجهز'],
            ['id' => 'outdoor_kitchen', 'label' => 'مطبخ خارجي'],
            ['id' => 'oven', 'label' => 'فرن'],
            ['id' => 'tandoor', 'label' => 'تنور'],
            ['id' => 'saj', 'label' => 'صاج'],
            ['id' => 'bbq_area', 'label' => 'منطقة شواء'],
            ['id' => 'fridge', 'label' => 'ثلاجة'],
            ['id' => 'cookware', 'label' => 'أدوات طبخ'],
        ]],
        ['id' => 'seating_area', 'label' => 'الجلسات', 'emoji' => '🌳', 'items' => [
            ['id' => 'garden', 'label' => 'حديقة'],
            ['id' => 'outdoor_seating', 'label' => 'جلسة خارجية'],
            ['id' => 'indoor_seating', 'label' => 'جلسة داخلية'],
            ['id' => 'arabic_seating', 'label' => 'جلسة عربية'],
            ['id' => 'shades', 'label' => 'مظلات'],
            ['id' => 'cabins', 'label' => 'أكواخ'],
            ['id' => 'waterfall', 'label' => 'شلال'],
            ['id' => 'fountains', 'label' => 'نوافير'],
            ['id' => 'green_space', 'label' => 'مساحات خضراء'],
            ['id' => 'orchard', 'label' => 'بستان / أشجار'],
            ['id' => 'view', 'label' => 'إطلالة'],
        ]],
        ['id' => 'stay', 'label' => 'الإقامة', 'emoji' => '🛏️', 'items' => [
            ['id' => 'bedroom', 'label' => 'غرفة نوم'],
            ['id' => 'multiple_bedrooms', 'label' => 'غرف نوم متعددة'],
            ['id' => 'master_bedroom', 'label' => 'غرفة ماستر'],
            ['id' => 'living_room', 'label' => 'صالة'],
            ['id' => 'majlis', 'label' => 'مجلس'],
            ['id' => 'bathroom', 'label' => 'حمام'],
            ['id' => 'pool_bathroom', 'label' => 'حمام سباحة'],
            ['id' => 'kitchen', 'label' => 'مطبخ'],
            ['id' => 'ac', 'label' => 'تكييف'],
            ['id' => 'heating', 'label' => 'تدفئة'],
        ]],
        ['id' => 'basics', 'label' => 'الخدمات الأساسية', 'emoji' => '🚗', 'items' => [
            ['id' => 'parking', 'label' => 'موقف سيارات'],
            ['id' => 'indoor_garage', 'label' => 'كراج داخلي'],
            ['id' => 'power_24h', 'label' => 'كهرباء 24 ساعة'],
            ['id' => 'generator', 'label' => 'مولد'],
            ['id' => 'wifi', 'label' => 'Wi-Fi'],
            ['id' => 'water', 'label' => 'ماء'],
            ['id' => 'bathrooms', 'label' => 'حمامات'],
            ['id' => 'outdoor_shower', 'label' => 'دش خارجي'],
            ['id' => 'changing_room', 'label' => 'غرفة تبديل ملابس'],
        ]],
        ['id' => 'events', 'label' => 'الترفيه والمناسبات', 'emoji' => '🎵', 'items' => [
            ['id' => 'sound_system', 'label' => 'نظام صوتي'],
            ['id' => 'speakers', 'label' => 'سماعات'],
            ['id' => 'parties', 'label' => 'إمكانية إقامة حفلات'],
            ['id' => 'birthdays', 'label' => 'إمكانية إقامة أعياد ميلاد'],
            ['id' => 'occasions', 'label' => 'إمكانية إقامة مناسبات'],
            ['id' => 'night_lighting', 'label' => 'إضاءة ليلية'],
            ['id' => 'event_space', 'label' => 'مساحة للفعاليات'],
        ]],
    ];
}

function vewo_farm_amenity_labels(): array
{
    $out = [
        'pool' => 'مسبح',
        'seating' => 'جلسات',
        'playground' => 'ملعب',
        'rooms' => 'غرف',
        'kids' => 'ألعاب أطفال',
        'cooling' => 'تبريد',
        'majles' => 'جلسات',
    ];
    foreach (vewo_farm_amenity_catalog() as $group) {
        foreach ($group['items'] as $item) {
            $out[(string) $item['id']] = (string) $item['label'];
        }
    }
    return $out;
}

function vewo_farm_default_amenities(): array
{
    return array_keys(vewo_farm_amenity_labels());
}

/** @param list<mixed> $amenities
 *  @return list<string>
 */
function vewo_farm_sanitize_amenities(array $amenities): array
{
    $allowed = vewo_farm_amenity_labels();
    $out = [];
    foreach ($amenities as $a) {
        $k = trim((string) $a);
        if ($k !== '' && isset($allowed[$k]) && !in_array($k, $out, true)) {
            $out[] = $k;
        }
    }
    return $out;
}

function vewo_farm_expire_holds(PDO $pdo): void
{
    try {
        $pdo->exec(
            "UPDATE farm_bookings
             SET booking_status = 'cancelled', payment_status = 'unpaid', slot_lock = NULL, updated_at = NOW(3),
                 reject_note = 'انتهت مهلة إكمال الحجز'
             WHERE slot_lock IS NOT NULL
               AND hold_until IS NOT NULL
               AND hold_until < NOW(3)
               AND booking_status IN ('pending','payment_pending')
               AND (proof_url IS NULL OR proof_url = '')"
        );
    } catch (Throwable $e) {
    }
}

function vewo_farm_notify(PDO $pdo, string $userId, string $title, string $body, array $data = []): void
{
    if ($userId === '') {
        return;
    }
    try {
        if (function_exists('vewo_app_notification_add')) {
            vewo_app_notification_add($pdo, $userId, (string) ($data['type'] ?? 'farm'), $title, $body, $data);
        }
        if (function_exists('vewo_device_tokens_for_user') && function_exists('vewo_fcm_send')) {
            $tokens = vewo_device_tokens_for_user($pdo, $userId, false);
            if (!empty($tokens)) {
                vewo_fcm_send($tokens, $title, $body, $data);
            }
        }
    } catch (Throwable $e) {
    }
}

function vewo_farm_seed_default_shifts(PDO $pdo, string $farmId): void
{
    $defaults = [
        ['ليلي', '23:00', '08:00', 100000, 0],
        ['مسائي', '16:00', '23:00', 75000, 1],
        ['صباحي', '08:00', '16:00', 50000, 2],
    ];
    $ins = $pdo->prepare(
        'INSERT INTO farm_shifts (id, farm_id, name, start_time, end_time, base_price_iqd, available_days_json, is_active, sort_order, created_at)
         VALUES (:id, :f, :n, :s, :e, :p, :d, 1, :o, NOW(3))'
    );
    foreach ($defaults as $row) {
        $ins->execute([
            ':id' => uuid_v4(),
            ':f' => $farmId,
            ':n' => $row[0],
            ':s' => $row[1],
            ':e' => $row[2],
            ':p' => $row[3],
            ':d' => '[0,1,2,3,4,5,6]',
            ':o' => $row[4],
        ]);
    }
}

function vewo_farm_create_for_owner(PDO $pdo, string $ownerId, array $in, string $phone = '', string $ownerName = ''): string
{
    vewo_farms_ensure($pdo);
    $id = uuid_v4();
    $name = trim((string) ($in['farm_name'] ?? $in['name'] ?? $in['office_name'] ?? ''));
    if ($name === '') {
        $name = 'مزرعة';
    }
    $amenities = $in['amenities'] ?? $in['amenities_json'] ?? [];
    if (is_string($amenities)) {
        $decoded = json_decode($amenities, true);
        $amenities = is_array($decoded) ? $decoded : [];
    }
    if (!is_array($amenities)) {
        $amenities = [];
    }
    $amenities = vewo_farm_sanitize_amenities($amenities);
    $lat = isset($in['lat']) && is_numeric($in['lat']) ? (float) $in['lat'] : (isset($in['office_lat']) && is_numeric($in['office_lat']) ? (float) $in['office_lat'] : null);
    $lng = isset($in['lng']) && is_numeric($in['lng']) ? (float) $in['lng'] : (isset($in['office_lng']) && is_numeric($in['office_lng']) ? (float) $in['office_lng'] : null);
    $images = $in['images'] ?? $in['image_urls'] ?? [];
    if (!is_array($images)) {
        $images = [];
    }
    $cover = trim((string) ($in['cover_url'] ?? $in['office_photo_url'] ?? ''));
    if ($cover === '' && isset($images[0])) {
        $cover = trim((string) $images[0]);
    }
    $pdo->prepare(
        'INSERT INTO farms (id, owner_user_id, name, owner_display_name, phone, show_phone, governorate, city, district, address_line, lat, lng,
            description, extra_info, booking_terms, cover_url, capacity_people, capacity_cars, amenities_json, status, deposit_iqd,
            allow_deposit, allow_full_payment, allow_pay_on_arrival, is_active, created_at)
         VALUES (:id, :oid, :n, :on, :ph, :sp, :g, :c, :d, :a, :la, :ln, :ds, :ex, :bt, :cv, :cp, :cc, :am, :st, :dep, 1, 1, 0, 1, NOW(3))'
    )->execute([
        ':id' => $id,
        ':oid' => $ownerId,
        ':n' => $name,
        ':on' => trim((string) ($in['owner_display_name'] ?? $ownerName)),
        ':ph' => trim((string) ($in['farm_phone'] ?? $in['phone'] ?? $phone)),
        ':sp' => !isset($in['show_phone']) || !empty($in['show_phone']) ? 1 : 0,
        ':g' => trim((string) ($in['governorate'] ?? '')),
        ':c' => trim((string) ($in['city'] ?? '')),
        ':d' => trim((string) ($in['district'] ?? $in['area'] ?? '')),
        ':a' => trim((string) ($in['address_line'] ?? $in['office_address'] ?? '')),
        ':la' => $lat,
        ':ln' => $lng,
        ':ds' => trim((string) ($in['description'] ?? '')),
        ':ex' => trim((string) ($in['extra_info'] ?? '')),
        ':bt' => trim((string) ($in['booking_terms'] ?? '')),
        ':cv' => $cover,
        ':cp' => max(0, (int) ($in['capacity_people'] ?? 0)),
        ':cc' => max(0, (int) ($in['capacity_cars'] ?? 0)),
        ':am' => json_encode($amenities, JSON_UNESCAPED_UNICODE),
        ':st' => 'pending',
        ':dep' => max(0, (int) ($in['deposit_iqd'] ?? 50000)),
    ]);
    $imgStmt = $pdo->prepare('INSERT INTO farm_images (id, farm_id, url, sort_order, created_at) VALUES (:id, :f, :u, :s, NOW(3))');
    $i = 0;
    foreach ($images as $url) {
        $url = trim((string) $url);
        if ($url === '') {
            continue;
        }
        $imgStmt->execute([':id' => uuid_v4(), ':f' => $id, ':u' => $url, ':s' => $i]);
        $i++;
    }
    if ($cover !== '' && $i === 0) {
        $imgStmt->execute([':id' => uuid_v4(), ':f' => $id, ':u' => $cover, ':s' => 0]);
    }
    vewo_farm_seed_default_shifts($pdo, $id);

    return $id;
}

function vewo_farm_fetch(PDO $pdo, string $id): ?array
{
    $stmt = $pdo->prepare('SELECT * FROM farms WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $id]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    return is_array($row) ? $row : null;
}

function vewo_farm_owner_row(PDO $pdo, string $userId): ?array
{
    $stmt = $pdo->prepare('SELECT * FROM farms WHERE owner_user_id = :u ORDER BY created_at DESC LIMIT 1');
    $stmt->execute([':u' => $userId]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    return is_array($row) ? $row : null;
}

function vewo_farm_shift_days(array $shift): array
{
    $raw = json_decode((string) ($shift['available_days_json'] ?? '[]'), true);
    if (!is_array($raw) || $raw === []) {
        return [0, 1, 2, 3, 4, 5, 6];
    }

    return array_values(array_map('intval', $raw));
}

function vewo_farm_shift_specific_date(array $shift): string
{
    $d = substr(trim((string) ($shift['specific_date'] ?? '')), 0, 10);
    if ($d === '' || $d === '0000-00-00' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $d)) {
        return '';
    }

    return $d;
}

function vewo_farm_shift_applies_on(array $shift, string $date): bool
{
    $specific = vewo_farm_shift_specific_date($shift);
    if ($specific !== '') {
        return $specific === $date;
    }
    $w = (int) date('w', strtotime($date . ' 12:00:00'));

    return in_array($w, vewo_farm_shift_days($shift), true);
}

function vewo_farm_format_time12(string $hhmm): string
{
    $hhmm = substr(trim($hhmm), 0, 5);
    $parts = explode(':', $hhmm);
    if (count($parts) < 2) {
        return $hhmm;
    }
    $h = (int) $parts[0];
    $m = str_pad((string) ((int) $parts[1]), 2, '0', STR_PAD_LEFT);
    $ampm = $h >= 12 ? 'مساءً' : 'صباحاً';
    $h12 = $h % 12;
    if ($h12 === 0) {
        $h12 = 12;
    }

    return $h12 . ':' . $m . ' ' . $ampm;
}

/** الليلي أولاً ثم المسائي ثم الصباحي. */
function vewo_farm_shift_sort_rank(array $shift): int
{
    $name = (string) ($shift['name'] ?? '');
    $start = (string) ($shift['start_time'] ?? '');
    $end = (string) ($shift['end_time'] ?? '');
    if (str_contains($name, 'ليل') || ($start !== '' && $end !== '' && $start > $end) || $start >= '18:00') {
        return 0;
    }
    if ($start >= '12:00' || str_contains($name, 'مساء')) {
        return 1;
    }

    return 2;
}

function vewo_farm_shift_public_row(array $sh, int $price, int $available, string $status): array
{
    $start = (string) ($sh['start_time'] ?? '');
    $end = (string) ($sh['end_time'] ?? '');

    return [
        'id' => (string) ($sh['id'] ?? ''),
        'name' => (string) ($sh['name'] ?? ''),
        'start_time' => $start,
        'end_time' => $end,
        'start_time_12' => vewo_farm_format_time12($start),
        'end_time_12' => vewo_farm_format_time12($end),
        'price_iqd' => $price,
        'available' => $available,
        'status' => $status,
        'specific_date' => vewo_farm_shift_specific_date($sh),
        'sort_order' => (int) ($sh['sort_order'] ?? 0),
    ];
}

function vewo_farm_hhmm(mixed $t): string
{
    $s = trim((string) $t);
    if (preg_match('/^(\d{1,2}):(\d{2})/', $s, $m)) {
        return str_pad($m[1], 2, '0', STR_PAD_LEFT) . ':' . $m[2];
    }
    return substr($s, 0, 5);
}

function vewo_farm_json_out(array $payload): void
{
    while (ob_get_level() > 0) {
        @ob_end_clean();
    }
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
        http_response_code(200);
    }
    $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if (!is_string($json) || $json === '') {
        $json = '{"ok":false,"error":"تعذر تجهيز الاستجابة"}';
    }
    echo $json;
    exit;
}

function vewo_farm_price_for_date(PDO $pdo, array $shift, string $date): int
{
    $w = (int) date('w', strtotime($date . ' 12:00:00'));
    $stmt = $pdo->prepare('SELECT price_iqd FROM farm_shift_prices WHERE shift_id = :s AND weekday = :w LIMIT 1');
    $stmt->execute([':s' => $shift['id'], ':w' => $w]);
    $p = $stmt->fetchColumn();
    if ($p !== false && $p !== null && $p !== '') {
        return (int) $p;
    }

    return (int) ($shift['base_price_iqd'] ?? 0);
}

function vewo_farm_slot_taken(PDO $pdo, string $farmId, string $shiftId, string $date, ?string $exceptBookingId = null): bool
{
    vewo_farm_expire_holds($pdo);
    $sql = "SELECT id FROM farm_bookings
            WHERE farm_id = :f AND shift_id = :s AND booking_date = :d
              AND slot_lock IS NOT NULL
              AND booking_status NOT IN ('cancelled','rejected')
              AND (hold_until IS NULL OR hold_until > NOW(3) OR booking_status IN ('payment_proof_uploaded','awaiting_confirmation','confirmed','completed'))";
    $params = [':f' => $farmId, ':s' => $shiftId, ':d' => $date];
    if ($exceptBookingId) {
        $sql .= ' AND id <> :ex';
        $params[':ex'] = $exceptBookingId;
    }
    $sql .= ' LIMIT 1';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    return (bool) $stmt->fetchColumn();
}

function vewo_farm_json(PDO $pdo, array $farm, bool $public = true, ?string $viewerId = null): array
{
    $id = (string) $farm['id'];
    $imgs = $pdo->prepare('SELECT id, url, sort_order FROM farm_images WHERE farm_id = :f ORDER BY sort_order ASC, created_at ASC');
    $imgs->execute([':f' => $id]);
    $images = $imgs->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $shifts = $pdo->prepare('SELECT * FROM farm_shifts WHERE farm_id = :f ORDER BY sort_order ASC, created_at ASC');
    $shifts->execute([':f' => $id]);
    $shiftRows = $shifts->fetchAll(PDO::FETCH_ASSOC) ?: [];
    usort($shiftRows, static function (array $a, array $b): int {
        $ra = vewo_farm_shift_sort_rank($a);
        $rb = vewo_farm_shift_sort_rank($b);
        if ($ra !== $rb) {
            return $ra <=> $rb;
        }

        return ((int) ($a['sort_order'] ?? 0)) <=> ((int) ($b['sort_order'] ?? 0));
    });
    $svc = $pdo->prepare('SELECT * FROM farm_services WHERE farm_id = :f ORDER BY created_at ASC');
    $svc->execute([':f' => $id]);
    $services = $svc->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $amen = json_decode((string) ($farm['amenities_json'] ?? '[]'), true);
    if (!is_array($amen)) {
        $amen = [];
    }
    $fav = 0;
    if ($viewerId) {
        $fs = $pdo->prepare('SELECT 1 FROM farm_favorites WHERE user_id = :u AND farm_id = :f LIMIT 1');
        $fs->execute([':u' => $viewerId, ':f' => $id]);
        $fav = $fs->fetchColumn() ? 1 : 0;
    }
    $minPrice = null;
    foreach ($shiftRows as $sh) {
        if ((int) ($sh['is_active'] ?? 0) !== 1) {
            continue;
        }
        $p = (int) ($sh['base_price_iqd'] ?? 0);
        if ($minPrice === null || $p < $minPrice) {
            $minPrice = $p;
        }
    }
    $status = (string) ($farm['status'] ?? 'pending');
    $available = $status === 'approved' && (int) ($farm['is_active'] ?? 0) === 1;
    $out = [
        'id' => $id,
        'name' => (string) $farm['name'],
        'owner_display_name' => (string) ($farm['owner_display_name'] ?? ''),
        'governorate' => (string) ($farm['governorate'] ?? ''),
        'city' => (string) ($farm['city'] ?? ''),
        'district' => (string) ($farm['district'] ?? ''),
        'address_line' => (string) ($farm['address_line'] ?? ''),
        'lat' => $farm['lat'] === null ? null : (float) $farm['lat'],
        'lng' => $farm['lng'] === null ? null : (float) $farm['lng'],
        'description' => (string) ($farm['description'] ?? ''),
        'extra_info' => (string) ($farm['extra_info'] ?? ''),
        'booking_terms' => (string) ($farm['booking_terms'] ?? ''),
        'cover_url' => (string) ($farm['cover_url'] ?? ''),
        'images' => array_values(array_map(static fn ($r) => [
            'id' => (string) ($r['id'] ?? ''),
            'url' => (string) ($r['url'] ?? ''),
        ], $images)),
        'capacity_people' => (int) ($farm['capacity_people'] ?? 0),
        'capacity_cars' => (int) ($farm['capacity_cars'] ?? 0),
        'amenities' => array_values($amen),
        'amenity_labels' => vewo_farm_amenity_labels(),
        'amenity_catalog' => vewo_farm_amenity_catalog(),
        'status' => $status,
        'reject_note' => $public && $status !== 'rejected' ? '' : (string) ($farm['reject_note'] ?? ''),
        'rating_avg' => (float) ($farm['rating_avg'] ?? 0),
        'rating_count' => (int) ($farm['rating_count'] ?? 0),
        'price_from' => $minPrice ?? 0,
        'available' => $available ? 1 : 0,
        'deposit_iqd' => (int) ($farm['deposit_iqd'] ?? 0),
        'allow_deposit' => (int) ($farm['allow_deposit'] ?? 0) === 1 ? 1 : 0,
        'allow_full_payment' => (int) ($farm['allow_full_payment'] ?? 0) === 1 ? 1 : 0,
        'allow_pay_on_arrival' => (int) ($farm['allow_pay_on_arrival'] ?? 0) === 1 ? 1 : 0,
        'is_favorite' => $fav,
        'shifts' => [],
        'services' => array_values(array_map(static fn ($s) => [
            'id' => (string) $s['id'],
            'name' => (string) $s['name'],
            'price_iqd' => (int) $s['price_iqd'],
            'is_active' => (int) $s['is_active'] === 1 ? 1 : 0,
        ], $services)),
        'created_at' => (string) ($farm['created_at'] ?? ''),
    ];
    if (!empty($farm['show_phone'])) {
        $out['phone'] = (string) ($farm['phone'] ?? '');
    } else {
        $out['phone'] = '';
    }
    $priceStmt = $pdo->prepare('SELECT weekday, price_iqd FROM farm_shift_prices WHERE shift_id = :s');
    foreach ($shiftRows as $sh) {
        $priceStmt->execute([':s' => $sh['id']]);
        $dayPrices = [];
        foreach ($priceStmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $pr) {
            $dayPrices[(string) $pr['weekday']] = (int) $pr['price_iqd'];
        }
        $out['shifts'][] = [
            'id' => (string) $sh['id'],
            'name' => (string) $sh['name'],
            'start_time' => (string) $sh['start_time'],
            'end_time' => (string) $sh['end_time'],
            'start_time_12' => vewo_farm_format_time12((string) $sh['start_time']),
            'end_time_12' => vewo_farm_format_time12((string) $sh['end_time']),
            'base_price_iqd' => (int) $sh['base_price_iqd'],
            'available_days' => vewo_farm_shift_days($sh),
            'specific_date' => vewo_farm_shift_specific_date($sh),
            'is_active' => (int) $sh['is_active'] === 1 ? 1 : 0,
            'sort_order' => (int) $sh['sort_order'],
            'day_prices' => $dayPrices,
        ];
    }
    if (!$public) {
        $out['owner_user_id'] = (string) $farm['owner_user_id'];
        $out['show_phone'] = (int) ($farm['show_phone'] ?? 1);
        $out['phone'] = (string) ($farm['phone'] ?? '');
        $out['superqi_name'] = (string) ($farm['superqi_name'] ?? '');
        $out['superqi_number'] = (string) ($farm['superqi_number'] ?? '');
        $out['superqi_phone'] = (string) ($farm['superqi_phone'] ?? '');
        $out['superqi_notes'] = (string) ($farm['superqi_notes'] ?? '');
        $out['hold_minutes'] = (int) ($farm['hold_minutes'] ?? 15);
        $out['is_active'] = (int) ($farm['is_active'] ?? 1);
    } else {
        $out['superqi_name'] = (string) ($farm['superqi_name'] ?? '');
        $out['superqi_number'] = (string) ($farm['superqi_number'] ?? '');
        $out['superqi_phone'] = (string) ($farm['superqi_phone'] ?? '');
        $out['superqi_notes'] = (string) ($farm['superqi_notes'] ?? '');
    }

    return $out;
}

function vewo_farm_booking_json(PDO $pdo, array $b, bool $ownerView = false): array
{
    $farm = vewo_farm_fetch($pdo, (string) $b['farm_id']) ?? [];
    $customerPhone = '';
    $customerName = '';
    if ($ownerView) {
        $u = $pdo->prepare('SELECT phone, full_name FROM users WHERE id = :id LIMIT 1');
        $u->execute([':id' => $b['user_id']]);
        $urow = $u->fetch(PDO::FETCH_ASSOC) ?: [];
        $customerPhone = (string) ($urow['phone'] ?? '');
        $customerName = (string) ($urow['full_name'] ?? '');
    }
    $shiftName = '';
    $ss = $pdo->prepare('SELECT name FROM farm_shifts WHERE id = :id LIMIT 1');
    $ss->execute([':id' => $b['shift_id']]);
    $shiftName = (string) ($ss->fetchColumn() ?: '');
    $extrasRaw = json_decode((string) ($b['extras_json'] ?? '[]'), true);
    if (!is_array($extrasRaw)) {
        $extrasRaw = [];
    }
    $extras = $extrasRaw;
    $guestName = '';
    $guestPhone = '';
    $createdByOwner = false;
    $note = '';
    if (isset($extrasRaw['services']) && is_array($extrasRaw['services'])) {
        $extras = $extrasRaw['services'];
        $guestName = trim((string) ($extrasRaw['guest_name'] ?? ''));
        $guestPhone = trim((string) ($extrasRaw['guest_phone'] ?? ''));
        $createdByOwner = !empty($extrasRaw['created_by_owner']);
        $note = trim((string) ($extrasRaw['note'] ?? ''));
    }
    if ($guestName !== '') {
        $customerName = $guestName;
    }
    if ($guestPhone !== '') {
        $customerPhone = $guestPhone;
    }
    $wa = preg_replace('/\D+/', '', $customerPhone);
    if (str_starts_with((string) $wa, '0')) {
        $wa = '964' . substr((string) $wa, 1);
    } elseif ($wa !== '' && !str_starts_with((string) $wa, '964')) {
        $wa = '964' . $wa;
    }

    return [
        'id' => (string) $b['id'],
        'public_code' => (string) $b['public_code'],
        'farm_id' => (string) $b['farm_id'],
        'farm_name' => (string) ($farm['name'] ?? ''),
        'farm_cover_url' => (string) ($farm['cover_url'] ?? ''),
        'shift_id' => (string) $b['shift_id'],
        'shift_name' => $shiftName,
        'booking_date' => (string) $b['booking_date'],
        'start_time' => (string) $b['start_time'],
        'end_time' => (string) $b['end_time'],
        'start_time_12' => vewo_farm_format_time12((string) $b['start_time']),
        'end_time_12' => vewo_farm_format_time12((string) $b['end_time']),
        'people_count' => (int) $b['people_count'],
        'cars_count' => (int) $b['cars_count'],
        'extras' => $extras,
        'total_iqd' => (int) $b['total_iqd'],
        'deposit_iqd' => (int) $b['deposit_iqd'],
        'remaining_iqd' => (int) $b['remaining_iqd'],
        'paid_iqd' => (int) $b['paid_iqd'],
        'payment_method' => (string) $b['payment_method'],
        'booking_status' => (string) $b['booking_status'],
        'payment_status' => (string) $b['payment_status'],
        'hold_until' => (string) ($b['hold_until'] ?? ''),
        'reject_reason' => (string) ($b['reject_reason'] ?? ''),
        'reject_note' => (string) ($b['reject_note'] ?? ''),
        'proof_url' => (string) ($b['proof_url'] ?? ''),
        'created_at' => (string) ($b['created_at'] ?? ''),
        'customer_name' => $ownerView ? $customerName : '',
        'customer_phone' => $ownerView ? $customerPhone : '',
        'customer_whatsapp' => $ownerView ? $wa : '',
        'created_by_owner' => $createdByOwner ? 1 : 0,
        'note' => $note,
        'superqi_number' => (string) ($farm['superqi_number'] ?? ''),
        'superqi_name' => (string) ($farm['superqi_name'] ?? ''),
        'superqi_phone' => (string) ($farm['superqi_phone'] ?? ''),
        'superqi_notes' => (string) ($farm['superqi_notes'] ?? ''),
    ];
}

function farms_dispatch_route(PDO $pdo, array $config, string $route): void
{
    try {
        if (!vewo_farms_ensure($pdo)) {
            json_error(503, 'تعذر تهيئة جداول المزارع — نفّذ patch_farms_booking_mysql.sql');
        }
        switch ($route) {
        case 'farms/list':
            farms_public_list_route($pdo);
            return;
        case 'farms/get':
            farms_public_get_route($pdo);
            return;
        case 'farms/availability':
            farms_availability_route($pdo);
            return;
        case 'farms/upload':
            farms_upload_route($pdo, $config);
            return;
        case 'farms/mine':
            farms_owner_mine_route($pdo);
            return;
        case 'farms/save':
            farms_owner_save_route($pdo);
            return;
        case 'farms/shifts':
            farms_owner_shifts_route($pdo);
            return;
        case 'farms/services':
            farms_owner_services_route($pdo);
            return;
        case 'farms/payment-settings':
            farms_owner_payment_settings_route($pdo);
            return;
        case 'farms/favorite':
            farms_favorite_route($pdo);
            return;
        case 'farms/favorites':
            farms_favorites_list_route($pdo);
            return;
        case 'farms/book':
            farms_book_route($pdo);
            return;
        case 'farms/booking/proof':
            farms_booking_proof_route($pdo, $config);
            return;
        case 'farms/booking/cancel':
            farms_booking_cancel_route($pdo);
            return;
        case 'farms/booking/review':
            farms_booking_review_route($pdo);
            return;
        case 'farms/my-bookings':
            farms_my_bookings_route($pdo);
            return;
        case 'farms/owner/bookings':
            farms_owner_bookings_route($pdo);
            return;
        case 'farms/owner/decide':
            farms_owner_decide_route($pdo);
            return;
        case 'farms/owner/book':
            farms_owner_book_route($pdo);
            return;
        case 'farms/owner/dashboard':
            farms_owner_dashboard_route($pdo);
            return;
        case 'admin/farms':
            admin_farms_route($pdo);
            return;
        case 'admin/farm-bookings':
            admin_farm_bookings_route($pdo);
            return;
        default:
            json_error(404, 'Route not found: ' . $route);
        }
    } catch (Throwable $e) {
        error_log('farms dispatch ' . $route . ': ' . $e->getMessage());
        json_error(500, 'تعذر إتمام الطلب');
    }
}

function farms_public_list_route(PDO $pdo): void
{
    $me = null;
    try {
        $hdr = (string) ($_SERVER['HTTP_AUTHORIZATION'] ?? '');
        if ($hdr !== '') {
            $me = require_auth_user($pdo);
        }
    } catch (Throwable $e) {
        $me = null;
    }
    $q = trim((string) ($_GET['q'] ?? ''));
    $gov = trim((string) ($_GET['governorate'] ?? ''));
    $city = trim((string) ($_GET['city'] ?? ''));
    $district = trim((string) ($_GET['district'] ?? ''));
    $amenity = trim((string) ($_GET['amenity'] ?? ''));
    $minPeople = (int) ($_GET['min_people'] ?? 0);
    $minPrice = isset($_GET['min_price']) ? (int) $_GET['min_price'] : null;
    $maxPrice = isset($_GET['max_price']) ? (int) $_GET['max_price'] : null;
    $sort = trim((string) ($_GET['sort'] ?? 'newest'));
    $date = trim((string) ($_GET['date'] ?? ''));
    $sql = "SELECT f.* FROM farms f WHERE f.status = 'approved' AND f.is_active = 1";
    $params = [];
    if ($gov !== '') {
        $sql .= ' AND f.governorate = :g';
        $params[':g'] = $gov;
    }
    if ($city !== '') {
        $sql .= ' AND f.city = :c';
        $params[':c'] = $city;
    }
    if ($district !== '') {
        $sql .= ' AND f.district = :d';
        $params[':d'] = $district;
    }
    if ($q !== '') {
        $sql .= ' AND (f.name LIKE :q OR f.district LIKE :q OR f.city LIKE :q OR f.address_line LIKE :q)';
        $params[':q'] = '%' . $q . '%';
    }
    if ($minPeople > 0) {
        $sql .= ' AND f.capacity_people >= :mp';
        $params[':mp'] = $minPeople;
    }
    $order = match ($sort) {
        'price_asc' => '(SELECT MIN(base_price_iqd) FROM farm_shifts s WHERE s.farm_id = f.id AND s.is_active = 1) ASC',
        'price_desc' => '(SELECT MIN(base_price_iqd) FROM farm_shifts s WHERE s.farm_id = f.id AND s.is_active = 1) DESC',
        'rating' => 'f.rating_avg DESC, f.rating_count DESC',
        default => 'f.created_at DESC',
    };
    $sql .= ' ORDER BY ' . $order . ' LIMIT 200';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC) ?: [];
    $viewer = is_array($me) ? (string) ($me['id'] ?? '') : null;
    $items = [];
    foreach ($rows as $row) {
        $item = vewo_farm_json($pdo, $row, true, $viewer);
        if ($amenity !== '' && !in_array($amenity, $item['amenities'], true)) {
            continue;
        }
        if ($minPrice !== null && (int) $item['price_from'] < $minPrice) {
            continue;
        }
        if ($maxPrice !== null && (int) $item['price_from'] > $maxPrice) {
            continue;
        }
        if ($date !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
            $any = false;
            foreach ($item['shifts'] as $sh) {
                if ((int) $sh['is_active'] !== 1) {
                    continue;
                }
                $w = (int) date('w', strtotime($date . ' 12:00:00'));
                if (!in_array($w, $sh['available_days'], true)) {
                    continue;
                }
                if (!vewo_farm_slot_taken($pdo, $item['id'], $sh['id'], $date)) {
                    $any = true;
                    break;
                }
            }
            if (!$any) {
                continue;
            }
        }
        $items[] = $item;
    }
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}

function farms_public_get_route(PDO $pdo): void
{
    $id = trim((string) ($_GET['id'] ?? ''));
    if ($id === '') {
        json_error(400, 'id مطلوب');
    }
    $farm = vewo_farm_fetch($pdo, $id);
    if ($farm === null) {
        json_error(404, 'المزرعة غير موجودة');
    }
    $me = null;
    try {
        if (trim((string) ($_SERVER['HTTP_AUTHORIZATION'] ?? '')) !== '') {
            $me = require_auth_user($pdo);
        }
    } catch (Throwable $e) {
    }
    $isOwner = is_array($me) && (string) ($me['id'] ?? '') === (string) $farm['owner_user_id'];
    $isAdmin = is_array($me) && in_array((string) ($me['role'] ?? ''), ['admin', 'staff'], true);
    if ((string) $farm['status'] !== 'approved' && !$isOwner && !$isAdmin) {
        json_error(404, 'المزرعة غير متاحة');
    }
    $item = vewo_farm_json($pdo, $farm, !$isOwner && !$isAdmin, is_array($me) ? (string) $me['id'] : null);
    echo json_encode(['ok' => true, 'item' => $item], JSON_UNESCAPED_UNICODE);
}

function farms_availability_route(PDO $pdo): void
{
    $farmId = trim((string) ($_GET['farm_id'] ?? $_GET['id'] ?? ''));
    $date = trim((string) ($_GET['date'] ?? ''));
    if ($farmId === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        json_error(400, 'المزرعة والتاريخ مطلوبان');
    }
    if ($date < date('Y-m-d')) {
        echo json_encode(['ok' => true, 'date' => $date, 'shifts' => []], JSON_UNESCAPED_UNICODE);
        return;
    }
    $farm = vewo_farm_fetch($pdo, $farmId);
    if ($farm === null || (string) $farm['status'] !== 'approved' || (int) $farm['is_active'] !== 1) {
        json_error(404, 'المزرعة غير متاحة للحجز');
    }
    vewo_farm_expire_holds($pdo);
    $stmt = $pdo->prepare('SELECT * FROM farm_shifts WHERE farm_id = :f AND is_active = 1');
    $stmt->execute([':f' => $farmId]);
    $out = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $sh) {
        if (!vewo_farm_shift_applies_on($sh, $date)) {
            continue;
        }
        $taken = vewo_farm_slot_taken($pdo, $farmId, (string) $sh['id'], $date);
        $price = vewo_farm_price_for_date($pdo, $sh, $date);
        $ended = false;
        if ($date === date('Y-m-d')) {
            $end = (string) $sh['end_time'];
            $start = (string) $sh['start_time'];
            if ($start < $end && date('H:i') >= $end) {
                $ended = true;
            }
        }
        $out[] = vewo_farm_shift_public_row(
            $sh,
            $price,
            (!$taken && !$ended) ? 1 : 0,
            $taken ? 'booked' : ($ended ? 'ended' : 'available')
        );
    }
    usort($out, static function (array $a, array $b): int {
        $ra = vewo_farm_shift_sort_rank($a);
        $rb = vewo_farm_shift_sort_rank($b);
        if ($ra !== $rb) {
            return $ra <=> $rb;
        }

        return ((int) ($a['sort_order'] ?? 0)) <=> ((int) ($b['sort_order'] ?? 0));
    });
    vewo_farm_json_out(['ok' => true, 'date' => $date, 'shifts' => $out]);
}

function farms_upload_route(PDO $pdo, array $config): void
{
    require_auth_user($pdo);
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $file = vewo_first_uploaded_file();
    if (!is_array($file) || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        json_error(400, 'اختر صورة');
    }
    $tmp = (string) ($file['tmp_name'] ?? '');
    if ($tmp === '' || !is_file($tmp)) {
        json_error(400, 'اختر صورة');
    }
    $name = strtolower((string) ($file['name'] ?? ''));
    $ext = pathinfo($name, PATHINFO_EXTENSION);
    if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true)) {
        json_error(400, 'الصيغ المسموحة: JPG, PNG, WebP');
    }
    $mime = (string) ($file['type'] ?? 'image/jpeg');
    $kind = trim((string) ($_POST['kind'] ?? 'farms'));
    $folder = $kind === 'proof' ? 'farm_payments' : 'farms';
    $stored = vewo_store_uploaded_file($config, $tmp, $mime, $ext, $folder);
    echo json_encode(['ok' => true, 'url' => $stored['public_url'], 'public_url' => $stored['public_url']], JSON_UNESCAPED_UNICODE);
}

function farms_owner_mine_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        echo json_encode(['ok' => true, 'item' => null], JSON_UNESCAPED_UNICODE);
        return;
    }
    echo json_encode(['ok' => true, 'item' => vewo_farm_json($pdo, $farm, false, (string) $me['id'])], JSON_UNESCAPED_UNICODE);
}

function farms_owner_save_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $in = read_json_body();
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        $id = vewo_farm_create_for_owner($pdo, (string) $me['id'], $in, (string) ($me['phone'] ?? ''), (string) ($me['full_name'] ?? ''));
        if (function_exists('vewo_fcm_notify_admins')) {
            vewo_fcm_notify_admins($pdo, 'طلب مزرعة جديد', trim((string) ($in['name'] ?? 'مزرعة')) . ' بانتظار المراجعة', [
                'type' => 'farm_pending', 'section' => 'farms', 'farm_id' => $id,
            ]);
        }
        $farm = vewo_farm_fetch($pdo, $id);
        echo json_encode(['ok' => true, 'item' => vewo_farm_json($pdo, $farm, false)], JSON_UNESCAPED_UNICODE);
        return;
    }
    $id = (string) $farm['id'];
    $status = (string) $farm['status'];
    $amenities = $in['amenities'] ?? null;
    $amSql = '';
    $params = [
        ':n' => trim((string) ($in['name'] ?? $farm['name'])),
        ':on' => trim((string) ($in['owner_display_name'] ?? $farm['owner_display_name'])),
        ':ph' => trim((string) ($in['phone'] ?? $farm['phone'])),
        ':sp' => isset($in['show_phone']) ? (!empty($in['show_phone']) ? 1 : 0) : (int) $farm['show_phone'],
        ':g' => trim((string) ($in['governorate'] ?? $farm['governorate'])),
        ':c' => trim((string) ($in['city'] ?? $farm['city'])),
        ':d' => trim((string) ($in['district'] ?? $farm['district'])),
        ':a' => trim((string) ($in['address_line'] ?? $farm['address_line'])),
        ':ds' => trim((string) ($in['description'] ?? $farm['description'])),
        ':ex' => trim((string) ($in['extra_info'] ?? $farm['extra_info'])),
        ':bt' => trim((string) ($in['booking_terms'] ?? $farm['booking_terms'])),
        ':cv' => trim((string) ($in['cover_url'] ?? $farm['cover_url'])),
        ':cp' => (int) ($in['capacity_people'] ?? $farm['capacity_people']),
        ':cc' => (int) ($in['capacity_cars'] ?? $farm['capacity_cars']),
        ':id' => $id,
    ];
    if (is_array($amenities)) {
        $amenities = vewo_farm_sanitize_amenities($amenities);
        $amSql = ', amenities_json = :am';
        $params[':am'] = json_encode($amenities, JSON_UNESCAPED_UNICODE);
    }
    $latSql = '';
    if (isset($in['lat']) && isset($in['lng']) && is_numeric($in['lat']) && is_numeric($in['lng'])) {
        $latSql = ', lat = :la, lng = :ln';
        $params[':la'] = (float) $in['lat'];
        $params[':ln'] = (float) $in['lng'];
    }
    $reopen = '';
    if (in_array($status, ['rejected', 'pending'], true) && !empty($in['resubmit'])) {
        $reopen = ", status = 'pending', reject_note = NULL";
    }
    $pdo->prepare(
        "UPDATE farms SET name = :n, owner_display_name = :on, phone = :ph, show_phone = :sp, governorate = :g, city = :c, district = :d,
         address_line = :a, description = :ds, extra_info = :ex, booking_terms = :bt, cover_url = :cv, capacity_people = :cp, capacity_cars = :cc,
         updated_at = NOW(3){$amSql}{$latSql}{$reopen} WHERE id = :id LIMIT 1"
    )->execute($params);
    if (isset($in['images']) && is_array($in['images'])) {
        $pdo->prepare('DELETE FROM farm_images WHERE farm_id = :f')->execute([':f' => $id]);
        $imgStmt = $pdo->prepare('INSERT INTO farm_images (id, farm_id, url, sort_order, created_at) VALUES (:id, :f, :u, :s, NOW(3))');
        $i = 0;
        foreach ($in['images'] as $url) {
            $url = trim((string) $url);
            if ($url === '') {
                continue;
            }
            $imgStmt->execute([':id' => uuid_v4(), ':f' => $id, ':u' => $url, ':s' => $i]);
            $i++;
        }
    }
    $farm = vewo_farm_fetch($pdo, $id);
    echo json_encode(['ok' => true, 'item' => vewo_farm_json($pdo, $farm, false)], JSON_UNESCAPED_UNICODE);
}

function farms_owner_shifts_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        json_error(404, 'لا توجد مزرعة');
    }
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'GET') {
        echo json_encode(['ok' => true, 'item' => vewo_farm_json($pdo, $farm, false)], JSON_UNESCAPED_UNICODE);
        return;
    }
    $in = read_json_body();
    $action = trim((string) ($in['action'] ?? 'upsert'));
    $farmId = (string) $farm['id'];
    if ($action === 'delete') {
        $sid = trim((string) ($in['id'] ?? ''));
        $pdo->prepare('DELETE FROM farm_shift_prices WHERE shift_id = :id')->execute([':id' => $sid]);
        $pdo->prepare('DELETE FROM farm_shifts WHERE id = :id AND farm_id = :f LIMIT 1')->execute([':id' => $sid, ':f' => $farmId]);
        echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
        return;
    }
    $sid = trim((string) ($in['id'] ?? ''));
    $name = trim((string) ($in['name'] ?? ''));
    $start = trim((string) ($in['start_time'] ?? ''));
    $end = trim((string) ($in['end_time'] ?? ''));
    if (preg_match('/^(\d{1,2}):(\d{2})/', $start, $m)) {
        $start = str_pad($m[1], 2, '0', STR_PAD_LEFT) . ':' . $m[2];
    }
    if (preg_match('/^(\d{1,2}):(\d{2})/', $end, $m)) {
        $end = str_pad($m[1], 2, '0', STR_PAD_LEFT) . ':' . $m[2];
    }
    if ($name === '' || !preg_match('/^\d{2}:\d{2}$/', $start) || !preg_match('/^\d{2}:\d{2}$/', $end)) {
        json_error(400, 'اسم الشفت والوقت مطلوبان');
    }
    $days = $in['available_days'] ?? [0, 1, 2, 3, 4, 5, 6];
    if (!is_array($days)) {
        $days = [0, 1, 2, 3, 4, 5, 6];
    }
    $days = array_values(array_unique(array_map('intval', $days)));
    $specific = trim((string) ($in['specific_date'] ?? ''));
    if ($specific !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $specific)) {
        json_error(400, 'تاريخ الشفت غير صالح');
    }
    if ($specific !== '') {
        $days = [];
    }
    $price = max(0, (int) ($in['base_price_iqd'] ?? 0));
    $active = isset($in['is_active']) ? ((int) $in['is_active'] === 1 ? 1 : 0) : 1;
    $sort = isset($in['sort_order'])
        ? (int) $in['sort_order']
        : vewo_farm_shift_sort_rank(['name' => $name, 'start_time' => $start, 'end_time' => $end]);
    if ($sid === '') {
        $sid = uuid_v4();
        $pdo->prepare(
            'INSERT INTO farm_shifts (id, farm_id, name, start_time, end_time, base_price_iqd, available_days_json, specific_date, is_active, sort_order, created_at)
             VALUES (:id, :f, :n, :s, :e, :p, :d, :sd, :a, :o, NOW(3))'
        )->execute([
            ':id' => $sid, ':f' => $farmId, ':n' => $name, ':s' => $start, ':e' => $end,
            ':p' => $price, ':d' => json_encode($days), ':sd' => ($specific === '' ? null : $specific),
            ':a' => $active, ':o' => $sort,
        ]);
    } else {
        $pdo->prepare(
            'UPDATE farm_shifts SET name = :n, start_time = :s, end_time = :e, base_price_iqd = :p, available_days_json = :d, specific_date = :sd, is_active = :a, sort_order = :o
             WHERE id = :id AND farm_id = :f LIMIT 1'
        )->execute([
            ':n' => $name, ':s' => $start, ':e' => $end, ':p' => $price, ':d' => json_encode($days),
            ':sd' => ($specific === '' ? null : $specific),
            ':a' => $active, ':o' => $sort, ':id' => $sid, ':f' => $farmId,
        ]);
    }
    if (isset($in['day_prices']) && is_array($in['day_prices'])) {
        $pdo->prepare('DELETE FROM farm_shift_prices WHERE shift_id = :s')->execute([':s' => $sid]);
        $ps = $pdo->prepare('INSERT INTO farm_shift_prices (id, shift_id, weekday, price_iqd) VALUES (:id, :s, :w, :p)');
        foreach ($in['day_prices'] as $w => $p) {
            $ps->execute([':id' => uuid_v4(), ':s' => $sid, ':w' => (int) $w, ':p' => max(0, (int) $p)]);
        }
    }
    echo json_encode(['ok' => true, 'id' => $sid], JSON_UNESCAPED_UNICODE);
}

function farms_owner_services_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        json_error(404, 'لا توجد مزرعة');
    }
    $in = read_json_body();
    $action = trim((string) ($in['action'] ?? 'upsert'));
    $farmId = (string) $farm['id'];
    if ($action === 'delete') {
        $pdo->prepare('DELETE FROM farm_services WHERE id = :id AND farm_id = :f LIMIT 1')->execute([
            ':id' => trim((string) ($in['id'] ?? '')), ':f' => $farmId,
        ]);
        echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
        return;
    }
    $sid = trim((string) ($in['id'] ?? ''));
    $name = trim((string) ($in['name'] ?? ''));
    if ($name === '') {
        json_error(400, 'اسم الخدمة مطلوب');
    }
    $price = max(0, (int) ($in['price_iqd'] ?? 0));
    $active = isset($in['is_active']) ? ((int) $in['is_active'] === 1 ? 1 : 0) : 1;
    if ($sid === '') {
        $sid = uuid_v4();
        $pdo->prepare('INSERT INTO farm_services (id, farm_id, name, price_iqd, is_active, created_at) VALUES (:id, :f, :n, :p, :a, NOW(3))')
            ->execute([':id' => $sid, ':f' => $farmId, ':n' => $name, ':p' => $price, ':a' => $active]);
    } else {
        $pdo->prepare('UPDATE farm_services SET name = :n, price_iqd = :p, is_active = :a WHERE id = :id AND farm_id = :f LIMIT 1')
            ->execute([':n' => $name, ':p' => $price, ':a' => $active, ':id' => $sid, ':f' => $farmId]);
    }
    echo json_encode(['ok' => true, 'id' => $sid], JSON_UNESCAPED_UNICODE);
}

function farms_owner_payment_settings_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        json_error(404, 'لا توجد مزرعة');
    }
    $in = read_json_body();
    $pdo->prepare(
        'UPDATE farms SET deposit_iqd = :dep, allow_deposit = :ad, allow_full_payment = :af, allow_pay_on_arrival = :ao,
         superqi_name = :sn, superqi_number = :sq, superqi_phone = :sp, superqi_notes = :nt, updated_at = NOW(3)
         WHERE id = :id LIMIT 1'
    )->execute([
        ':dep' => max(0, (int) ($in['deposit_iqd'] ?? $farm['deposit_iqd'])),
        ':ad' => !empty($in['allow_deposit']) || !array_key_exists('allow_deposit', $in) && (int) $farm['allow_deposit'] === 1 ? 1 : (!empty($in['allow_deposit']) ? 1 : 0),
        ':af' => array_key_exists('allow_full_payment', $in) ? (!empty($in['allow_full_payment']) ? 1 : 0) : (int) $farm['allow_full_payment'],
        ':ao' => array_key_exists('allow_pay_on_arrival', $in) ? (!empty($in['allow_pay_on_arrival']) ? 1 : 0) : (int) $farm['allow_pay_on_arrival'],
        ':sn' => trim((string) ($in['superqi_name'] ?? $farm['superqi_name'])),
        ':sq' => trim((string) ($in['superqi_number'] ?? $farm['superqi_number'])),
        ':sp' => trim((string) ($in['superqi_phone'] ?? $farm['superqi_phone'])),
        ':nt' => trim((string) ($in['superqi_notes'] ?? $farm['superqi_notes'])),
        ':id' => $farm['id'],
    ]);
    if (array_key_exists('allow_deposit', $in)) {
        $pdo->prepare('UPDATE farms SET allow_deposit = :v WHERE id = :id')->execute([
            ':v' => !empty($in['allow_deposit']) ? 1 : 0, ':id' => $farm['id'],
        ]);
    }
    $farm = vewo_farm_fetch($pdo, (string) $farm['id']);
    echo json_encode(['ok' => true, 'item' => vewo_farm_json($pdo, $farm, false)], JSON_UNESCAPED_UNICODE);
}

function farms_favorite_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $farmId = trim((string) ($in['farm_id'] ?? $_GET['farm_id'] ?? ''));
    if ($farmId === '') {
        json_error(400, 'farm_id مطلوب');
    }
    $exists = $pdo->prepare('SELECT 1 FROM farm_favorites WHERE user_id = :u AND farm_id = :f LIMIT 1');
    $exists->execute([':u' => $me['id'], ':f' => $farmId]);
    if ($exists->fetchColumn()) {
        $pdo->prepare('DELETE FROM farm_favorites WHERE user_id = :u AND farm_id = :f')->execute([':u' => $me['id'], ':f' => $farmId]);
        echo json_encode(['ok' => true, 'is_favorite' => 0], JSON_UNESCAPED_UNICODE);
        return;
    }
    $pdo->prepare('INSERT INTO farm_favorites (user_id, farm_id, created_at) VALUES (:u, :f, NOW(3))')->execute([':u' => $me['id'], ':f' => $farmId]);
    echo json_encode(['ok' => true, 'is_favorite' => 1], JSON_UNESCAPED_UNICODE);
}

function farms_favorites_list_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $stmt = $pdo->prepare(
        "SELECT f.* FROM farm_favorites fav INNER JOIN farms f ON f.id = fav.farm_id
         WHERE fav.user_id = :u AND f.status = 'approved' AND f.is_active = 1 ORDER BY fav.created_at DESC"
    );
    $stmt->execute([':u' => $me['id']]);
    $items = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $row) {
        $items[] = vewo_farm_json($pdo, $row, true, (string) $me['id']);
    }
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}

function farms_next_code(PDO $pdo, string $date): string
{
    $prefix = 'FARM-' . str_replace('-', '', $date) . '-';
    $stmt = $pdo->prepare('SELECT public_code FROM farm_bookings WHERE public_code LIKE :p ORDER BY public_code DESC LIMIT 1');
    $stmt->execute([':p' => $prefix . '%']);
    $last = (string) ($stmt->fetchColumn() ?: '');
    $n = 1;
    if ($last !== '' && preg_match('/-(\d+)$/', $last, $m)) {
        $n = (int) $m[1] + 1;
    }

    return $prefix . str_pad((string) $n, 5, '0', STR_PAD_LEFT);
}

function farms_book_route(PDO $pdo): void
{
    try {
    $me = require_auth_user($pdo);
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $in = read_json_body();
    $farmId = trim((string) ($in['farm_id'] ?? ''));
    $shiftId = trim((string) ($in['shift_id'] ?? ''));
    $date = trim((string) ($in['booking_date'] ?? $in['date'] ?? ''));
    $method = trim((string) ($in['payment_method'] ?? ''));
    if ($farmId === '' || $shiftId === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        json_error(400, 'بيانات الحجز غير مكتملة');
    }
    if ($date < date('Y-m-d')) {
        json_error(400, 'لا يمكن حجز تاريخ سابق');
    }
    $farm = vewo_farm_fetch($pdo, $farmId);
    if ($farm === null || (string) $farm['status'] !== 'approved' || (int) $farm['is_active'] !== 1) {
        json_error(400, 'المزرعة غير متاحة للحجز');
    }
    $sh = $pdo->prepare('SELECT * FROM farm_shifts WHERE id = :id AND farm_id = :f AND is_active = 1 LIMIT 1');
    $sh->execute([':id' => $shiftId, ':f' => $farmId]);
    $shift = $sh->fetch(PDO::FETCH_ASSOC);
    if (!is_array($shift)) {
        json_error(400, 'الشفت غير متاح');
    }
    if (!vewo_farm_shift_applies_on($shift, $date)) {
        json_error(400, 'هذا الشفت غير متاح في هذا اليوم');
    }
    if ($date === date('Y-m-d')) {
        $end = (string) $shift['end_time'];
        $start = (string) $shift['start_time'];
        if ($start < $end && date('H:i') >= $end) {
            json_error(400, 'هذا الشفت انتهى اليوم');
        }
    }
    $allowed = [];
    if ((int) $farm['allow_deposit'] === 1) {
        $allowed[] = 'deposit';
    }
    if ((int) $farm['allow_full_payment'] === 1) {
        $allowed[] = 'full';
    }
    if ((int) $farm['allow_pay_on_arrival'] === 1) {
        $allowed[] = 'on_arrival';
    }
    if ($allowed === []) {
        $allowed[] = 'on_arrival';
        if ($method === '') {
            $method = 'on_arrival';
        }
    }
    if ($method === '' && $allowed !== []) {
        $method = $allowed[0];
    }
    if (!in_array($method, $allowed, true)) {
        json_error(400, 'طريقة الدفع غير متاحة لهذه المزرعة');
    }
    $people = max(0, (int) ($in['people_count'] ?? 0));
    $cars = max(0, (int) ($in['cars_count'] ?? 0));
    if ((int) $farm['capacity_people'] > 0 && $people > (int) $farm['capacity_people']) {
        json_error(400, 'عدد الأشخاص يتجاوز سعة المزرعة');
    }
    $extraIds = $in['service_ids'] ?? [];
    if (!is_array($extraIds)) {
        $extraIds = [];
    }
    $extras = [];
    $extraTotal = 0;
    if ($extraIds !== []) {
        $inQ = implode(',', array_fill(0, count($extraIds), '?'));
        $st = $pdo->prepare("SELECT id, name, price_iqd FROM farm_services WHERE farm_id = ? AND is_active = 1 AND id IN ($inQ)");
        $st->execute(array_merge([$farmId], array_map('strval', $extraIds)));
        foreach ($st->fetchAll(PDO::FETCH_ASSOC) ?: [] as $sv) {
            $extras[] = ['id' => $sv['id'], 'name' => $sv['name'], 'price_iqd' => (int) $sv['price_iqd']];
            $extraTotal += (int) $sv['price_iqd'];
        }
    }
    $base = vewo_farm_price_for_date($pdo, $shift, $date);
    $total = $base + $extraTotal;
    $deposit = 0;
    $remaining = $total;
    $paid = 0;
    if ($method === 'deposit') {
        $deposit = min($total, max(0, (int) $farm['deposit_iqd']));
        if ($deposit <= 0) {
            json_error(400, 'قيمة العربون غير محددة');
        }
        $remaining = max(0, $total - $deposit);
    } elseif ($method === 'full') {
        $deposit = $total;
        $remaining = 0;
    }
    $holdMin = max(5, (int) ($farm['hold_minutes'] ?? 15));
    $pdo->beginTransaction();
    try {
        vewo_farm_expire_holds($pdo);
        $pdo->exec('SELECT id FROM farm_bookings WHERE farm_id = ' . $pdo->quote($farmId) . ' FOR UPDATE');
        if (vewo_farm_slot_taken($pdo, $farmId, $shiftId, $date)) {
            $pdo->rollBack();
            json_error(409, 'هذا الشفت محجوز في التاريخ المحدد');
        }
        $id = uuid_v4();
        $code = farms_next_code($pdo, $date);
        $slot = $farmId . '|' . $shiftId . '|' . $date;
        $bStatus = $method === 'on_arrival' ? 'awaiting_confirmation' : 'payment_pending';
        $pStatus = $method === 'on_arrival' ? 'pay_on_arrival' : 'unpaid';
        $hold = $method === 'on_arrival' ? null : date('Y-m-d H:i:s', time() + $holdMin * 60);
        $pdo->prepare(
            'INSERT INTO farm_bookings (id, public_code, farm_id, owner_user_id, user_id, shift_id, booking_date, start_time, end_time,
             people_count, cars_count, extras_json, total_iqd, deposit_iqd, remaining_iqd, paid_iqd, payment_method, booking_status, payment_status,
             hold_until, slot_lock, created_at)
             VALUES (:id, :c, :f, :o, :u, :s, :d, :st, :en, :pe, :ca, :ex, :t, :dep, :rem, :pd, :pm, :bs, :ps, :h, :sl, NOW(3))'
        )->execute([
            ':id' => $id, ':c' => $code, ':f' => $farmId, ':o' => $farm['owner_user_id'], ':u' => $me['id'], ':s' => $shiftId,
        ':d' => $date, ':st' => vewo_farm_hhmm($shift['start_time']), ':en' => vewo_farm_hhmm($shift['end_time']), ':pe' => $people, ':ca' => $cars,
            ':ex' => json_encode($extras, JSON_UNESCAPED_UNICODE), ':t' => $total, ':dep' => $deposit, ':rem' => $remaining,
            ':pd' => $paid, ':pm' => $method, ':bs' => $bStatus, ':ps' => $pStatus, ':h' => $hold, ':sl' => $slot,
        ]);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        $dup = str_contains($e->getMessage(), 'uq_farm_bookings_slot');
        if ($e instanceof PDOException && (int) ($e->errorInfo[1] ?? 0) === 1062) {
            $dup = true;
        }
        if ($dup) {
            json_error(409, 'هذا الشفت محجوز في التاريخ المحدد');
        }
        error_log('farms/book insert: ' . $e->getMessage());
        json_error(500, 'تعذر إنشاء الحجز');
    }
    $item = [
        'id' => $id,
        'public_code' => $code,
        'farm_id' => $farmId,
        'booking_date' => $date,
        'booking_status' => $bStatus,
        'payment_status' => $pStatus,
        'total_iqd' => $total,
        'deposit_iqd' => $deposit,
        'remaining_iqd' => $remaining,
        'payment_method' => $method,
        'start_time' => vewo_farm_hhmm($shift['start_time']),
        'end_time' => vewo_farm_hhmm($shift['end_time']),
        'start_time_12' => vewo_farm_format_time12((string) $shift['start_time']),
        'end_time_12' => vewo_farm_format_time12((string) $shift['end_time']),
        'shift_id' => $shiftId,
        'shift_name' => (string) ($shift['name'] ?? ''),
        'farm_name' => (string) ($farm['name'] ?? ''),
    ];
    try {
        $row = $pdo->prepare('SELECT * FROM farm_bookings WHERE id = :id');
        $row->execute([':id' => $id]);
        $booking = $row->fetch(PDO::FETCH_ASSOC);
        if (is_array($booking)) {
            $item = vewo_farm_booking_json($pdo, $booking, false);
        }
    } catch (Throwable $e) {
        error_log('farms/book json: ' . $e->getMessage());
    }
    try {
        vewo_farm_notify($pdo, (string) $me['id'], 'تم إنشاء حجزك الأولي بنجاح', 'رقم الحجز ' . $code, [
            'type' => 'farm_booking_created', 'booking_id' => $id, 'section' => 'farms',
        ]);
        vewo_farm_notify($pdo, (string) $farm['owner_user_id'], 'لديك حجز جديد بانتظار المراجعة', $code . ' — ' . (string) $farm['name'], [
            'type' => 'farm_booking_new', 'booking_id' => $id, 'section' => 'farms',
        ]);
        if (function_exists('vewo_fcm_notify_admins')) {
            vewo_fcm_notify_admins($pdo, 'حجز مزرعة جديد', $code, ['type' => 'farm_booking_pending', 'section' => 'farms', 'booking_id' => $id]);
        }
    } catch (Throwable $e) {
    }
    vewo_farm_json_out(['ok' => true, 'item' => $item]);
    } catch (Throwable $e) {
        error_log('farms/book: ' . $e->getMessage());
        json_error(500, 'تعذر إنشاء الحجز');
    }
}

function farms_booking_proof_route(PDO $pdo, array $config): void
{
    $me = require_auth_user($pdo);
    $bookingId = trim((string) ($_POST['booking_id'] ?? $_GET['booking_id'] ?? ''));
    $url = trim((string) ($_POST['proof_url'] ?? ''));
    if ($bookingId === '') {
        $in = read_json_body();
        $bookingId = trim((string) ($in['booking_id'] ?? ''));
        $url = trim((string) ($in['proof_url'] ?? $url));
    }
    if ($bookingId === '') {
        json_error(400, 'booking_id مطلوب');
    }
    $stmt = $pdo->prepare('SELECT * FROM farm_bookings WHERE id = :id AND user_id = :u LIMIT 1');
    $stmt->execute([':id' => $bookingId, ':u' => $me['id']]);
    $b = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($b)) {
        json_error(404, 'الحجز غير موجود');
    }
    if (!in_array((string) $b['booking_status'], ['pending', 'payment_pending', 'payment_proof_uploaded', 'awaiting_confirmation'], true)) {
        json_error(400, 'لا يمكن رفع إثبات لهذا الحجز');
    }
    if ((string) $b['payment_method'] === 'on_arrival') {
        json_error(400, 'هذا الحجز يدفع عند الوصول');
    }
    $file = $_FILES['file'] ?? $_FILES['image'] ?? null;
    if (is_array($file) && (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
        $tmp = (string) $file['tmp_name'];
        $ext = strtolower(pathinfo((string) $file['name'], PATHINFO_EXTENSION));
        if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true)) {
            json_error(400, 'الصيغ المسموحة: JPG, PNG, WebP');
        }
        $stored = vewo_store_uploaded_file($config, $tmp, (string) ($file['type'] ?? 'image/jpeg'), $ext, 'farm_payments');
        $url = $stored['public_url'];
    }
    if ($url === '') {
        json_error(400, 'ارفع صورة إثبات التحويل');
    }
    $pdo->prepare(
        "UPDATE farm_bookings SET proof_url = :u, booking_status = 'payment_proof_uploaded', payment_status = 'awaiting_review',
         hold_until = NULL, updated_at = NOW(3) WHERE id = :id LIMIT 1"
    )->execute([':u' => $url, ':id' => $bookingId]);
    $stmt->execute([':id' => $bookingId, ':u' => $me['id']]);
    $b = $stmt->fetch(PDO::FETCH_ASSOC);
    vewo_farm_notify($pdo, (string) $me['id'], 'تم إرسال إثبات الدفع وبانتظار مراجعة صاحب المزرعة', (string) $b['public_code'], [
        'type' => 'farm_proof_uploaded', 'booking_id' => $bookingId,
    ]);
    vewo_farm_notify($pdo, (string) $b['owner_user_id'], 'تم رفع إثبات دفع جديد', (string) $b['public_code'], [
        'type' => 'farm_proof_new', 'booking_id' => $bookingId,
    ]);
    echo json_encode(['ok' => true, 'item' => vewo_farm_booking_json($pdo, $b, false)], JSON_UNESCAPED_UNICODE);
}

function farms_booking_cancel_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $id = trim((string) ($in['booking_id'] ?? $in['id'] ?? ''));
    $stmt = $pdo->prepare('SELECT * FROM farm_bookings WHERE id = :id AND user_id = :u LIMIT 1');
    $stmt->execute([':id' => $id, ':u' => $me['id']]);
    $b = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($b)) {
        json_error(404, 'الحجز غير موجود');
    }
    if (in_array((string) $b['booking_status'], ['cancelled', 'completed', 'rejected'], true)) {
        json_error(400, 'لا يمكن إلغاء هذا الحجز');
    }
    $pdo->prepare("UPDATE farm_bookings SET booking_status = 'cancelled', slot_lock = NULL, updated_at = NOW(3) WHERE id = :id LIMIT 1")
        ->execute([':id' => $id]);
    vewo_farm_notify($pdo, (string) $b['owner_user_id'], 'تم إلغاء أحد الحجوزات', (string) $b['public_code'], [
        'type' => 'farm_booking_cancelled', 'booking_id' => $id,
    ]);
    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
}

function farms_booking_review_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $id = trim((string) ($in['booking_id'] ?? ''));
    $stars = (int) ($in['stars'] ?? 0);
    $comment = trim((string) ($in['comment'] ?? ''));
    if ($stars < 1 || $stars > 5) {
        json_error(400, 'التقييم من 1 إلى 5');
    }
    $stmt = $pdo->prepare("SELECT * FROM farm_bookings WHERE id = :id AND user_id = :u AND booking_status = 'completed' LIMIT 1");
    $stmt->execute([':id' => $id, ':u' => $me['id']]);
    $b = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($b)) {
        json_error(400, 'يمكن التقييم بعد اكتمال الحجز فقط');
    }
    try {
        $pdo->prepare('INSERT INTO farm_reviews (id, farm_id, user_id, booking_id, stars, comment, created_at) VALUES (:id, :f, :u, :b, :s, :c, NOW(3))')
            ->execute([':id' => uuid_v4(), ':f' => $b['farm_id'], ':u' => $me['id'], ':b' => $id, ':s' => $stars, ':c' => $comment]);
    } catch (Throwable $e) {
        json_error(409, 'تم تقييم هذا الحجز مسبقاً');
    }
    $agg = $pdo->prepare('SELECT AVG(stars), COUNT(*) FROM farm_reviews WHERE farm_id = :f');
    $agg->execute([':f' => $b['farm_id']]);
    $row = $agg->fetch(PDO::FETCH_NUM) ?: [0, 0];
    $pdo->prepare('UPDATE farms SET rating_avg = :a, rating_count = :c WHERE id = :id')->execute([
        ':a' => round((float) $row[0], 2), ':c' => (int) $row[1], ':id' => $b['farm_id'],
    ]);
    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
}

function farms_my_bookings_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    vewo_farm_expire_holds($pdo);
    $status = trim((string) ($_GET['status'] ?? ''));
    $sql = 'SELECT * FROM farm_bookings WHERE user_id = :u';
    $params = [':u' => $me['id']];
    if ($status !== '' && $status !== 'all') {
        $map = [
            'pending' => ['pending', 'payment_pending'],
            'awaiting' => ['payment_proof_uploaded', 'awaiting_confirmation'],
            'confirmed' => ['confirmed'],
            'completed' => ['completed'],
            'cancelled' => ['cancelled', 'rejected'],
        ];
        $set = $map[$status] ?? [$status];
        $inQ = implode(',', array_fill(0, count($set), '?'));
        $sql = "SELECT * FROM farm_bookings WHERE user_id = ? AND booking_status IN ($inQ)";
        $params = array_merge([(string) $me['id']], $set);
        $stmt = $pdo->prepare($sql . ' ORDER BY created_at DESC LIMIT 200');
        $stmt->execute($params);
    } else {
        $stmt = $pdo->prepare($sql . ' ORDER BY created_at DESC LIMIT 200');
        $stmt->execute($params);
    }
    $items = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $row) {
        $items[] = vewo_farm_booking_json($pdo, $row, false);
    }
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}

function farms_owner_bookings_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        json_error(404, 'لا توجد مزرعة');
    }
    vewo_farm_expire_holds($pdo);
    $stmt = $pdo->prepare('SELECT * FROM farm_bookings WHERE farm_id = :f ORDER BY created_at DESC LIMIT 300');
    $stmt->execute([':f' => $farm['id']]);
    $items = [];
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: [] as $row) {
        $items[] = vewo_farm_booking_json($pdo, $row, true);
    }
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}

function farms_owner_book_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        json_error(405, 'Method not allowed');
    }
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        json_error(404, 'لا توجد مزرعة مرتبطة بهذا الحساب');
    }
    if ((string) ($farm['status'] ?? '') !== 'approved' || (int) ($farm['is_active'] ?? 1) !== 1) {
        json_error(400, 'المزرعة بانتظار موافقة الإدارة قبل تسجيل الحجوزات');
    }
    $in = read_json_body();
    $farmId = (string) $farm['id'];
    $shiftId = trim((string) ($in['shift_id'] ?? ''));
    $date = trim((string) ($in['booking_date'] ?? $in['date'] ?? ''));
    if ($shiftId === '' || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) {
        json_error(400, 'حدد الشفت وتاريخ الحجز');
    }
    $sh = $pdo->prepare('SELECT * FROM farm_shifts WHERE id = :id AND farm_id = :f AND is_active = 1 LIMIT 1');
    $sh->execute([':id' => $shiftId, ':f' => $farmId]);
    $shift = $sh->fetch(PDO::FETCH_ASSOC);
    if (!is_array($shift)) {
        json_error(400, 'الشفت غير متاح');
    }
    if (!vewo_farm_shift_applies_on($shift, $date)) {
        json_error(400, 'هذا الشفت غير متاح في هذا اليوم — أضف الشفت أولاً');
    }
    $guestName = trim((string) ($in['guest_name'] ?? $in['customer_name'] ?? ''));
    $guestPhone = trim((string) ($in['guest_phone'] ?? $in['customer_phone'] ?? ''));
    if ($guestName === '' || preg_replace('/\D+/', '', $guestPhone) === '') {
        json_error(400, 'أدخل اسم الزبون وهاتفه — لا يُسمح بحجز وهمي');
    }
    $note = trim((string) ($in['note'] ?? ''));
    $people = max(0, (int) ($in['people_count'] ?? 0));
    $cars = max(0, (int) ($in['cars_count'] ?? 0));
    $base = vewo_farm_price_for_date($pdo, $shift, $date);
    $pdo->beginTransaction();
    try {
        vewo_farm_expire_holds($pdo);
        $pdo->exec('SELECT id FROM farm_bookings WHERE farm_id = ' . $pdo->quote($farmId) . ' FOR UPDATE');
        if (vewo_farm_slot_taken($pdo, $farmId, $shiftId, $date)) {
            $pdo->rollBack();
            json_error(409, 'هذا الشفت محجوز في التاريخ المحدد');
        }
        $id = uuid_v4();
        $code = farms_next_code($pdo, $date);
        $slot = $farmId . '|' . $shiftId . '|' . $date;
        $extrasPayload = [
            'services' => [],
            'guest_name' => $guestName,
            'guest_phone' => $guestPhone,
            'created_by_owner' => 1,
            'note' => $note,
        ];
        $pdo->prepare(
            'INSERT INTO farm_bookings (id, public_code, farm_id, owner_user_id, user_id, shift_id, booking_date, start_time, end_time,
             people_count, cars_count, extras_json, total_iqd, deposit_iqd, remaining_iqd, paid_iqd, payment_method, booking_status, payment_status,
             hold_until, slot_lock, created_at)
             VALUES (:id, :c, :f, :o, :u, :s, :d, :st, :en, :pe, :ca, :ex, :t, 0, :t2, 0, :pm, :bs, :ps, NULL, :sl, NOW(3))'
        )->execute([
            ':id' => $id,
            ':c' => $code,
            ':f' => $farmId,
            ':o' => $farm['owner_user_id'],
            ':u' => $me['id'],
            ':s' => $shiftId,
            ':d' => $date,
            ':st' => vewo_farm_hhmm($shift['start_time']),
            ':en' => vewo_farm_hhmm($shift['end_time']),
            ':pe' => $people,
            ':ca' => $cars,
            ':ex' => json_encode($extrasPayload, JSON_UNESCAPED_UNICODE),
            ':t' => $base,
            ':t2' => $base,
            ':pm' => 'on_arrival',
            ':bs' => 'confirmed',
            ':ps' => 'pay_on_arrival',
            ':sl' => $slot,
        ]);
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        $dup = str_contains($e->getMessage(), 'uq_farm_bookings_slot');
        if ($e instanceof PDOException && (int) ($e->errorInfo[1] ?? 0) === 1062) {
            $dup = true;
        }
        if ($dup) {
            json_error(409, 'هذا الشفت محجوز في التاريخ المحدد');
        }
        json_error(500, 'تعذر إنشاء الحجز');
    }
    $row = $pdo->prepare('SELECT * FROM farm_bookings WHERE id = :id');
    $row->execute([':id' => $id]);
    $booking = $row->fetch(PDO::FETCH_ASSOC);
    vewo_farm_json_out([
        'ok' => true,
        'item' => is_array($booking) ? vewo_farm_booking_json($pdo, $booking, true) : ['id' => $id, 'public_code' => $code],
    ]);
}

function farms_owner_decide_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $in = read_json_body();
    $id = trim((string) ($in['booking_id'] ?? ''));
    $decision = trim((string) ($in['decision'] ?? $in['action'] ?? ''));
    $stmt = $pdo->prepare('SELECT * FROM farm_bookings WHERE id = :id AND owner_user_id = :o LIMIT 1');
    $stmt->execute([':id' => $id, ':o' => $me['id']]);
    $b = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!is_array($b)) {
        json_error(404, 'الحجز غير موجود');
    }
    if ($decision === 'confirm' || $decision === 'accept') {
        $pStatus = (string) $b['payment_method'] === 'full' ? 'paid_in_full'
            : ((string) $b['payment_method'] === 'deposit' ? 'deposit_paid' : 'pay_on_arrival');
        $paid = (string) $b['payment_method'] === 'on_arrival' ? 0 : (int) $b['deposit_iqd'];
        $pdo->prepare(
            "UPDATE farm_bookings SET booking_status = 'confirmed', payment_status = :ps, paid_iqd = :pd, hold_until = NULL, updated_at = NOW(3)
             WHERE id = :id LIMIT 1"
        )->execute([':ps' => $pStatus, ':pd' => $paid, ':id' => $id]);
        vewo_farm_notify($pdo, (string) $b['user_id'], 'تم تأكيد حجزك نهائياً', (string) $b['public_code'], [
            'type' => 'farm_booking_confirmed', 'booking_id' => $id,
        ]);
    } elseif ($decision === 'reject') {
        $reason = trim((string) ($in['reject_reason'] ?? 'other'));
        $note = trim((string) ($in['reject_note'] ?? ''));
        $pdo->prepare(
            "UPDATE farm_bookings SET booking_status = 'rejected', payment_status = 'rejected', slot_lock = NULL,
             reject_reason = :r, reject_note = :n, updated_at = NOW(3) WHERE id = :id LIMIT 1"
        )->execute([':r' => $reason, ':n' => $note, ':id' => $id]);
        vewo_farm_notify($pdo, (string) $b['user_id'], 'تم رفض الحجز', $note !== '' ? $note : 'راجع تفاصيل الحجز', [
            'type' => 'farm_booking_rejected', 'booking_id' => $id, 'reason' => $reason,
        ]);
    } elseif ($decision === 'complete') {
        $pdo->prepare("UPDATE farm_bookings SET booking_status = 'completed', updated_at = NOW(3) WHERE id = :id AND owner_user_id = :o LIMIT 1")
            ->execute([':id' => $id, ':o' => $me['id']]);
    } else {
        json_error(400, 'قرار غير صالح');
    }
    $stmt->execute([':id' => $id, ':o' => $me['id']]);
    $b = $stmt->fetch(PDO::FETCH_ASSOC);
    echo json_encode(['ok' => true, 'item' => vewo_farm_booking_json($pdo, $b, true)], JSON_UNESCAPED_UNICODE);
}

function farms_owner_dashboard_route(PDO $pdo): void
{
    $me = require_auth_user($pdo);
    $farm = vewo_farm_owner_row($pdo, (string) $me['id']);
    if ($farm === null) {
        echo json_encode(['ok' => true, 'item' => null, 'stats' => []], JSON_UNESCAPED_UNICODE);
        return;
    }
    vewo_farm_expire_holds($pdo);
    $fid = (string) $farm['id'];
    $q = static function (PDO $pdo, string $sql, array $p = []) {
        $s = $pdo->prepare($sql);
        $s->execute($p);
        return $s->fetchColumn();
    };
    $today = date('Y-m-d');
    $stats = [
        'today' => (int) $q($pdo, "SELECT COUNT(*) FROM farm_bookings WHERE farm_id = :f AND booking_date = :d AND booking_status NOT IN ('cancelled','rejected')", [':f' => $fid, ':d' => $today]),
        'upcoming' => (int) $q($pdo, "SELECT COUNT(*) FROM farm_bookings WHERE farm_id = :f AND booking_date >= :d AND booking_status = 'confirmed'", [':f' => $fid, ':d' => $today]),
        'pending' => (int) $q($pdo, "SELECT COUNT(*) FROM farm_bookings WHERE farm_id = :f AND booking_status IN ('pending','payment_pending','payment_proof_uploaded','awaiting_confirmation')", [':f' => $fid]),
        'confirmed' => (int) $q($pdo, "SELECT COUNT(*) FROM farm_bookings WHERE farm_id = :f AND booking_status = 'confirmed'", [':f' => $fid]),
        'cancelled' => (int) $q($pdo, "SELECT COUNT(*) FROM farm_bookings WHERE farm_id = :f AND booking_status IN ('cancelled','rejected')", [':f' => $fid]),
        'revenue_month' => (int) $q($pdo, "SELECT COALESCE(SUM(paid_iqd),0) FROM farm_bookings WHERE farm_id = :f AND booking_status IN ('confirmed','completed') AND created_at >= DATE_FORMAT(NOW(), '%Y-%m-01')", [':f' => $fid]),
        'revenue_day' => (int) $q($pdo, "SELECT COALESCE(SUM(paid_iqd),0) FROM farm_bookings WHERE farm_id = :f AND booking_status IN ('confirmed','completed') AND booking_date = :d", [':f' => $fid, ':d' => $today]),
        'top_shift' => (string) ($q($pdo, "SELECT s.name FROM farm_bookings b INNER JOIN farm_shifts s ON s.id = b.shift_id WHERE b.farm_id = :f AND b.booking_status IN ('confirmed','completed') GROUP BY b.shift_id ORDER BY COUNT(*) DESC LIMIT 1", [':f' => $fid]) ?: ''),
    ];
    echo json_encode(['ok' => true, 'item' => vewo_farm_json($pdo, $farm, false), 'stats' => $stats], JSON_UNESCAPED_UNICODE);
}

function admin_farms_route(PDO $pdo): void
{
    require_admin_from_bearer($pdo);
    if (function_exists('vewo_require_admin_permission')) {
        vewo_require_admin_permission($pdo, 'offices');
    }
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    if ($method === 'GET') {
        $scope = trim((string) ($_GET['scope'] ?? 'pending'));
        $sql = 'SELECT * FROM farms';
        if ($scope === 'pending') {
            $sql .= " WHERE status = 'pending'";
        } elseif ($scope === 'approved') {
            $sql .= " WHERE status = 'approved'";
        } elseif ($scope === 'rejected') {
            $sql .= " WHERE status = 'rejected'";
        } elseif ($scope === 'suspended') {
            $sql .= " WHERE status IN ('suspended','closed')";
        } elseif ($scope === 'bookings') {
            echo json_encode(['ok' => true, 'items' => []], JSON_UNESCAPED_UNICODE);
            return;
        }
        $sql .= ' ORDER BY created_at DESC LIMIT 300';
        $stmt = $pdo->query($sql);
        $items = [];
        foreach ($stmt !== false ? ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) : [] as $row) {
            $items[] = vewo_farm_json($pdo, $row, false);
        }
        echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
        return;
    }
    $in = read_json_body();
    $action = trim((string) ($in['action'] ?? 'approve'));
    $id = trim((string) ($in['farm_id'] ?? $in['id'] ?? ''));
    $farm = vewo_farm_fetch($pdo, $id);
    if ($farm === null) {
        json_error(404, 'المزرعة غير موجودة');
    }
    if ($action === 'approve') {
        $pdo->prepare("UPDATE farms SET status = 'approved', is_active = 1, reject_note = NULL, updated_at = NOW(3) WHERE id = :id LIMIT 1")->execute([':id' => $id]);
        $pdo->prepare('UPDATE users SET office_approved = 1 WHERE id = :id LIMIT 1')->execute([':id' => $farm['owner_user_id']]);
        vewo_farm_notify($pdo, (string) $farm['owner_user_id'], 'تمت الموافقة على مزرعتك', (string) $farm['name'], ['type' => 'farm_approved', 'farm_id' => $id]);
    } elseif ($action === 'reject') {
        $note = trim((string) ($in['reject_note'] ?? ''));
        if ($note === '') {
            json_error(400, 'سبب الرفض مطلوب');
        }
        $pdo->prepare("UPDATE farms SET status = 'rejected', reject_note = :n, updated_at = NOW(3) WHERE id = :id LIMIT 1")->execute([':n' => $note, ':id' => $id]);
        vewo_farm_notify($pdo, (string) $farm['owner_user_id'], 'تم رفض طلب المزرعة', $note, ['type' => 'farm_rejected', 'farm_id' => $id]);
    } elseif ($action === 'suspend') {
        $pdo->prepare("UPDATE farms SET status = 'suspended', is_active = 0, updated_at = NOW(3) WHERE id = :id LIMIT 1")->execute([':id' => $id]);
    } elseif ($action === 'close') {
        $pdo->prepare("UPDATE farms SET status = 'closed', is_active = 0, updated_at = NOW(3) WHERE id = :id LIMIT 1")->execute([':id' => $id]);
    } elseif ($action === 'activate' || $action === 'reopen') {
        $pdo->prepare("UPDATE farms SET status = 'approved', is_active = 1, updated_at = NOW(3) WHERE id = :id LIMIT 1")->execute([':id' => $id]);
    } else {
        json_error(400, 'إجراء غير صالح');
    }
    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE);
}

function admin_farm_bookings_route(PDO $pdo): void
{
    require_admin_from_bearer($pdo);
    if (function_exists('vewo_require_admin_permission')) {
        vewo_require_admin_permission($pdo, 'offices');
    }
    vewo_farm_expire_holds($pdo);
    $stmt = $pdo->query('SELECT * FROM farm_bookings ORDER BY created_at DESC LIMIT 400');
    $items = [];
    foreach ($stmt !== false ? ($stmt->fetchAll(PDO::FETCH_ASSOC) ?: []) : [] as $row) {
        $items[] = vewo_farm_booking_json($pdo, $row, true);
    }
    echo json_encode(['ok' => true, 'items' => $items], JSON_UNESCAPED_UNICODE);
}
