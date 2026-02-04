<?php

use App\Http\Controllers\DomainController;
use App\Http\Controllers\DashboardController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect()->route('dashboard');
});

Route::middleware(['auth'])->group(function () {
    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

    Route::prefix('domains')->name('domains.')->group(function () {
        Route::get('/', [DomainController::class, 'index'])->name('index');
        Route::post('/', [DomainController::class, 'store'])->name('store');
        Route::post('/{domain}/ssl', [DomainController::class, 'issueSsl'])->name('ssl');
    });

    Route::prefix('databases')->name('databases.')->group(function () {
        Route::get('/', [DatabaseController::class, 'index'])->name('index');
        Route::post('/', [DatabaseController::class, 'store'])->name('store');
    });

    Route::prefix('emails')->name('emails.')->group(function () {
        Route::get('/', [EmailController::class, 'index'])->name('index');
        Route::post('/', [EmailController::class, 'store'])->name('store');
    });

    Route::prefix('dns')->name('dns.')->group(function () {
        Route::get('/', [DnsController::class, 'index'])->name('index');
        Route::get('/{domain}', [DnsController::class, 'show'])->name('show');
        Route::post('/{domain}', [DnsController::class, 'store'])->name('store');
    });

    Route::prefix('backups')->name('backups.')->group(function () {
        Route::get('/', [BackupController::class, 'index'])->name('index');
        Route::post('/', [BackupController::class, 'store'])->name('store');
        Route::get('/{backup}/download', [BackupController::class, 'download'])->name('download');
    });

    Route::prefix('filemanager')->name('filemanager.')->group(function () {
        Route::get('/', [FileManagerController::class, 'index'])->name('index');
        Route::post('/upload', [FileManagerController::class, 'upload'])->name('upload');
        Route::delete('/delete', [FileManagerController::class, 'delete'])->name('delete');
    });

    Route::prefix('cron')->name('cron.')->group(function () {
        Route::get('/', [CronController::class, 'index'])->name('index');
        Route::post('/', [CronController::class, 'store'])->name('store');
        Route::delete('/{lineNum}', [CronController::class, 'destroy'])->name('destroy');
    });
});
