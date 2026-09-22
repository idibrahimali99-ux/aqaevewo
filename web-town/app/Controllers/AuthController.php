<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class AuthController extends Controller
{
    public function loginForm(): void
    {
        if (is_logged_in()) {
            redirect_to(after_login_path(auth_user()));
        }
        $error = '';
        if (($_GET['error'] ?? '') === 'admin_token_required') {
            $error = 'يجب تسجيل الدخول عبر auth/admin/login (رمز admin) للوصول للوحة التحكم.';
        }
        if (($_GET['error'] ?? '') === 'session_replaced') {
            $error = 'تم تسجيل الدخول من جهاز آخر، لذلك أُغلقت هذه الجلسة.';
        }
        $this->view('auth/login', ['title' => 'تسجيل الدخول', 'error' => $error]);
    }

    public function loginSubmit(): void
    {
        verify_csrf();
        $login = trim((string) ($_POST['login'] ?? ''));
        $password = (string) ($_POST['password'] ?? '');
        $result = login_with_credentials($login, $password);
        if (!empty($result['ok'])) {
            redirect_to(after_login_path(auth_user()));
        }
        $this->view('auth/login', [
            'title' => 'تسجيل الدخول',
            'error' => (string) ($result['error'] ?? 'تعذر تسجيل الدخول'),
            'login' => $login,
        ]);
    }

    public function registerForm(): void
    {
        $this->view('auth/register', [
            'title' => 'إنشاء حساب',
            'old' => [],
            'governorates' => $this->governorateNames(),
        ]);
    }

    public function registerSubmit(): void
    {
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
        if ($kind === 'farm') {
            $this->view('auth/register', [
                'title' => 'إنشاء حساب',
                'error' => 'تسجيل حساب المزرعة غير متاح',
                'old' => $_POST,
            ]);
            return;
        }
        $response = api_client()->post('auth/register', $payload);
        if (!empty($response['ok']) && isset($response['user'], $response['token']) && is_array($response['user'])) {
            persist_auth($response['user'], (string) $response['token'], 'user');
            refresh_current_user();
            redirect_to(after_login_path(auth_user()));
        }
        $this->view('auth/register', [
            'title' => 'إنشاء حساب',
            'error' => (string) ($response['error'] ?? 'تعذر إنشاء الحساب'),
            'old' => $_POST,
            'governorates' => $this->governorateNames(),
        ]);
    }

    /** @return list<string> */
    private function governorateNames(): array
    {
        try {
            $govs = api_client()->get('app/governorates');
        } catch (\Throwable $e) {
            $govs = [];
        }
        $names = [];
        foreach (($govs['items'] ?? []) as $gov) {
            if (is_array($gov) && !empty($gov['name'])) {
                $names[] = (string) $gov['name'];
            } elseif (is_string($gov) && trim($gov) !== '') {
                $names[] = trim($gov);
            }
        }
        $fallback = ['بغداد', 'البصرة', 'الموصل', 'أربيل', 'النجف', 'كربلاء', 'الناصرية', 'العمارة', 'الحلة', 'الديوانية', 'سامراء', 'تكريت', 'دهوك', 'السليمانية', 'ذي قار'];
        foreach ($fallback as $g) {
            if (!in_array($g, $names, true)) {
                $names[] = $g;
            }
        }
        return $names;
    }

    public function logout(): void
    {
        logout();
        redirect_to('/');
    }
}
