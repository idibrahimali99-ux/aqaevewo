<?php
declare(strict_types=1);

namespace App\Controllers\User;

use App\Core\Controller;

final class AccountController extends Controller
{
    public function profile(): void
    {
        $user = require_login();
        refresh_current_user();
        $user = auth_user() ?? $user;
        $myProps = api_client()->get('properties/list', [
            'owner_id' => (string) ($user['id'] ?? ''),
            'include_mine' => '1',
            'limit' => 50,
        ], auth_token());
        $this->view('user/profile', [
            'title' => 'الملف الشخصي',
            'user' => $user,
            'properties' => $myProps['items'] ?? [],
            'error' => '',
            'success' => '',
        ], 'user');
    }

    public function profileSubmit(): void
    {
        verify_csrf();
        $user = require_login();
        $response = api_client()->post('users/update-profile', [
            'full_name' => trim((string) ($_POST['full_name'] ?? '')),
            'office_name' => trim((string) ($_POST['office_name'] ?? '')),
        ], auth_token());
        if (!empty($response['ok'])) {
            refresh_current_user();
            $user = auth_user() ?? $user;
            $myProps = api_client()->get('properties/list', [
                'owner_id' => (string) ($user['id'] ?? ''),
                'include_mine' => '1',
                'limit' => 50,
            ], auth_token());
            $this->view('user/profile', [
                'title' => 'الملف الشخصي',
                'user' => $user,
                'properties' => $myProps['items'] ?? [],
                'error' => '',
                'success' => 'تم تحديث الملف.',
            ], 'user');
            return;
        }
        $this->view('user/profile', [
            'title' => 'الملف الشخصي',
            'user' => $user,
            'properties' => [],
            'error' => (string) ($response['error'] ?? 'تعذر التحديث'),
            'success' => '',
        ], 'user');
    }

    public function favorites(): void
    {
        require_login();
        $this->view('user/favorites', [
            'title' => 'المفضلة',
            'items' => favorite_properties(),
        ], 'user');
    }

    public function favoritesToggle(): void
    {
        verify_csrf();
        require_login();
        $id = trim((string) ($_POST['property_id'] ?? ''));
        toggle_favorite($id);
        $back = trim((string) ($_POST['back'] ?? '/favorites'));
        redirect_to($back !== '' ? $back : '/favorites');
    }

    public function notifications(): void
    {
        require_login();
        $data = api_client()->get('app/notifications/poll', ['since_ms' => '0', 'mark_read' => '1'], auth_token());
        $this->view('user/notifications', [
            'title' => 'الإشعارات',
            'items' => is_array($data['items'] ?? null) ? $data['items'] : [],
            'counts' => is_array($data['counts'] ?? null) ? $data['counts'] : [],
            'error' => empty($data['ok']) ? (string) ($data['error'] ?? '') : '',
        ], 'user');
    }

    public function notificationsPoll(): void
    {
        require_login();
        header('Content-Type: application/json; charset=utf-8');
        $data = api_client()->get('app/notifications/poll', ['since_ms' => '0'], auth_token());
        echo json_encode($data, JSON_UNESCAPED_UNICODE);
    }

    public function messages(): void
    {
        require_login();
        $data = api_client()->get('chat/threads', [
            'q' => trim((string) ($_GET['q'] ?? '')),
        ], auth_token());
        $this->view('user/messages', [
            'title' => 'الرسائل',
            'items' => is_array($data['items'] ?? null) ? $data['items'] : [],
            'error' => empty($data['ok']) ? (string) ($data['error'] ?? '') : '',
        ], 'user');
    }

    public function messageRoom(string $threadId): void
    {
        require_login();
        if (request_method() === 'POST') {
            verify_csrf();
            $body = trim((string) ($_POST['body'] ?? ''));
            if ($body !== '') {
                api_client()->post('chat/messages', [
                    'thread_id' => $threadId,
                    'body' => $body,
                ], auth_token());
            }
            redirect_to('/messages/' . $threadId);
        }
        $data = api_client()->get('chat/messages', ['thread_id' => $threadId], auth_token());
        api_client()->post('chat/thread/read', ['thread_id' => $threadId], auth_token());
        $this->view('user/message-room', [
            'title' => 'محادثة',
            'threadId' => $threadId,
            'messages' => is_array($data['items'] ?? null) ? $data['items'] : [],
            'thread' => is_array($data['thread'] ?? null) ? $data['thread'] : [],
            'error' => empty($data['ok']) ? (string) ($data['error'] ?? '') : '',
        ], 'user');
    }
}
