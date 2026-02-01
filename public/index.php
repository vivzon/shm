<?php

// Public Entry Point

require_once __DIR__ . '/../bootstrap/app.php';

use App\Core\Router;

// Load Routes
require_once __DIR__ . '/../config/routes.php';

// Dispatch
Router::dispatch();
