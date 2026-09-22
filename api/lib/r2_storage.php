<?php
declare(strict_types=1);

/**
 * Cloudflare R2 (S3-compatible) storage helpers.
 *
 * @param array<string,mixed> $config
 */
function vewo_r2_config(array $config): array
{
    $r2 = $config['r2'] ?? [];
    return is_array($r2) ? $r2 : [];
}

/**
 * @param array<string,mixed> $config
 */
function vewo_r2_enabled(array $config): bool
{
    $r2 = vewo_r2_config($config);
    if (empty($r2['enabled'])) {
        return false;
    }
    $access = trim((string) ($r2['access_key'] ?? ''));
    $secret = trim((string) ($r2['secret_key'] ?? ''));
    $bucket = trim((string) ($r2['bucket'] ?? ''));
    $public = trim((string) ($r2['public_base_url'] ?? ''));
    return $access !== '' && $secret !== '' && $bucket !== '' && $public !== '';
}

/**
 * Base URL used for public media links (R2 public domain, else API public_base_url / request host).
 *
 * @param array<string,mixed> $config
 */
function vewo_media_public_base(array $config): string
{
    if (vewo_r2_enabled($config)) {
        return rtrim((string) (vewo_r2_config($config)['public_base_url'] ?? ''), '/');
    }
    $publicBase = rtrim((string) ($config['public_base_url'] ?? ''), '/');
    if ($publicBase !== '') {
        return $publicBase;
    }
    $https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && strtolower((string) $_SERVER['HTTP_X_FORWARDED_PROTO']) === 'https');
    $scheme = $https ? 'https' : 'http';
    $host = (string) ($_SERVER['HTTP_HOST'] ?? 'localhost');
    $script = (string) ($_SERVER['SCRIPT_NAME'] ?? '/index.php');
    $basePath = rtrim(str_replace('\\', '/', dirname($script)), '/');

    return $scheme . '://' . $host . $basePath;
}

/**
 * يحوّل مسار صورة نسبي إلى رابط مطلق يفتح في المتصفح.
 */
function vewo_absolute_media_url(mixed $url): string
{
    $url = is_scalar($url) ? trim((string) $url) : '';
    if ($url === '' || strcasecmp($url, 'null') === 0) {
        return '';
    }
    if (preg_match('#^https?://#i', $url) === 1 || str_starts_with($url, 'data:')) {
        return $url;
    }
    if (str_starts_with($url, '//')) {
        return 'https:' . $url;
    }
    $config = is_array($GLOBALS['vewo_config'] ?? null) ? $GLOBALS['vewo_config'] : [];
    $base = rtrim(vewo_media_public_base($config), '/');
    if (str_starts_with($url, '/')) {
        return $base . $url;
    }

    return $base . '/' . ltrim($url, '/');
}

/**
 * يمنع أباتشي من قطع الاتصال أثناء انتظار رفع R2.
 */
function vewo_begin_long_upload(): void
{
    @ignore_user_abort(true);
    @set_time_limit(0);
    @ini_set('max_execution_time', '0');
    @ini_set('max_input_time', '0');
    if (!headers_sent()) {
        header('Connection: close');
    }
}

/**
 * Store an uploaded temp file either on R2 or local disk.
 *
 * @param array<string,mixed> $config
 * @return array{name:string,storage_key:string,public_url:string,local_path:?string}
 */
function vewo_store_uploaded_file(
    array $config,
    string $tmpPath,
    string $mime,
    string $ext,
    string $folder = ''
): array {
    vewo_begin_long_upload();
    $folder = trim(str_replace('\\', '/', $folder), '/');
    $name = uuid_v4() . '.' . ltrim($ext, '.');
    $relative = $folder === '' ? $name : ($folder . '/' . $name);
    $storageKey = 'uploads/' . $relative;

    if (vewo_r2_enabled($config)) {
        vewo_r2_put_file(vewo_r2_config($config), $storageKey, $tmpPath, $mime);
        $publicUrl = rtrim((string) (vewo_r2_config($config)['public_base_url'] ?? ''), '/') . '/' . $storageKey;
        @unlink($tmpPath);

        return [
            'name' => $name,
            'storage_key' => $storageKey,
            'public_url' => $publicUrl,
            'local_path' => null,
        ];
    }

    $dir = dirname(__DIR__) . '/uploads' . ($folder === '' ? '' : '/' . $folder);
    if (!is_dir($dir)) {
        if (!@mkdir($dir, 0755, true) && !is_dir($dir)) {
            json_error(500, 'تعذر إنشاء مجلد الرفع');
        }
    }
    $dest = $dir . '/' . $name;
    if (!@move_uploaded_file($tmpPath, $dest) && !@rename($tmpPath, $dest)) {
        if (!@copy($tmpPath, $dest)) {
            json_error(500, 'تعذر حفظ الملف');
        }
        @unlink($tmpPath);
    }
    $publicUrl = vewo_media_public_base($config) . '/uploads/' . $relative;

    return [
        'name' => $name,
        'storage_key' => $storageKey,
        'public_url' => $publicUrl,
        'local_path' => $dest,
    ];
}

/**
 * Put a local file into R2 via S3-compatible API (SigV4), streaming from disk.
 *
 * @param array<string,mixed> $r2
 */
function vewo_r2_put_file(array $r2, string $key, string $filePath, string $contentType): void
{
    if (!is_file($filePath) || !is_readable($filePath)) {
        json_error(500, 'تعذر قراءة الملف للرفع إلى R2');
    }
    $size = filesize($filePath);
    if ($size === false || $size < 0) {
        json_error(500, 'تعذر تحديد حجم الملف');
    }

    $fp = fopen($filePath, 'rb');
    if ($fp === false) {
        json_error(500, 'تعذر فتح الملف للرفع إلى R2');
    }
    try {
        // UNSIGNED-PAYLOAD: لا نحسب SHA-256 للملف كاملاً قبل الرفع.
        // الحساب كان يجمّد PHP دقائق فيفشل أباتشي بـ "Connection closed before full header".
        vewo_r2_signed_put($r2, $key, $contentType, 'UNSIGNED-PAYLOAD', (int) $size, $fp);
    } finally {
        fclose($fp);
    }
}

/**
 * @param array<string,mixed> $r2
 */
function vewo_r2_put_object(array $r2, string $key, string $body, string $contentType): void
{
    $payloadHash = hash('sha256', $body);
    vewo_r2_signed_put($r2, $key, $contentType, $payloadHash, strlen($body), $body);
}

/**
 * @param array<string,mixed> $r2
 * @param resource|string $bodyOrStream
 */
function vewo_r2_signed_put(
    array $r2,
    string $key,
    string $contentType,
    string $payloadHash,
    int $contentLength,
    $bodyOrStream
): void {
    $accessKey = trim((string) ($r2['access_key'] ?? ''));
    $secretKey = trim((string) ($r2['secret_key'] ?? ''));
    $bucket = trim((string) ($r2['bucket'] ?? ''));
    $endpoint = rtrim((string) ($r2['endpoint'] ?? ''), '/');
    $region = trim((string) ($r2['region'] ?? 'auto'));
    if ($region === '') {
        $region = 'auto';
    }
    if ($accessKey === '' || $secretKey === '' || $bucket === '' || $endpoint === '') {
        json_error(500, 'إعدادات Cloudflare R2 غير مكتملة');
    }

    $key = ltrim(str_replace('\\', '/', $key), '/');
    $host = parse_url($endpoint, PHP_URL_HOST);
    if (!is_string($host) || $host === '') {
        json_error(500, 'endpoint غير صالح في إعدادات R2');
    }

    $contentType = trim($contentType) !== '' ? trim($contentType) : 'application/octet-stream';
    $cacheControl = 'public, max-age=31536000, immutable';
    $contentDisposition = 'inline';

    $amzDate = gmdate('Ymd\THis\Z');
    $dateStamp = gmdate('Ymd');
    $canonicalUri = '/' . $bucket . '/' . implode('/', array_map('rawurlencode', explode('/', $key)));

    $canonicalHeaders =
        "cache-control:{$cacheControl}\n"
        . "content-disposition:{$contentDisposition}\n"
        . "content-type:{$contentType}\n"
        . "host:{$host}\n"
        . "x-amz-content-sha256:{$payloadHash}\n"
        . "x-amz-date:{$amzDate}\n";
    $signedHeaders = 'cache-control;content-disposition;content-type;host;x-amz-content-sha256;x-amz-date';
    $canonicalRequest = "PUT\n{$canonicalUri}\n\n{$canonicalHeaders}\n{$signedHeaders}\n{$payloadHash}";

    $algorithm = 'AWS4-HMAC-SHA256';
    $credentialScope = "{$dateStamp}/{$region}/s3/aws4_request";
    $stringToSign = $algorithm . "\n" . $amzDate . "\n" . $credentialScope . "\n" . hash('sha256', $canonicalRequest);

    $signingKey = vewo_r2_signing_key($secretKey, $dateStamp, $region, 's3');
    $signature = hash_hmac('sha256', $stringToSign, $signingKey);
    $authorization = $algorithm
        . " Credential={$accessKey}/{$credentialScope},"
        . " SignedHeaders={$signedHeaders},"
        . " Signature={$signature}";

    $url = $endpoint . '/' . $bucket . '/' . implode('/', array_map('rawurlencode', explode('/', $key)));
    if (!function_exists('curl_init')) {
        json_error(500, 'امتداد cURL مطلوب للرفع إلى Cloudflare R2');
    }

    $ch = curl_init($url);
    if ($ch === false) {
        json_error(500, 'تعذر تهيئة طلب R2');
    }

    $headers = [
        'Cache-Control: ' . $cacheControl,
        'Content-Disposition: ' . $contentDisposition,
        'Content-Type: ' . $contentType,
        'Host: ' . $host,
        'x-amz-content-sha256: ' . $payloadHash,
        'x-amz-date: ' . $amzDate,
        'Authorization: ' . $authorization,
        'Content-Length: ' . (string) $contentLength,
    ];

    $opts = [
        CURLOPT_CUSTOMREQUEST => 'PUT',
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_TIMEOUT => 600,
        CURLOPT_CONNECTTIMEOUT => 30,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
    ];
    if (defined('CURLOPT_NOSIGNAL')) {
        $opts[CURLOPT_NOSIGNAL] = true;
    }
    if (defined('CURLOPT_TCP_NODELAY')) {
        $opts[CURLOPT_TCP_NODELAY] = true;
    }

    if (is_resource($bodyOrStream)) {
        $opts[CURLOPT_UPLOAD] = true;
        $opts[CURLOPT_INFILE] = $bodyOrStream;
        $opts[CURLOPT_INFILESIZE] = $contentLength;
    } else {
        $opts[CURLOPT_POSTFIELDS] = (string) $bodyOrStream;
    }

    curl_setopt_array($ch, $opts);
    $resp = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);

    if ($resp === false || $status < 200 || $status >= 300) {
        $hint = is_string($resp) && $resp !== '' ? mb_substr(trim(strip_tags($resp)), 0, 200) : $err;
        json_error(500, 'فشل الرفع إلى Cloudflare R2' . ($hint !== '' ? (': ' . $hint) : ''));
    }
}

/**
 * Apply a permissive read CORS policy (images/video Range) on the bucket.
 *
 * @param array<string,mixed> $r2
 */
function vewo_r2_put_cors(array $r2): void
{
    $body = <<<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <CORSRule>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <ExposeHeader>Content-Length</ExposeHeader>
    <ExposeHeader>Content-Type</ExposeHeader>
    <ExposeHeader>Content-Range</ExposeHeader>
    <ExposeHeader>Accept-Ranges</ExposeHeader>
    <MaxAgeSeconds>86400</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
XML;
    $body = trim($body) . "\n";

    $accessKey = trim((string) ($r2['access_key'] ?? ''));
    $secretKey = trim((string) ($r2['secret_key'] ?? ''));
    $bucket = trim((string) ($r2['bucket'] ?? ''));
    $endpoint = rtrim((string) ($r2['endpoint'] ?? ''), '/');
    $region = trim((string) ($r2['region'] ?? 'auto')) ?: 'auto';
    $host = parse_url($endpoint, PHP_URL_HOST);
    if (!is_string($host) || $host === '' || $accessKey === '' || $secretKey === '' || $bucket === '') {
        json_error(500, 'إعدادات Cloudflare R2 غير مكتملة');
    }

    $amzDate = gmdate('Ymd\THis\Z');
    $dateStamp = gmdate('Ymd');
    $payloadHash = hash('sha256', $body);
    $canonicalUri = '/' . $bucket;
    $canonicalQuery = 'cors=';
    $contentType = 'application/xml';
    $canonicalHeaders =
        "content-type:{$contentType}\n"
        . "host:{$host}\n"
        . "x-amz-content-sha256:{$payloadHash}\n"
        . "x-amz-date:{$amzDate}\n";
    $signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
    $canonicalRequest = "PUT\n{$canonicalUri}\n{$canonicalQuery}\n{$canonicalHeaders}\n{$signedHeaders}\n{$payloadHash}";

    $algorithm = 'AWS4-HMAC-SHA256';
    $credentialScope = "{$dateStamp}/{$region}/s3/aws4_request";
    $stringToSign = $algorithm . "\n" . $amzDate . "\n" . $credentialScope . "\n" . hash('sha256', $canonicalRequest);
    $signature = hash_hmac('sha256', $stringToSign, vewo_r2_signing_key($secretKey, $dateStamp, $region, 's3'));
    $authorization = $algorithm
        . " Credential={$accessKey}/{$credentialScope},"
        . " SignedHeaders={$signedHeaders},"
        . " Signature={$signature}";

    $url = $endpoint . '/' . $bucket . '?cors';
    $ch = curl_init($url);
    if ($ch === false) {
        json_error(500, 'تعذر تهيئة طلب CORS');
    }
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST => 'PUT',
        CURLOPT_POSTFIELDS => $body,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'Content-Type: ' . $contentType,
            'Host: ' . $host,
            'x-amz-content-sha256: ' . $payloadHash,
            'x-amz-date: ' . $amzDate,
            'Authorization: ' . $authorization,
            'Content-Length: ' . (string) strlen($body),
        ],
        CURLOPT_TIMEOUT => 60,
    ]);
    $resp = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);
    if ($resp === false || $status < 200 || $status >= 300) {
        $hint = is_string($resp) && $resp !== '' ? mb_substr(trim(strip_tags($resp)), 0, 200) : $err;
        json_error(500, 'فشل ضبط CORS على R2' . ($hint !== '' ? (': ' . $hint) : ''));
    }
}

function vewo_r2_signing_key(string $secretKey, string $dateStamp, string $region, string $service): string
{
    $kDate = hash_hmac('sha256', $dateStamp, 'AWS4' . $secretKey, true);
    $kRegion = hash_hmac('sha256', $region, $kDate, true);
    $kService = hash_hmac('sha256', $service, $kRegion, true);

    return hash_hmac('sha256', 'aws4_request', $kService, true);
}
