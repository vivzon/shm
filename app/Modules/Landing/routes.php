<?php

use App\Core\Router;

// Home
Router::get('/', ['App\Modules\Landing\Controllers\HomeController', 'index']);

// Checkout
Router::get('/checkout', ['App\Modules\Landing\Controllers\CheckoutController', 'index']);
Router::post('/checkout/process', ['App\Modules\Landing\Controllers\CheckoutController', 'process']);
