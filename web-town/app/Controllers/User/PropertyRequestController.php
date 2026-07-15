<?php
declare(strict_types=1);

namespace App\Controllers\User;

use App\Core\Controller;

final class PropertyRequestController extends Controller
{
    public function form(): void
    {
        require_login();
        $govs = api_client()->get('app/governorates');
        $this->view('user/property-request', [
            'title' => 'طلب عقار',
            'governorates' => $govs['items'] ?? $govs['governorates'] ?? [],
            'error' => '',
            'success' => '',
        ], 'user');
    }

    public function submit(): void
    {
        verify_csrf();
        require_login();
        $payload = [
            'governorate' => trim((string) ($_POST['governorate'] ?? '')),
            'district' => trim((string) ($_POST['district'] ?? '')),
            'category' => trim((string) ($_POST['category'] ?? 'house')),
            'purpose' => trim((string) ($_POST['purpose'] ?? 'sale')),
            'budget_iqd' => (int) ($_POST['budget_iqd'] ?? 0),
            'area_sqm_min' => (int) ($_POST['area_sqm_min'] ?? 0),
            'notes' => trim((string) ($_POST['notes'] ?? '')),
        ];
        $response = api_client()->post('property-requests', $payload, auth_token());
        $govs = api_client()->get('app/governorates');
        $this->view('user/property-request', [
            'title' => 'طلب عقار',
            'governorates' => $govs['items'] ?? $govs['governorates'] ?? [],
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? 'تعذر الإرسال') : '',
            'success' => !empty($response['ok']) ? 'تم إرسال طلبك بنجاح.' : '',
        ], 'user');
    }

    public function mine(): void
    {
        require_login();
        $response = api_client()->get('property-requests', [], auth_token());
        $this->view('user/my-requests', [
            'title' => 'طلباتي',
            'items' => $response['items'] ?? [],
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
        ], 'user');
    }
}
