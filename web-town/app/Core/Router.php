<?php
declare(strict_types=1);

namespace App\Core;

final class Router
{
    /** @var array<int,array{method:string,path:string,handler:callable|array{0:class-string|object,1:string},middleware:array<int,string>}> */
    private array $routes = [];

    /** @param callable|array{0:class-string|object,1:string} $handler */
    public function get(string $path, callable|array $handler, array $middleware = []): self
    {
        return $this->add('GET', $path, $handler, $middleware);
    }

    /** @param callable|array{0:class-string|object,1:string} $handler */
    public function post(string $path, callable|array $handler, array $middleware = []): self
    {
        return $this->add('POST', $path, $handler, $middleware);
    }

    /** @param callable|array{0:class-string|object,1:string} $handler */
    public function add(string $method, string $path, callable|array $handler, array $middleware = []): self
    {
        $this->routes[] = [
            'method' => strtoupper($method),
            'path' => $this->normalize($path),
            'handler' => $handler,
            'middleware' => $middleware,
        ];

        return $this;
    }

    public function dispatch(string $method, string $uri): void
    {
        $method = strtoupper($method);
        $path = $this->normalize(parse_url($uri, PHP_URL_PATH) ?: '/');

        foreach ($this->routes as $route) {
            if ($route['method'] !== $method && $route['method'] !== 'ANY') {
                continue;
            }
            $params = $this->match($route['path'], $path);
            if ($params === null) {
                continue;
            }
            foreach ($route['middleware'] as $mw) {
                $mw::handle();
            }
            $handler = $route['handler'];
            if (is_array($handler) && count($handler) === 2 && is_string($handler[0])) {
                $controller = new $handler[0]();
                $action = $handler[1];
                $controller->{$action}(...array_values($params));
            } elseif (is_callable($handler)) {
                $handler(...array_values($params));
            }
            return;
        }

        http_response_code(404);
        View::render('errors/404', ['title' => 'الصفحة غير موجودة']);
    }

    private function normalize(string $path): string
    {
        $path = '/' . trim($path, '/');
        return $path === '/' ? '/' : rtrim($path, '/');
    }

    /** @return array<string,string>|null */
    private function match(string $pattern, string $path): ?array
    {
        if ($pattern === $path) {
            return [];
        }
        $regex = preg_replace('#\{([a-zA-Z_]+)\}#', '(?P<$1>[^/]+)', $pattern);
        $regex = '#^' . $regex . '$#';
        if (!preg_match($regex, $path, $m)) {
            return null;
        }
        $params = [];
        foreach ($m as $k => $v) {
            if (!is_int($k)) {
                $params[$k] = (string) $v;
            }
        }

        return $params;
    }
}
