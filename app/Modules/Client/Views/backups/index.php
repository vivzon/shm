<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="flex justify-between items-center mb-8">
    <h2 class="text-2xl font-bold text-white">Backups</h2>
    <form onsubmit="handleGeneric(event, 'create_backup')">
        <button
            class="bg-blue-600 hover:bg-blue-500 text-white px-5 py-3 rounded-xl font-bold shadow-lg shadow-blue-600/20 flex items-center gap-2 transition">
            <i data-lucide="plus-circle" class="w-4"></i> Create Backup
        </button>
    </form>
</div>

<div class="glass-panel overflow-hidden rounded-2xl">
    <table class="w-full text-left">
        <thead class="bg-slate-900/50 text-[10px] font-bold uppercase text-slate-400 border-b border-slate-800">
            <tr>
                <th class="p-4">Filename</th>
                <th class="p-4">Size</th>
                <th class="p-4 text-right">Actions</th>
            </tr>
        </thead>
        <tbody id="backup-list" class="divide-y divide-slate-800/50">
            <tr>
                <td class="p-4 text-center text-slate-500" colspan="3">Loading...</td>
            </tr>
        </tbody>
    </table>
</div>

<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>

<script>
    async function loadBackups() {
        const list = document.getElementById('backup-list');
        const fd = new FormData(); fd.append('ajax_action', 'list_backups');
        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            list.innerHTML = '';
            if (res.data && res.data.length > 0) {
                res.data.forEach(b => {
                    const safeName = b.name.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
                    list.innerHTML += `
                            <tr class="hover:bg-slate-800/30 transition">
                                <td class="p-4 font-bold text-slate-300">${safeName}</td>
                                <td class="p-4 text-slate-400 text-xs">${b.size}</td>
                                <td class="p-4 text-right">
                                    <button onclick="restoreBackup('${safeName}')" class="text-blue-400 font-bold text-xs uppercase hover:text-white mr-4 transition">Restore</button>
                                </td>
                            </tr>
                        `;
                });
                lucide.createIcons();
            } else {
                list.innerHTML = '<tr><td colspan="3" class="p-4 text-center text-slate-500">No backups found.</td></tr>';
            }
        } catch (e) { list.innerHTML = '<tr><td colspan="3" class="p-4 text-center text-red-400">Error loading.</td></tr>'; }
    }

    async function restoreBackup(file) {
        if (!confirm('Restoring will overwrite current files and DBs. Continue?')) return;
        const fd = new FormData();
        fd.append('ajax_action', 'restore_backup');
        fd.append('file', file);

        showToast('info', 'Processing...', 'Restore job started.');
        await fetch('', { method: 'POST', body: fd });
        showToast('success', 'Restore Initiated', 'System is restoring backup.');
    }

    // Hook into generic handler to reload list on create
    // We can't overwrite handleGeneric globally if it's in app.js, but we can wrap the submit logic or use event listener
    // The previous code had:  <form onsubmit="handleGeneric(event, 'create_backup')">
    // We can change the onsubmit to a local function wrapper

    const _originalSubmit = window.handleGeneric; // wait, handleGeneric is defined in app.js? Yes.
    // Actually we can just add an event listener for custom event if we emitted one, but we don't.
    // Simplest: Custom submit handler inline

    document.querySelector('form').onsubmit = async function (e) {
        e.preventDefault();
        await handleGeneric(e, 'create_backup');
        setTimeout(loadBackups, 2000);
    };

    loadBackups();
</script>