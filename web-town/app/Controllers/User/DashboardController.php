<?php
declare(strict_types=1);

namespace App\Controllers\User;

use App\Core\Controller;

final class DashboardController extends Controller
{
    public function index(): void
    {
        $user = require_account_kind(['customer']);
        $this->view('user/customer', ['title' => 'لوحة الزبون', 'user' => $user], 'user');
    }

    public function office(): void
    {
        $user = require_account_kind(['office']);
        $myProps = api_client()->get('properties/list', [
            'owner_id' => (string) ($user['id'] ?? ''),
            'include_mine' => '1',
            'limit' => 50,
        ], auth_token());
        $myReels = api_client()->get('reels/list', [
            'owner_id' => (string) ($user['id'] ?? ''),
            'include_mine' => '1',
            'limit' => 50,
        ], auth_token());
        $this->view('user/office', [
            'title' => 'لوحة المكتب',
            'user' => $user,
            'properties' => $myProps['items'] ?? [],
            'reels' => $myReels['items'] ?? [],
        ], 'user');
    }

    public function marketer(): void
    {
        $user = require_account_kind(['marketer']);
        $myProps = api_client()->get('properties/list', [
            'owner_id' => (string) ($user['id'] ?? ''),
            'include_mine' => '1',
            'limit' => 50,
        ], auth_token());
        $myReels = api_client()->get('reels/list', [
            'owner_id' => (string) ($user['id'] ?? ''),
            'include_mine' => '1',
            'limit' => 50,
        ], auth_token());
        $this->view('user/marketer', [
            'title' => 'لوحة المسوق',
            'user' => $user,
            'properties' => $myProps['items'] ?? [],
            'reels' => $myReels['items'] ?? [],
        ], 'user');
    }
}
