<?php

declare(strict_types=1);



use App\Controllers\Admin\DashboardController;

use App\Controllers\User\ChatController;

use App\Core\Router;

use App\Middleware\AdminMiddleware;



return static function (Router $router): void {

    $router->get('/admin/api/chat/threads', [ChatController::class, 'apiThreads'], [AdminMiddleware::class]);

    $router->get('/admin/api/chat/{threadId}', [ChatController::class, 'apiMessages'], [AdminMiddleware::class]);

    $router->post('/admin/api/chat/{threadId}/send', [ChatController::class, 'apiSend'], [AdminMiddleware::class]);

    $router->post('/admin/api/chat/{threadId}/upload', [ChatController::class, 'apiUpload'], [AdminMiddleware::class]);



    $router->get('/admin', [DashboardController::class, 'index'], [AdminMiddleware::class]);

    $router->get('/admin/{section}', [DashboardController::class, 'section'], [AdminMiddleware::class]);

    $router->post('/admin/{section}', [DashboardController::class, 'section'], [AdminMiddleware::class]);

};

