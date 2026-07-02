<?php
declare(strict_types=1);

/**
 * بث صوت المحادثة مع دعم HTTP Range (تشغيل تدريجي مثل تيليجرام).
 */
function chat_stream_serve(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'GET') {
        http_response_code(405);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'Method not allowed';

        return;
    }

    $file = basename((string) ($_GET['file'] ?? ''));
    if ($file === '' || !preg_match('/^[0-9a-fA-F-]{36}\.(wav|m4a|aac|mp3|ogg|webm)$/i', $file)) {
        http_response_code(400);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'Invalid file';

        return;
    }

    $path = dirname(__DIR__) . '/uploads/chat/' . $file;
    if (!is_file($path) || !is_readable($path)) {
        http_response_code(404);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'Not found';

        return;
    }

    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    $mime = match ($ext) {
        'm4a', 'aac' => 'audio/mp4',
        'mp3' => 'audio/mpeg',
        'ogg' => 'audio/ogg',
        'webm' => 'audio/webm',
        default => 'audio/wav',
    };

    vewo_http_stream_file($path, $mime);
}

/**
 * @param non-empty-string $path
 * @param non-empty-string $mime
 */
function vewo_http_stream_file(string $path, string $mime): void
{
    $size = filesize($path);
    if ($size === false || $size < 1) {
        http_response_code(500);

        return;
    }

    $start = 0;
    $end = $size - 1;
    $length = $size;

    $rangeHeader = (string) ($_SERVER['HTTP_RANGE'] ?? '');
    if ($rangeHeader !== '' && preg_match('/bytes=(\d*)-(\d*)/', $rangeHeader, $m)) {
        if ($m[1] !== '') {
            $start = (int) $m[1];
        }
        if ($m[2] !== '') {
            $end = (int) $m[2];
        }
        if ($start > $end || $start >= $size) {
            http_response_code(416);
            header("Content-Range: bytes */$size");

            return;
        }
        $end = min($end, $size - 1);
        $length = $end - $start + 1;
        http_response_code(206);
        header("Content-Range: bytes $start-$end/$size");
    }

    header('Content-Type: ' . $mime);
    header('Accept-Ranges: bytes');
    header('Content-Length: ' . (string) $length);
    header('Cache-Control: public, max-age=86400');
    header('Access-Control-Expose-Headers: Content-Range, Accept-Ranges, Content-Length');

    if (function_exists('apache_setenv')) {
        @apache_setenv('no-gzip', '1');
    }
    @ini_set('zlib.output_compression', '0');

    $fp = fopen($path, 'rb');
    if ($fp === false) {
        http_response_code(500);

        return;
    }
    fseek($fp, $start);
    $remaining = $length;
    while ($remaining > 0 && !feof($fp)) {
        $chunk = fread($fp, min(8192, $remaining));
        if ($chunk === false) {
            break;
        }
        echo $chunk;
        $remaining -= strlen($chunk);
        if (connection_aborted()) {
            break;
        }
    }
    fclose($fp);
}
