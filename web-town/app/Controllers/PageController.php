<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Controller;

final class PageController extends Controller
{
    public function about(): void
    {
        $this->view('pages/about', ['title' => 'من نحن']);
    }

    public function contact(): void
    {
        $this->view('pages/contact', ['title' => 'تواصل معنا']);
    }

    public function privacy(): void
    {
        $this->view('pages/privacy', ['title' => 'سياسة الخصوصية']);
    }

    public function terms(): void
    {
        $this->view('pages/terms', ['title' => 'الشروط والأحكام']);
    }
}
