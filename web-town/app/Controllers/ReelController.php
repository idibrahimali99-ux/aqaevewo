<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class ReelController extends Controller
{
    public function index(): void
    {
        $response = api_client()->get('reels/list', ['limit' => 50]);
        $this->view('reels/index', [
            'title' => 'ريلز',
            'items' => $response['items'] ?? [],
            'error' => empty($response['ok']) ? (string) ($response['error'] ?? '') : '',
        ], 'reels');
    }

    public function show(string $id): void
    {
        redirect_to('/reels', ['reel' => $id]);
    }

    public function apiView(): void
    {
        verify_csrf_json();
        $input = json_input();
        $reelId = trim((string) ($input['reel_id'] ?? ''));
        if ($reelId === '') {
            $this->json(['ok' => false, 'error' => 'reel_id مطلوب'], 400);
        }
        $token = auth_token();
        if ($token === '') {
            $this->json(['ok' => true]);
        }
        api_client()->post('reels/view', ['reel_id' => $reelId], $token);
        $this->json(['ok' => true]);
    }

    public function apiReact(): void
    {
        require_login();
        verify_csrf_json();
        $input = json_input();
        $reelId = trim((string) ($input['reel_id'] ?? ''));
        $liked = !empty($input['liked']) || !empty($input['like']);
        if ($reelId === '') {
            $this->json(['ok' => false, 'error' => 'reel_id مطلوب'], 400);
        }
        $data = api_client()->post('reels/react', [
            'reel_id' => $reelId,
            'liked' => $liked ? 1 : 0,
        ], auth_token());
        $this->json([
            'ok' => !empty($data['ok']),
            'liked' => !empty($data['liked_by_me']),
            'likes_count' => $data['likes_count'] ?? null,
            'error' => (string) ($data['error'] ?? ''),
        ], !empty($data['ok']) ? 200 : 422);
    }

    public function createForm(): void
    {
        require_account_kind(['office', 'marketer']);
        $this->view('user/reel-form', [
            'title' => 'نشر ريل',
            'error' => '',
            'success' => '',
            'reel' => [],
        ], 'user');
    }

    public function createSubmit(): void
    {
        verify_csrf();
        require_account_kind(['office', 'marketer']);
        $videoUrl = $this->uploadReelVideo();
        if ($videoUrl === '') {
            $this->view('user/reel-form', [
                'title' => 'نشر ريل',
                'error' => 'ارفع فيديو بين 30 ثانية و3 دقائق',
                'success' => '',
                'reel' => $_POST,
            ], 'user');
            return;
        }
        $duration = (float) ($_POST['duration_seconds'] ?? 0);
        $response = api_client()->post('reels/create', [
            'video_public_url' => $videoUrl,
            'caption' => trim((string) ($_POST['caption'] ?? '')),
            'duration_seconds' => $duration,
        ], auth_token());
        if (!empty($response['ok'])) {
            redirect_to('/profile', ['ok' => 'reel_created']);
        }
        $this->view('user/reel-form', [
            'title' => 'نشر ريل',
            'error' => (string) ($response['error'] ?? 'تعذر نشر الريل'),
            'success' => '',
            'reel' => $_POST,
        ], 'user');
    }

    public function editForm(string $id): void
    {
        require_login();
        $reel = $this->ownedReel($id);
        if ($reel === null) {
            redirect_to('/profile', ['error' => 'not_found']);
        }
        $this->view('user/reel-form', [
            'title' => 'تعديل الريل',
            'error' => '',
            'success' => '',
            'reel' => $reel,
        ], 'user');
    }

    public function editSubmit(string $id): void
    {
        verify_csrf();
        require_login();
        $reel = $this->ownedReel($id);
        if ($reel === null) {
            redirect_to('/profile', ['error' => 'not_found']);
        }
        $payload = [
            'id' => $id,
            'caption' => trim((string) ($_POST['caption'] ?? '')),
        ];
        $videoUrl = $this->uploadReelVideo();
        if ($videoUrl !== '') {
            $payload['video_public_url'] = $videoUrl;
            $payload['duration_seconds'] = (float) ($_POST['duration_seconds'] ?? 0);
        }
        $response = api_client()->post('reels/update', $payload, auth_token());
        if (!empty($response['ok'])) {
            redirect_to('/profile', ['ok' => 'reel_updated']);
        }
        $this->view('user/reel-form', [
            'title' => 'تعديل الريل',
            'error' => (string) ($response['error'] ?? 'تعذر تعديل الريل'),
            'success' => '',
            'reel' => array_merge($reel, $_POST),
        ], 'user');
    }

    public function deleteSubmit(string $id): void
    {
        verify_csrf();
        require_login();
        $response = api_client()->post('reels/delete', ['id' => $id], auth_token());
        if (!empty($response['ok'])) {
            redirect_to('/profile', ['ok' => 'reel_deleted']);
        }
        redirect_to('/profile', ['error' => (string) ($response['error'] ?? 'تعذر حذف الريل')]);
    }

    /** @return array<string,mixed>|null */
    private function ownedReel(string $id): ?array
    {
        $id = trim($id);
        $meId = (string) (auth_user()['id'] ?? '');
        if ($id === '' || $meId === '') {
            return null;
        }
        $response = api_client()->get('reels/list', [
            'owner_id' => $meId,
            'include_mine' => '1',
            'limit' => 80,
        ], auth_token());
        foreach (is_array($response['items'] ?? null) ? $response['items'] : [] as $row) {
            if (is_array($row) && (string) ($row['id'] ?? '') === $id) {
                return $row;
            }
        }
        return null;
    }

    private function uploadReelVideo(): string
    {
        $file = $_FILES['video'] ?? null;
        if (!is_array($file) || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
            return '';
        }
        $up = api_client()->upload('properties/upload', (string) $file['tmp_name'], (string) $file['name'], auth_token());
        return (string) ($up['public_url'] ?? $up['url'] ?? '');
    }
}
