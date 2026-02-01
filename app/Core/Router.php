<?php

namespace App\Core;

class Router
{
    private static $routes = [];

    public static function get($path, $callback)
    {
        self::$routes['GET'][$path] = $callback;
    }

    public static function post($path, $callback)
    {
        self::$routes['POST'][$path] = $callback;
    }

    public static function dispatch()
    {
        $uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
        $method = $_SERVER['REQUEST_METHOD'];

        // Normalize URI (remove trailing slash except for root)
        if ($uri !== '/' && substr($uri, -1) === '/') {
            $uri = rtrim($uri, '/');
        }

        foreach (self::$routes[$method] ?? [] as $route => $callback) {
            // Convert route parameters (e.g., /user/{id}) to regex
            $pattern = preg_replace('/\{([a-zA-Z0-9_]+)\}/', '(?P<$1>[^/]+)', $route);
            $pattern = "#^" . $pattern . "$#";

            if (preg_match($pattern, $uri, $matches)) {
                // Filter named matches
                $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);

                if (is_array($callback)) {
                    $controller = new $callback[0];
                    $method = $callback[1];
                    return call_user_func_array([$controller, $method], $params);
                }

                return call_user_func_array($callback, $params);
            }
        }

        self::handleNotFound();
    }

    private static function handleNotFound()
    {
        http_response_code(404);
        echo "404 Not Found";
    }
}
