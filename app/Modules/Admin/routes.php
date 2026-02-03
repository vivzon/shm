<?php

use App\Core\Router;

// Dashboard
Router::get('/admin/dashboard', ['App\Modules\Admin\Controllers\DashboardController', 'index']);

// Accounts
Router::get('/admin/accounts', ['App\Modules\Admin\Controllers\AccountsController', 'index']);
Router::post('/admin/accounts', ['App\Modules\Admin\Controllers\AccountsController', 'action']);

// Packages
Router::get('/admin/packages', ['App\Modules\Admin\Controllers\PackagesController', 'index']);
Router::post('/admin/packages', ['App\Modules\Admin\Controllers\PackagesController', 'action']);

// Services
Router::get('/admin/services', ['App\Modules\Admin\Controllers\ServicesController', 'index']);
Router::post('/admin/services', ['App\Modules\Admin\Controllers\ServicesController', 'action']);

// Tools
Router::get('/admin/tools', ['App\Modules\Admin\Controllers\ToolsController', 'index']);
Router::post('/admin/tools', ['App\Modules\Admin\Controllers\ToolsController', 'action']);

// Logs
Router::get('/admin/logs', ['App\Modules\Admin\Controllers\LogsController', 'index']);
Router::post('/admin/logs', ['App\Modules\Admin\Controllers\LogsController', 'action']);

// Resellers
Router::get('/admin/resellers', ['App\Modules\Admin\Controllers\ResellersController', 'index']);
Router::post('/admin/resellers', ['App\Modules\Admin\Controllers\ResellersController', 'action']);
