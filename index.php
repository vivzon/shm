<?php
// index.php

// 1. Always bootstrap config first (DB, session, functions, auth)
require_once __DIR__ . '/includes/config.php';

// 2. Then your routing helpers
function getPageMap(): array
{
    return [
        'login'     => 'Login',
        'dashboard' => 'Dashboard',
        'domains'   => 'Domains',
        'ssl'       => 'SSL',
        'database'  => 'Database',
        'files'     => 'Files',
        'dns'       => 'DNS',
        'users'     => 'Users',
    ];
}

function getCurrentPageSlug(): string
{
    $uri  = $_SERVER['REQUEST_URI'];
    $slug = trim(parse_url($uri, PHP_URL_PATH), '/');
    return !empty($slug) ? $slug : 'login';
}

function getPageTitle(string $slug): string
{
    $map = getPageMap();
    if (isset($map[$slug])) {
        return $map[$slug];
    }
    return ucwords(str_replace('-', ' ', $slug));
}

function loadPage(string $slug): void
{
    $map      = getPageMap();
    $isAllowed = isset($map[$slug]);
    $file      = __DIR__ . '/pages/' . $slug . '.php';

    if ($isAllowed && file_exists($file)) {
        $pageTitle = getPageTitle($slug);
    } else {
        http_response_code(404);
        $slug      = '404';
        $file      = __DIR__ . '/pages/404.php';
        $pageTitle = 'Page Not Found';
    }

    // for all non-public pages, enforce login & show header/footer
    if ($slug !== 'login' && $slug !== '404') {
        require_login(); // from auth.php
        require_once __DIR__ . '/includes/header.php';
    }

    // main page content
    require_once $file;

    if ($slug !== 'login' && $slug !== '404') {
        require_once __DIR__ . '/includes/footer.php';
    }
}

$slug = getCurrentPageSlug();
loadPage($slug);
