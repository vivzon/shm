<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="flex justify-between items-center mb-8 gap-4">
    <div>
        <h2 class="text-2xl font-bold text-white font-heading">Domains</h2>
        <p class="text-slate-400 text-sm">Manage your websites and DNS</p>
    </div>
    <button onclick="document.getElementById('addDomainModal').classList.remove('hidden')"
        class="bg-blue-600 hover:bg-blue-500 text-white px-5 py-2.5 rounded-xl font-bold shadow-lg shadow-blue-900/20 text-sm flex items-center gap-2 transition border border-blue-500/50">
        <i data-lucide="plus-circle" class="w-4"></i> Add Domain
    </button>
</div>

<div class="glass-panel rounded-2xl overflow-hidden mb-8">
    <table class="w-full text-left border-collapse">
        <thead
            class="bg-slate-900/50 text-slate-400 text-[10px] font-bold uppercase tracking-widest border-b border-slate-800">
            <tr>
                <th class="p-5">Domain Name</th>
                <th class="p-5">Document Root</th>
                <th class="p-5">Status</th>
                <th class="p-5 text-right">Actions</th>
            </tr>
        </thead>
        <tbody class="divide-y divide-slate-800/50">
            <?php foreach ($domains as $d): ?>
                <tr class="hover:bg-slate-800/30 transition">
                    <td class="p-5 font-bold text-white text-sm">
                        <a href="http://<?= $d['domain'] ?>" target="_blank"
                            class="hover:text-blue-400 flex items-center gap-2">
                            <?= htmlspecialchars($d['domain']) ?>
                            <i data-lucide="external-link" class="w-3 text-slate-600"></i>
                        </a>
                    </td>
                    <td class="p-5 text-slate-400 text-xs font-mono">
                        <?= htmlspecialchars($d['document_root']) ?>
                    </td>
                    <td class="p-5">
                        <span
                            class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-500 border border-emerald-500/20">
                            Active
                        </span>
                    </td>
                    <td class="p-5 text-right flex justify-end gap-2">
                        <button disabled class="p-2 hover:bg-slate-800 text-slate-500 rounded-lg transition"
                            title="DNS Manager (Coming Soon)">
                            <i data-lucide="settings" class="w-4"></i>
                        </button>
                        <button onclick="deleteDomain(<?= $d['id'] ?>, '<?= $d['domain'] ?>')"
                            class="p-2 hover:bg-red-500/10 text-slate-400 hover:text-red-400 rounded-lg transition">
                            <i data-lucide="trash-2" class="w-4"></i>
                        </button>
                    </td>
                </tr>
            <?php endforeach; ?>
            <?php if (empty($domains)): ?>
                <tr>
                    <td colspan="4" class="p-8 text-center text-slate-500 text-sm">No domains found. Add one to get started.
                    </td>
                </tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<!-- Add Domain Modal -->
<div id="addDomainModal"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm hidden">
    <div class="glass-panel p-8 rounded-2xl w-full max-w-md relative animate-[fadeIn_0.2s_ease-out]">
        <button onclick="document.getElementById('addDomainModal').classList.add('hidden')"
            class="absolute top-4 right-4 text-slate-500 hover:text-white">
            <i data-lucide="x" class="w-5"></i>
        </button>

        <h3 class="text-xl font-bold text-white mb-6">Add New Domain</h3>

        <form onsubmit="handleGeneric(event, 'add_domain')">
            <div class="space-y-4">
                <div>
                    <label class="block text-xs font-bold text-slate-400 mb-2">Domain Name</label>
                    <input name="domain" type="text" placeholder="example.com" required
                        class="w-full bg-slate-900/50 border border-slate-700 rounded-xl px-4 py-3 text-white focus:border-blue-500 outline-none transition">
                </div>
                <div>
                    <label class="block text-xs font-bold text-slate-400 mb-2">Document Root (Optional)</label>
                    <input name="path" type="text" placeholder="/var/www/clients/..."
                        class="w-full bg-slate-900/50 border border-slate-700 rounded-xl px-4 py-3 text-white focus:border-blue-500 outline-none transition font-mono text-xs">
                    <p class="text-[10px] text-slate-600 mt-1">Leave empty for auto-generated path.</p>
                </div>
            </div>

            <button type="submit"
                class="mt-8 w-full bg-blue-600 hover:bg-blue-500 text-white font-bold py-3 rounded-xl transition shadow-lg shadow-blue-600/20">
                Create Domain
            </button>
        </form>
    </div>
</div>

<script>
    async function deleteDomain(id, name) {
        if (!confirm(`Delete ${name}? This cannot be undone.`)) return;

        // Manual fetch as handleGeneric wraps Form events
        const fd = new FormData();
        fd.append('ajax_action', 'delete_domain');
        fd.append('id', id);

        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            if (res.status === 'success') {
                location.reload();
            } else {
                alert(res.msg);
            }
        } catch (e) {
            alert('Error');
        }
    }
</script>

<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>