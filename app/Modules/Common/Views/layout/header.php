<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
// Auth Check Helper
function isAuthenticated()
{
    return isset($_SESSION['client']) || isset($_SESSION['admin']);
}
if (!isAuthenticated() && !strpos($_SERVER['REQUEST_URI'], 'login')) {
    // Basic catch-all, though Controller should handle redirects.
    // This view might be rendered by a controller that already checked auth.
}

$username = $_SESSION['client'] ?? $_SESSION['admin'] ?? 'Guest';
$isAdmin = isset($_SESSION['admin']);
$current_page = basename($_SERVER['REQUEST_URI']);
// Simple URI check for active class logic
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>
        <?= get_branding() ?> | SHM Portal
    </title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/lucide@latest"></script>
    <link href="/assets/css/app.css" rel="stylesheet">
</head>

<body class="flex h-screen overflow-hidden text-sm">

    <!-- Sidebar -->
    <?php
    if ($isAdmin) {
        include __DIR__ . '/sidebar_admin.php';
    } else {
        include __DIR__ . '/sidebar_client.php';
    }
    ?>

    <main class="flex-1 flex flex-col h-full bg-[#020617] relative overflow-hidden">
        <!-- Top Header -->
        <header
            class="h-16 px-8 flex items-center justify-between border-b border-slate-900 bg-slate-950/50 backdrop-blur-md sticky top-0 z-10 w-full">
            <div class="flex items-center gap-4">
                <span class="relative flex h-2.5 w-2.5">
                    <span
                        class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
                </span>
                <span class="text-[10px] font-bold text-emerald-500 font-mono tracking-widest uppercase">System
                    Online</span>
            </div>
            <div class="flex items-center gap-4">
                <div
                    class="flex items-center gap-2 px-3 py-1.5 bg-slate-900/50 rounded-full border border-slate-800 hover:border-slate-700 transition cursor-pointer">
                    <div
                        class="w-6 h-6 rounded-full bg-gradient-to-tr from-blue-600 to-indigo-600 flex items-center justify-center text-[10px] font-bold text-white shadow-lg shadow-blue-500/20">
                        <?= strtoupper(substr($username, 0, 1)) ?>
                    </div>
                    <span class="text-xs font-semibold text-slate-300 pr-1">
                        <?= $username ?>
                    </span>
                    <i data-lucide="chevron-down" class="w-3 h-3 text-slate-500"></i>
                </div>
            </div>
        </header>

        <div class="flex-1 overflow-y-auto p-8 pb-24 custom-scrollbar">