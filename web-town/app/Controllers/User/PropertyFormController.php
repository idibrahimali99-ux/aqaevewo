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
            'property' => [],
        ], 'user');
    }

    public function createSubmit(): void
    {
        verify_csrf();
        require_account_kind(['office', 'marketer']);
        $body = $this->buildPayload();
        if ($body['error'] !== '') {
            $this->view('user/property-form', [
                'title' => 'إضافة إعلان',
                'error' => $body['error'],
                'success' => '',
                'property' => $_POST,
            ], 'user');
            return;
        }
        $response = api_client()->post('properties/create', $body['payload'], auth_token());
        if (!empty($response['ok'])) {
            $this->view('user/property-form', [
                'title' => 'إضافة إعلان',
                'error' => '',
                'success' => 'تم إرسال الإعلان — الحالة: ' . (string) ($response['approval_status'] ?? 'pending'),
                'property' => [],
            ], 'user');
            return;
        }
        $this->view('user/property-form', [
            'title' => 'إضافة إعلان',
            'error' => (string) ($response['error'] ?? 'تعذر إنشاء الإعلان'),
            'success' => '',
            'property' => $_POST,
        ], 'user');
    }

    public function editForm(string $id): void
    {
        require_login();
        $property = $this->ownedProperty($id);
        if ($property === null) {
            redirect_to('/profile', ['error' => 'not_found']);
        }
        $this->view('user/property-form', [
            'title' => 'تعديل الإعلان',
            'error' => '',
            'success' => '',
            'property' => $property,
        ], 'user');
    }

    public function editSubmit(string $id): void
    {
        verify_csrf();
        require_login();
        $property = $this->ownedProperty($id);
        if ($property === null) {
            redirect_to('/profile', ['error' => 'not_found']);
        }
        $body = $this->buildPayload();
        if ($body['error'] !== '') {
            $this->view('user/property-form', [
                'title' => 'تعديل الإعلان',
                'error' => $body['error'],
                'success' => '',
                'property' => array_merge($property, $_POST),
            ], 'user');
            return;
        }
        $payload = $body['payload'];
        $payload['id'] = $id;
        $response = api_client()->post('properties/update', $payload, auth_token());
        if (!empty($response['ok'])) {
            redirect_to('/profile', ['ok' => 'property_updated']);
        }
        $this->view('user/property-form', [
            'title' => 'تعديل الإعلان',
            'error' => (string) ($response['error'] ?? 'تعذر تعديل الإعلان'),
            'success' => '',
            'property' => array_merge($property, $_POST),
        ], 'user');
    }

    public function deleteSubmit(string $id): void
    {
        verify_csrf();
        require_login();
        $response = api_client()->post('properties/delete', ['id' => $id], auth_token());
        if (!empty($response['ok'])) {
            redirect_to('/profile', ['ok' => 'property_deleted']);
        }
        redirect_to('/profile', ['error' => (string) ($response['error'] ?? 'تعذر الحذف')]);
    }

    /** @return array<string,mixed>|null */
    private function ownedProperty(string $id): ?array
    {
        $id = trim($id);
        if ($id === '') {
            return null;
        }
        $response = api_client()->get('properties/get', ['id' => $id], auth_token());
        if (empty($response['ok'])) {
            return null;
        }
        $property = is_array($response['property'] ?? null) ? $response['property'] : $response;
        $ownerId = (string) ($property['owner_user_id'] ?? '');
        $meId = (string) (auth_user()['id'] ?? '');
        if ($ownerId === '' || $meId === '' || $ownerId !== $meId) {
            return null;
        }
        $images = is_array($response['images'] ?? null) ? $response['images'] : [];
        if ($images !== []) {
            $property['image_urls'] = $images;
        }
        return $property;
    }

    /** @return array{payload: array<string,mixed>, error: string} */
    private function buildPayload(): array
    {
        $imageUrls = array_values(array_filter(array_map('trim', explode("\n", (string) ($_POST['image_urls'] ?? '')))));
        $files = $_FILES['images'] ?? $_FILES['image_file'] ?? null;
        if (is_array($files)) {
            $names = $files['name'] ?? [];
            $tmps = $files['tmp_name'] ?? [];
            $errs = $files['error'] ?? [];
            if (!is_array($names)) {
                $names = [$names];
                $tmps = [$tmps];
                $errs = [$errs];
            }
            foreach ($names as $i => $name) {
                if ((int) ($errs[$i] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
                    continue;
                }
                $up = api_client()->upload('properties/upload', (string) $tmps[$i], (string) $name, auth_token());
                $url = (string) ($up['public_url'] ?? $up['url'] ?? '');
                if ($url !== '') {
                    $imageUrls[] = $url;
                }
            }
        }
        $imageUrls = array_values(array_unique(array_filter($imageUrls)));
        if ($imageUrls === []) {
            return ['payload' => [], 'error' => 'أضف صورة واحدة على الأقل'];
        }
        $details = [];
        foreach (['rooms', 'bedrooms', 'bathrooms', 'floor', 'floors_count', 'kitchen', 'living_room', 'parking', 'facade', 'deed_type', 'furnished', 'extra_notes'] as $k) {
            $v = trim((string) ($_POST[$k] ?? ''));
            if ($v !== '') {
                $details[$k] = is_numeric($v) ? (0 + $v) : $v;
            }
        }
        $purpose = trim((string) ($_POST['purpose'] ?? 'sale'));
        if ($purpose === 'rent') {
            $rp = strtolower(trim((string) ($_POST['rent_period'] ?? 'monthly')));
            $details['rent_period'] = $rp === 'yearly' ? 'yearly' : 'monthly';
        }
        return [
            'error' => '',
            'payload' => [
                'title' => trim((string) ($_POST['title'] ?? '')),
                'governorate' => trim((string) ($_POST['governorate'] ?? '')),
                'address_line' => trim((string) ($_POST['address_line'] ?? '')),
                'category' => trim((string) ($_POST['category'] ?? 'house')),
                'segment' => trim((string) ($_POST['segment'] ?? 'standard')),
                'purpose' => $purpose,
                'price_iqd' => (int) ($_POST['price_iqd'] ?? 0),
                'area_sqm' => (int) ($_POST['area_sqm'] ?? 0),
                'description' => trim((string) ($_POST['description'] ?? '')),
                'image_urls' => $imageUrls,
                'details_json' => $details,
            ],
        ];
    }
}
