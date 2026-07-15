<?php
declare(strict_types=1);

namespace App\Controllers\User;

use App\Core\Controller;

final class PropertyFormController extends Controller
{
    public function createForm(): void
    {
        require_account_kind(['office', 'marketer']);
        $this->view('user/property-form', [
            'title' => 'إضافة إعلان',
            'error' => '',
            'success' => '',
        ], 'user');
    }

    public function createSubmit(): void
    {
        verify_csrf();
        require_account_kind(['office', 'marketer']);
        $imageUrls = array_values(array_filter(array_map('trim', explode("\n", (string) ($_POST['image_urls'] ?? '')))));
        $body = [
            'title' => trim((string) ($_POST['title'] ?? '')),
            'governorate' => trim((string) ($_POST['governorate'] ?? '')),
            'address_line' => trim((string) ($_POST['address_line'] ?? '')),
            'category' => trim((string) ($_POST['category'] ?? 'house')),
            'segment' => trim((string) ($_POST['segment'] ?? 'standard')),
            'purpose' => trim((string) ($_POST['purpose'] ?? 'sale')),
            'price_iqd' => (int) ($_POST['price_iqd'] ?? 0),
            'area_sqm' => (int) ($_POST['area_sqm'] ?? 0),
            'description' => trim((string) ($_POST['description'] ?? '')),
            'image_urls' => $imageUrls,
        ];
        $response = api_client()->post('properties/create', $body, auth_token());
        if (!empty($response['ok'])) {
            $this->view('user/property-form', [
                'title' => 'إضافة إعلان',
                'error' => '',
                'success' => 'تم إرسال الإعلان — الحالة: ' . (string) ($response['approval_status'] ?? 'pending'),
            ], 'user');
            return;
        }
        $this->view('user/property-form', [
            'title' => 'إضافة إعلان',
            'error' => (string) ($response['error'] ?? 'تعذر إنشاء الإعلان'),
            'success' => '',
        ], 'user');
    }
}
