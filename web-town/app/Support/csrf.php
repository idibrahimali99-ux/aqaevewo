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

function verify_csrf(): void
{
    $actual = (string) ($_POST['_csrf'] ?? '');
    $expected = (string) ($_SESSION['_csrf_token'] ?? '');
    if ($actual === '' || $expected === '' || !hash_equals($expected, $actual)) {
        http_response_code(419);
        echo 'انتهت صلاحية النموذج، أعد تحميل الصفحة وحاول مرة أخرى.';
        exit;
    }
}
