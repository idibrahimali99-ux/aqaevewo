<?php
declare(strict_types=1);

/**
 * @return array<string,mixed>|null
 */
function auth_user(): ?array
{
    $user = $_SESSION['auth_user'] ?? null;
    return is_array($user) ? $user : null;
}

function auth_token(): string
{
    return (string) ($_SESSION['auth_token'] ?? '');
}

function auth_token_type(): string
{
    return (string) ($_SESSION['auth_token_type'] ?? '');
}

function is_logged_in(): bool
{
    return auth_user() !== null && auth_token() !== '';
}

function is_admin_area_user(?array $user = null): bool
{
    $user ??= auth_user();
    return in_array((string) ($user['role'] ?? ''), ['admin', 'staff'], true);
}

function account_kind(?array $user = null): string
{
    $user ??= auth_user();
    $role = (string) ($user['role'] ?? 'guest');
    if ($role === 'office' && !empty($user['is_marketer'])) {
        return 'marketer';
    }

    return $role;
}

function dashboard_path(?array $user = null): string
{
    return match (account_kind($user)) {
        'admin', 'staff' => '/admin',
        'office' => '/user/office',
        'marketer' => '/user/marketer',
        'customer' => '/user',
        default => '/login',
    };
}

function require_login(): array
{
    $user = auth_user();
    if ($user === null) {
        redirect_to('/login', ['next' => current_path()]);
    }

    return $user;
}

function require_account_kind(array $allowed): array
{
    $user = require_login();
    if (!in_array(account_kind($user), $allowed, true)) {
        redirect_to(dashboard_path($user));
    }

    return $user;
}

function login_with_credentials(string $login, string $password): array
{
    // نفس vewo_admin: admin/stats وكل مسارات admin/* تتطلب token من auth/admin/login
    $admin = api_client()->post('auth/admin/login', [
        'login' => $login,
        'password' => $password,
    ]);

    if (!empty($admin['ok']) && isset($admin['user'], $admin['token']) && is_array($admin['user'])) {
        persist_auth($admin['user'], (string) $admin['token'], 'admin');
        return ['ok' => true, 'user' => $admin['user']];
    }

    $user = api_client()->post('auth/login', [
        'login' => $login,
        'password' => $password,
    ]);

    if (!empty($user['ok']) && isset($user['user'], $user['token']) && is_array($user['user'])) {
        $role = (string) ($user['user']['role'] ?? '');
        if (in_array($role, ['admin', 'staff'], true)) {
            return [
                'ok' => false,
                'error' => (string) ($admin['error'] ?? 'فشل دخول لوحة الأدمن — استخدم حساب admin/staff عبر auth/admin/login'),
            ];
        }
        persist_auth($user['user'], (string) $user['token'], 'user');
        refresh_current_user();
        return ['ok' => true, 'user' => auth_user()];
    }

    return [
        'ok' => false,
        'error' => (string) ($user['error'] ?? $admin['error'] ?? 'بيانات الدخول غير صحيحة'),
    ];
}

/**
 * @param array<string,mixed> $user
 */
function persist_auth(array $user, string $token, string $type): void
{
    session_regenerate_id(true);
    $_SESSION['auth_user'] = $user;
    $_SESSION['auth_token'] = $token;
    $_SESSION['auth_token_type'] = $type;
}

function refresh_current_user(): void
{
    if (auth_token() === '') {
        return;
    }
    $response = api_client()->get('users/me', [], auth_token());
    if (!empty($response['ok']) && isset($response['user']) && is_array($response['user'])) {
        $_SESSION['auth_user'] = array_merge(auth_user() ?? [], $response['user']);
    }
}

function logout(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'], (bool) $params['secure'], (bool) $params['httponly']);
    }
    session_destroy();
}

function can_staff(string $permission): bool
{
    $user = auth_user();
    if (($user['role'] ?? '') === 'admin') {
        return true;
    }
    if (($user['role'] ?? '') !== 'staff') {
        return false;
    }
    $permissions = $user['staff_permissions'] ?? [];
    return is_array($permissions) && in_array($permission, $permissions, true);
}

/** يضمن أن جلسة الأدمن تستخدم admin_api_tokens — مثل vewo_admin */
function require_admin_api_token(): void
{
    require_account_kind(['admin', 'staff']);
    if (auth_token_type() !== 'admin' || auth_token() === '') {
        logout();
        redirect_to('/login', ['error' => 'admin_token_required']);
    }
}

/** @return array<string,mixed> */
function admin_fetch_stats(): array
{
    require_admin_api_token();
    return api_client()->get('admin/stats', [], auth_token());
}
