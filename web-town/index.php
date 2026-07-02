<?php
declare(strict_types=1);

require __DIR__ . '/app/bootstrap.php';

$path = current_path();
$method = request_method();

if ($path === '/logout') {
    logout();
    redirect_to('/');
}

if ($path === '/login') {
    if ($method === 'POST') {
        verify_csrf();
        $login = trim((string) ($_POST['login'] ?? ''));
        $password = (string) ($_POST['password'] ?? '');
        $result = login_with_credentials($login, $password);
        if (!empty($result['ok'])) {
            redirect_to(dashboard_path(auth_user()));
        }
        render('auth/login', [
            'title' => 'تسجيل الدخول',
            'error' => (string) ($result['error'] ?? 'تعذر تسجيل الدخول'),
            'login' => $login,
        ]);
        exit;
    }

    if (is_logged_in()) {
        redirect_to(dashboard_path(auth_user()));
    }
    render('auth/login', ['title' => 'تسجيل الدخول']);
    exit;
}

if ($path === '/register') {
    if ($method === 'POST') {
        verify_csrf();
        $kind = (string) ($_POST['account_kind'] ?? 'customer');
        $payload = [
            'full_name' => trim((string) ($_POST['full_name'] ?? '')),
            'phone' => trim((string) ($_POST['phone'] ?? '')),
            'email' => trim((string) ($_POST['email'] ?? '')),
            'password' => (string) ($_POST['password'] ?? ''),
            'role' => $kind === 'customer' ? 'customer' : 'office',
            'office_name' => trim((string) ($_POST['office_name'] ?? '')),
            'office_address' => trim((string) ($_POST['office_address'] ?? '')),
            'office_license_no' => trim((string) ($_POST['office_license_no'] ?? '')),
            'office_photo_url' => trim((string) ($_POST['office_photo_url'] ?? '')),
        ];
        if ($kind === 'marketer') {
            $payload['is_marketer'] = 1;
            $payload['account_kind'] = 'marketer';
        }
        $response = api_client()->post('auth/register', $payload);
        if (!empty($response['ok']) && isset($response['user'], $response['token']) && is_array($response['user'])) {
            persist_auth($response['user'], (string) $response['token'], 'user');
            refresh_current_user();
            redirect_to(dashboard_path(auth_user()));
        }
        render('auth/register', [
            'title' => 'إنشاء حساب',
            'error' => (string) ($response['error'] ?? 'تعذر إنشاء الحساب'),
            'old' => $_POST,
        ]);
        exit;
    }
    render('auth/register', ['title' => 'إنشاء حساب', 'old' => []]);
    exit;
}

if ($path === '/properties') {
    $response = api_client()->get('properties/list', [
        'q' => trim((string) ($_GET['q'] ?? '')),
        'governorate' => trim((string) ($_GET['governorate'] ?? '')),
        'purpose' => trim((string) ($_GET['purpose'] ?? '')),
        'limit' => 24,
    ]);
    render('properties', [
        'title' => 'العقارات',
        'items' => $response['items'] ?? [],
        'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
    ]);
    exit;
}

if ($path === '/offices') {
    $response = api_client()->get('offices/list', ['limit' => 50]);
    render('offices', [
        'title' => 'المكاتب والمسوقون',
        'items' => $response['items'] ?? [],
        'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
    ]);
    exit;
}

if ($path === '/dashboard') {
    require_login();
    redirect_to(dashboard_path(auth_user()));
}

if ($path === '/dashboard/admin') {
    $user = require_account_kind(['admin', 'staff']);
    $stats = api_client()->get('admin/stats', [], auth_token());
    render('dashboard/admin', [
        'title' => 'لوحة الإدارة',
        'user' => $user,
        'stats' => $stats,
    ]);
    exit;
}

if ($path === '/dashboard/customer') {
    $user = require_account_kind(['customer']);
    render('dashboard/customer', ['title' => 'لوحة الزبون', 'user' => $user]);
    exit;
}

if ($path === '/dashboard/office') {
    $user = require_account_kind(['office']);
    render('dashboard/office', ['title' => 'لوحة المكتب', 'user' => $user]);
    exit;
}

if ($path === '/dashboard/marketer') {
    $user = require_account_kind(['marketer']);
    render('dashboard/marketer', ['title' => 'لوحة المسوق العقاري', 'user' => $user]);
    exit;
}

if ($path === '/' || $path === '') {
    $bootstrap = api_client()->get('app/bootstrap');
    $properties = api_client()->get('properties/list', ['limit' => 8]);
    $offices = api_client()->get('offices/list', ['limit' => 6]);
    render('home', [
        'title' => 'الرئيسية',
        'bootstrap' => $bootstrap,
        'properties' => $properties['items'] ?? [],
        'offices' => $offices['items'] ?? [],
        'api_error' => empty($bootstrap['ok']) ? (string) ($bootstrap['error'] ?? '') : '',
    ]);
    exit;
}

http_response_code(404);
render('errors/404', ['title' => 'الصفحة غير موجودة']);
