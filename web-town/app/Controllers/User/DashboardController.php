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
        $this->view('user/office', ['title' => 'لوحة المكتب', 'user' => $user], 'user');
    }

    public function marketer(): void
    {
        $user = require_account_kind(['marketer']);
        $this->view('user/marketer', ['title' => 'لوحة المسوق', 'user' => $user], 'user');
    }
}
