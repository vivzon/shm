<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<h2 class="text-2xl font-bold mb-8 text-white font-heading">Service Engine</h2>
<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
    <?php foreach ($services as $id => $name):
        $active = $serviceStatus[$id] ?? false; ?>
        <div
            class="glass-panel p-6 rounded-2xl flex justify-between items-center group hover:border-blue-500/30 transition">
            <div class="flex items-center gap-4">
                <div class="relative">
                    <div
                        class="w-3 h-3 rounded-full <?= $active ? 'bg-emerald-500 shadow-[0_0_10px_#10b981]' : 'bg-red-500 shadow-[0_0_10px_#ef4444]' ?>">
                    </div>
                    <div
                        class="w-3 h-3 rounded-full <?= $active ? 'bg-emerald-500' : 'bg-red-500' ?> absolute top-0 animate-ping opacity-75">
                    </div>
                </div>
                <div>
                    <p class="font-bold text-lg text-white group-hover:text-blue-400 transition">
                        <?= $name ?>
                    </p>
                    <p class="text-slate-500 text-[10px] font-mono uppercase tracking-widest">
                        <?= $id ?>
                    </p>
                </div>
            </div>
            <div class="flex gap-2">
                <button onclick="servAction('<?= $id ?>','restart')" title="Restart"
                    class="p-3 bg-slate-800 rounded-xl text-blue-400 hover:text-white hover:bg-blue-600 transition-all border border-slate-700 shadow-lg">
                    <i data-lucide="refresh-cw" class="w-4 h-4"></i>
                </button>
                <button onclick="servAction('<?= $id ?>','stop')" title="Stop"
                    class="p-3 bg-slate-800 rounded-xl text-red-500 hover:text-white hover:bg-red-600 transition-all border border-slate-700 shadow-lg">
                    <i data-lucide="power" class="w-4 h-4"></i>
                </button>
            </div>
        </div>
    <?php endforeach; ?>
</div>

<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>

<script>
    function servAction(srv, op) {
        showToast('success', 'Service command sent: ' + op);
        const fd = new FormData();
        fd.append('ajax_action', 'service_action');
        fd.append('service', srv);
        fd.append('op', op);
        fetch('', { method: 'POST', body: fd })
            .then(r => r.json())
            .then(res => {
                if (res.status === 'success') {
                    // Maybe reload after few seconds to show new status?
                    setTimeout(() => location.reload(), 3000);
                }
            });
    }
</script>