<?php
declare(strict_types=1);

function csrf_token(): string
{
    if (empty($_SESSION['_csrf_token'])) {
        $_SESSION['_csrf_token'] = bin2hex(random_bytes(32));
    }

    return (string) $_SESSION['_csrf_token'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="_csrf" value="' . e(csrf_token()) . '">';
}

function csrf_header_value(): string
{
    return csrf_token();
}

function verify_csrf(): void
{
    if (!csrf_valid()) {
        http_response_code(419);
        echo 'انتهت صلاحية النموذج، أعد تحميل الصفحة وحاول مرة أخرى.';
        exit;
    }
}

function verify_csrf_json(): void
{
    if (!csrf_valid()) {
        http_response_code(419);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['ok' => false, 'error' => 'انتهت صلاحية الجلسة'], JSON_UNESCAPED_UNICODE);
        exit;
    }
}

function csrf_valid(): bool
{
    $actual = (string) ($_POST['_csrf'] ?? $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
    $expected = (string) ($_SESSION['_csrf_token'] ?? '');

    return $actual !== '' && $expected !== '' && hash_equals($expected, $actual);
}

/** @return array<string,mixed> */
function json_input(): array
{
    $raw = file_get_contents('php://input');
    if (!is_string($raw) || $raw === '') {
        return [];
    }
    $decoded = json_decode($raw, true);

    return is_array($decoded) ? $decoded : [];
}
