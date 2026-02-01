<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="mb-8">
    <h1 class="text-2xl font-bold text-white font-heading">Dashboard</h1>
    <p class="text-slate-400 text-sm">Welcome back,
        <?= htmlspecialchars($_SESSION['client']) ?>
    </p>
</div>

<div class="grid grid-cols-1 md:grid-cols-3 gap-6">
    <!-- Quick Links -->
    <a href="/domains" class="glass-panel p-6 hover:bg-slate-800/50 transition group">
        <div
            class="w-12 h-12 rounded-xl bg-blue-600/20 text-blue-400 flex items-center justify-center mb-4 group-hover:scale-110 transition">
            <i data-lucide="globe" class="w-6 h-6"></i>
        </div>
        <h3 class="font-bold text-white text-lg mb-1">Domains</h3>
        <p class="text-slate-500 text-xs">Manage your websites and DNS zones</p>
    </a>

    <a href="/files" target="_blank" class="glass-panel p-6 hover:bg-slate-800/50 transition group">
        <div
            class="w-12 h-12 rounded-xl bg-purple-600/20 text-purple-400 flex items-center justify-center mb-4 group-hover:scale-110 transition">
            <i data-lucide="folder-open" class="w-6 h-6"></i>
        </div>
        <h3 class="font-bold text-white text-lg mb-1">File Manager</h3>
        <p class="text-slate-500 text-xs">Upload and edit files</p>
    </a>

    <a href="/tools/apps" class="glass-panel p-6 hover:bg-slate-800/50 transition group">
        <div
            class="w-12 h-12 rounded-xl bg-emerald-600/20 text-emerald-400 flex items-center justify-center mb-4 group-hover:scale-110 transition">
            <i data-lucide="box" class="w-6 h-6"></i>
        </div>
        <h3 class="font-bold text-white text-lg mb-1">Apps</h3>
        <p class="text-slate-500 text-xs">One-click installers</p>
    </a>
</div>

<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>