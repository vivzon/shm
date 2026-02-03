<?php

use App\Core\Router;

// Dashboard
Router::get('/dashboard', ['App\Modules\Client\Controllers\DashboardController', 'index']);

// Domains
Router::get('/domains', ['App\Modules\Client\Controllers\DomainsController', 'index']);
Router::post('/domains', ['App\Modules\Client\Controllers\DomainsController', 'action']);

// Databases
Router::get('/databases', ['App\Modules\Client\Controllers\DatabasesController', 'index']);
Router::post('/databases', ['App\Modules\Client\Controllers\DatabasesController', 'action']);

// Emails
Router::get('/emails', ['App\Modules\Client\Controllers\EmailsController', 'index']);
Router::post('/emails', ['App\Modules\Client\Controllers\EmailsController', 'action']);

// Files
Router::get('/files', ['App\Modules\Client\Controllers\FilesController', 'index']);
Router::post('/files', ['App\Modules\Client\Controllers\FilesController', 'action']);

// Editor
Router::get('/editor', ['App\Modules\Client\Controllers\EditorController', 'index']);
Router::post('/editor', ['App\Modules\Client\Controllers\EditorController', 'index']);

// Backups
Router::get('/backups', ['App\Modules\Client\Controllers\BackupsController', 'index']);
Router::post('/backups', ['App\Modules\Client\Controllers\BackupsController', 'action']);

// Security
Router::get('/security', ['App\Modules\Client\Controllers\SecurityController', 'index']);
Router::post('/security', ['App\Modules\Client\Controllers\SecurityController', 'action']);

// DNS Management
Router::get('/dns', ['App\Modules\Client\Controllers\DnsController', 'index']);
Router::post('/dns', ['App\Modules\Client\Controllers\DnsController', 'action']);
