<?php
declare(strict_types=1);

use App\Controllers\AuthController;
use App\Controllers\CompoundController;
use App\Controllers\HomeController;
use App\Controllers\MapController;
use App\Controllers\NewsController;
use App\Controllers\OfficeController;
use App\Controllers\PageController;
use App\Controllers\ParcelController;
use App\Controllers\PropertyController;
use App\Controllers\ReelController;
use App\Controllers\User\AccountController;
use App\Controllers\User\ChatController;
use App\Controllers\User\DashboardController as UserDashboardController;
use App\Controllers\User\PropertyFormController;
use App\Controllers\User\PropertyRequestController;
use App\Core\Router;
use App\Middleware\AuthMiddleware;

return static function (Router $router): void {
    $router->get('/', [HomeController::class, 'index']);

    $router->get('/search', [PropertyController::class, 'search']);
    $router->get('/properties', [PropertyController::class, 'index']);
    $router->get('/property/{id}', [PropertyController::class, 'show']);
    $router->post('/property/{id}/contact', [PropertyController::class, 'contact'], [AuthMiddleware::class]);

    $router->get('/map', [MapController::class, 'index']);
    $router->get('/reels', [ReelController::class, 'index']);
    $router->get('/reels/{id}', [ReelController::class, 'show']);
    $router->post('/reels/view', [ReelController::class, 'apiView']);
    $router->post('/reels/react', [ReelController::class, 'apiReact'], [AuthMiddleware::class]);

    $router->get('/parcels', [ParcelController::class, 'index']);
    $router->get('/parcels/{id}', [ParcelController::class, 'show']);
    $router->get('/compounds', [CompoundController::class, 'index']);
    $router->get('/compounds/{id}', [CompoundController::class, 'show']);

    $router->get('/offices', [OfficeController::class, 'index']);
    $router->get('/office/{id}', [OfficeController::class, 'show']);
    $router->get('/marketers', [OfficeController::class, 'marketers']);
    $router->get('/marketer/{id}', [OfficeController::class, 'marketerShow']);

    $router->get('/news/{id}', [NewsController::class, 'show']);

    $router->get('/about', [PageController::class, 'about']);
    $router->get('/contact', [PageController::class, 'contact']);
    $router->get('/privacy', [PageController::class, 'privacy']);
    $router->get('/terms', [PageController::class, 'terms']);

    $router->get('/login', [AuthController::class, 'loginForm']);
    $router->post('/login', [AuthController::class, 'loginSubmit']);
    $router->get('/register', [AuthController::class, 'registerForm']);
    $router->post('/register', [AuthController::class, 'registerSubmit']);
    $router->get('/logout', [AuthController::class, 'logout']);

    $router->get('/user', [UserDashboardController::class, 'index'], [AuthMiddleware::class]);
    $router->get('/user/office', [UserDashboardController::class, 'office'], [AuthMiddleware::class]);
    $router->get('/user/marketer', [UserDashboardController::class, 'marketer'], [AuthMiddleware::class]);

    $router->get('/profile', [AccountController::class, 'profile'], [AuthMiddleware::class]);
    $router->post('/profile', [AccountController::class, 'profileSubmit'], [AuthMiddleware::class]);
    $router->get('/favorites', [AccountController::class, 'favorites'], [AuthMiddleware::class]);
    $router->post('/favorites/toggle', [AccountController::class, 'favoritesToggle'], [AuthMiddleware::class]);
    $router->get('/notifications', [AccountController::class, 'notifications'], [AuthMiddleware::class]);
    $router->get('/notifications/api/poll', [AccountController::class, 'notificationsPoll'], [AuthMiddleware::class]);

    $router->get('/messages', [ChatController::class, 'index'], [AuthMiddleware::class]);
    $router->get('/messages/api/threads', [ChatController::class, 'apiThreads'], [AuthMiddleware::class]);
    $router->post('/messages/api/open', [ChatController::class, 'apiOpen'], [AuthMiddleware::class]);
    $router->get('/messages/api/{threadId}', [ChatController::class, 'apiMessages'], [AuthMiddleware::class]);
    $router->post('/messages/api/{threadId}/send', [ChatController::class, 'apiSend'], [AuthMiddleware::class]);
    $router->post('/messages/api/{threadId}/upload', [ChatController::class, 'apiUpload'], [AuthMiddleware::class]);

    $router->get('/request-property', [PropertyRequestController::class, 'form'], [AuthMiddleware::class]);
    $router->post('/request-property', [PropertyRequestController::class, 'submit'], [AuthMiddleware::class]);
    $router->get('/my-requests', [PropertyRequestController::class, 'mine'], [AuthMiddleware::class]);

    $router->get('/property/add', [PropertyFormController::class, 'createForm'], [AuthMiddleware::class]);
    $router->post('/property/add', [PropertyFormController::class, 'createSubmit'], [AuthMiddleware::class]);

    $router->get('/dashboard', static function (): void {
        redirect_to(dashboard_path(auth_user()));
    });
};
