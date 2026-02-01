<?php

use App\Core\Router;

// Client Auth
Router::get('/login', ['App\Modules\Auth\Controllers\AuthController', 'login']);
Router::post('/login', ['App\Modules\Auth\Controllers\AuthController', 'authenticate']);
Router::get('/logout', ['App\Modules\Auth\Controllers\AuthController', 'logout']);

// Admin Auth
Router::get('/admin/login', ['App\Modules\Auth\Controllers\AuthController', 'adminLogin']);
Router::post('/admin/login', ['App\Modules\Auth\Controllers\AuthController', 'adminAuthenticate']);
Router::get('/admin/logout', ['App\Modules\Auth\Controllers\AuthController', 'adminLogout']);
