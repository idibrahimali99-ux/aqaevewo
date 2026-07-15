<?php
declare(strict_types=1);

namespace App\Controllers\User;

use App\Core\Controller;

final class ChatController extends Controller
{
    public function index(): void
    {
        require_login();
        $activeThread = trim((string) ($_GET['thread'] ?? ''));
        $this->view('user/messenger', [
            'title' => 'الرسائل',
            'activeThread' => $activeThread,
        ], 'chat');
    }

    public function apiThreads(): void
    {
        require_login();
        $data = api_client()->get('chat/threads', [
            'q' => trim((string) ($_GET['q'] ?? '')),
        ], auth_token());
        $this->json([
            'ok' => !empty($data['ok']),
            'items' => is_array($data['items'] ?? null) ? $data['items'] : [],
            'error' => (string) ($data['error'] ?? ''),
        ]);
    }

    public function apiMessages(string $threadId): void
    {
        require_login();
        $data = api_client()->get('chat/messages', ['thread_id' => $threadId], auth_token());
        if (!empty($data['ok'])) {
            api_client()->post('chat/thread/read', ['thread_id' => $threadId], auth_token());
        }
        $thread = is_array($data['thread'] ?? null) ? $data['thread'] : [];
        foreach ([
            'thread_type', 'thread_public_no', 'customer_user_id', 'office_user_id',
            'customer_display_name', 'customer_phone', 'office_display_name', 'office_phone',
            'customer_last_read_at', 'admin_last_read_at', 'thread_last_message_at',
            'mediated_customer_caught_up', 'thread_customer_unread', 'thread_office_unread',
        ] as $key) {
            if (array_key_exists($key, $data)) {
                $thread[$key] = $data[$key];
            }
        }
        $this->json([
            'ok' => !empty($data['ok']),
            'items' => is_array($data['items'] ?? null) ? $data['items'] : [],
            'thread' => $thread,
            'property' => $data['property'] ?? null,
            'reel' => $data['reel'] ?? null,
            'me_id' => (string) (auth_user()['id'] ?? ''),
            'me_role' => (string) (auth_user()['role'] ?? ''),
            'error' => (string) ($data['error'] ?? ''),
        ]);
    }

    public function apiSend(string $threadId): void
    {
        require_login();
        verify_csrf_json();
        $input = json_input();
        $body = trim((string) ($input['body'] ?? $_POST['body'] ?? ''));
        $visibility = trim((string) ($input['visibility'] ?? $_POST['visibility'] ?? 'all'));
        if ($body === '') {
            $this->json(['ok' => false, 'error' => 'الرسالة فارغة'], 400);
        }
        $payload = ['thread_id' => $threadId, 'body' => $body];
        if ($visibility !== '' && $visibility !== 'all') {
            $payload['visibility'] = $visibility;
        }
        $data = api_client()->post('chat/messages', $payload, auth_token());
        $this->json([
            'ok' => !empty($data['ok']),
            'error' => (string) ($data['error'] ?? ''),
        ], !empty($data['ok']) ? 200 : 422);
    }

    public function apiOpen(): void
    {
        require_login();
        verify_csrf_json();
        $input = json_input();
        $payload = [];
        $propertyId = trim((string) ($input['property_id'] ?? ''));
        $reelId = trim((string) ($input['reel_id'] ?? ''));
        if ($propertyId !== '') {
            $payload['property_id'] = $propertyId;
        }
        if ($reelId !== '') {
            $payload['reel_id'] = $reelId;
        }
        if (!empty($input['support'])) {
            $payload['support'] = 1;
        }
        $data = api_client()->post('chat/thread/open', $payload, auth_token());
        $threadId = (string) ($data['thread_id'] ?? $data['id'] ?? '');
        $this->json([
            'ok' => !empty($data['ok']),
            'thread_id' => $threadId,
            'error' => (string) ($data['error'] ?? ''),
        ], !empty($data['ok']) ? 200 : 422);
    }

    public function apiUpload(string $threadId): void
    {
        require_login();
        verify_csrf();
        if (empty($_FILES['file']['tmp_name'])) {
            $this->json(['ok' => false, 'error' => 'لم يُرفع ملف'], 400);
        }
        $upload = api_client()->upload(
            'chat/upload',
            (string) $_FILES['file']['tmp_name'],
            (string) ($_FILES['file']['name'] ?? 'file.bin'),
            auth_token()
        );
        if (empty($upload['ok'])) {
            $this->json(['ok' => false, 'error' => (string) ($upload['error'] ?? 'فشل الرفع')], 422);
        }
        $url = (string) ($upload['public_url'] ?? $upload['url'] ?? '');
        $mime = (string) ($_FILES['file']['type'] ?? '');
        $mediaType = str_starts_with($mime, 'image/') ? 'image' : (str_starts_with($mime, 'audio/') ? 'audio' : 'file');
        $payload = [
            'thread_id' => $threadId,
            'body' => '',
            'media_type' => $mediaType,
            'media_public_url' => $url,
        ];
        $visibility = trim((string) ($_POST['visibility'] ?? ''));
        if ($visibility !== '' && $visibility !== 'all') {
            $payload['visibility'] = $visibility;
        }
        $send = api_client()->post('chat/messages', $payload, auth_token());
        $this->json([
            'ok' => !empty($send['ok']),
            'error' => (string) ($send['error'] ?? ''),
        ], !empty($send['ok']) ? 200 : 422);
    }
}
