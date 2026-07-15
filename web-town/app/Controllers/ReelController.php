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
}
