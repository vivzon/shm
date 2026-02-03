<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="mb-8 flex flex-col md:flex-row md:items-center justify-between gap-4">
    <div>
        <h2 class="text-2xl font-bold text-white mb-2">DNS Zone Editor</h2>
        <p class="text-slate-400 text-sm">Manage DNS records for your domains.</p>
    </div>
    <div class="flex items-center gap-3">
        <label class="text-xs font-bold text-slate-500 uppercase tracking-widest">Select Domain:</label>
        <select onchange="window.location.href='?domain_id=' + this.value"
            class="bg-slate-900 border border-slate-700 p-2.5 rounded-lg text-sm text-slate-200 outline-none focus:border-blue-500 min-w-[200px]">
            <option value="">-- Choose Domain --</option>
            <?php foreach ($domains as $d): ?>
                <option value="<?= $d['id'] ?>" <?= $selected_domain == $d['id'] ? 'selected' : '' ?>>
                    <?= htmlspecialchars($d['domain']) ?>
                </option>
            <?php endforeach; ?>
        </select>
    </div>
</div>

<?php if ($selected_domain):
    $curDom = null;
    foreach ($domains as $d) {
        if ($d['id'] == $selected_domain) {
            $curDom = $d;
            break;
        }
    }
    ?>
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- ADD RECORD FORM -->
        <div class="space-y-6">
            <div class="glass-card p-6 rounded-2xl border border-slate-700/50">
                <h3 class="font-bold text-white mb-6 flex items-center gap-2">
                    <i data-lucide="plus-circle" class="w-5 h-5 text-blue-500"></i>
                    Add New Record
                </h3>
                <form onsubmit="handleRecordAdd(event)" class="space-y-4">
                    <input type="hidden" name="domain_id" value="<?= $selected_domain ?>">

                    <div>
                        <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Record Type</label>
                        <select name="type" required
                            class="w-full bg-slate-900/50 border border-slate-700 p-3 rounded-xl outline-none focus:border-blue-500 text-slate-200">
                            <option value="A">A (Address)</option>
                            <option value="AAAA">AAAA (IPv6 Address)</option>
                            <option value="CNAME">CNAME (Canonical Name)</option>
                            <option value="MX">MX (Mail Exchange)</option>
                            <option value="TXT">TXT (Text)</option>
                        </select>
                    </div>

                    <div>
                        <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Host / Name</label>
                        <div class="relative">
                            <input name="host" required placeholder="e.g. www"
                                class="w-full bg-slate-900/50 border border-slate-700 p-3 rounded-xl outline-none focus:border-blue-500 text-white placeholder-slate-600">
                            <div class="absolute right-3 top-3 text-xs text-slate-500 font-mono">.
                                <?= htmlspecialchars($curDom['domain'] ?? '') ?>
                            </div>
                        </div>
                    </div>

                    <div>
                        <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Value / Target</label>
                        <input name="value" required placeholder="e.g. 1.2.3.4 or target.com"
                            class="w-full bg-slate-900/50 border border-slate-700 p-3 rounded-xl outline-none focus:border-blue-500 text-white placeholder-slate-600">
                    </div>

                    <div id="priority-field" class="hidden">
                        <label class="block text-xs font-bold text-slate-500 uppercase mb-2">Priority</label>
                        <input name="priority" type="number" value="10"
                            class="w-full bg-slate-900/50 border border-slate-700 p-3 rounded-xl outline-none focus:border-blue-500 text-white placeholder-slate-600">
                    </div>

                    <button type="submit"
                        class="w-full bg-blue-600 hover:bg-blue-500 text-white py-3.5 rounded-xl font-bold shadow-lg shadow-blue-600/20 transition-all flex items-center justify-center gap-2">
                        Add Record
                    </button>
                </form>
            </div>
        </div>

        <!-- RECORDS LIST -->
        <div class="lg:col-span-2">
            <div class="glass-panel rounded-2xl overflow-hidden border border-slate-700/50">
                <table class="w-full text-left">
                    <thead
                        class="bg-slate-900/80 text-[10px] font-bold uppercase text-slate-400 tracking-widest border-b border-slate-800">
                        <tr>
                            <th class="p-4">Type</th>
                            <th class="p-4">Name</th>
                            <th class="p-4">Value</th>
                            <th class="p-4 text-right">Action</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-800/50">
                        <?php foreach ($records as $r): ?>
                            <tr class="hover:bg-slate-800/20 transition group">
                                <td class="p-4">
                                    <span
                                        class="px-2.5 py-1 rounded-md text-[10px] font-bold bg-slate-800 text-slate-300 border border-slate-700">
                                        <?= htmlspecialchars($r['type']) ?>
                                    </span>
                                </td>
                                <td class="p-4 text-sm font-mono text-slate-200">
                                    <?= htmlspecialchars($r['host']) ?>
                                </td>
                                <td class="p-4 text-sm text-slate-400 truncate max-w-[200px]">
                                    <?= $r['priority'] ? "<span class='text-blue-400 text-xs italic mr-1'>[{$r['priority']}]</span>" : "" ?>
                                    <?= htmlspecialchars($r['value']) ?>
                                </td>
                                <td class="p-4 text-right">
                                    <button onclick="deleteRecord(<?= $r['id'] ?>)"
                                        class="text-red-400/50 hover:text-red-400 p-2 hover:bg-red-400/10 rounded-lg transition">
                                        <i data-lucide="trash-2" class="w-4 h-4"></i>
                                    </button>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        <?php if (empty($records)): ?>
                            <tr>
                                <td colspan="4" class="p-8 text-center text-slate-500 italic">No custom records found.</td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
<?php else: ?>
    <div class="glass-panel p-12 rounded-3xl text-center border border-slate-800/50">
        <div
            class="w-16 h-16 bg-slate-900/50 rounded-2xl border border-slate-700 flex items-center justify-center mx-auto mb-6">
            <i data-lucide="search" class="w-8 h-8 text-slate-600"></i>
        </div>
        <h3 class="text-xl font-bold text-white mb-2">No Domain Selected</h3>
        <p class="text-slate-500 max-w-sm mx-auto">Please select a domain from the dropdown above to manage its DNS zone.
        </p>
    </div>
<?php endif; ?>

<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>

<script>
    document.querySelector('select[name="type"]')?.addEventListener('change', function () {
        document.getElementById('priority-field').classList.toggle('hidden', this.value !== 'MX');
    });

    async function handleRecordAdd(e) {
        e.preventDefault();
        const fd = new FormData(e.target);
        fd.append('ajax_action', 'add_record');

        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            if (res.status === 'success') {
                showToast('success', 'Record Added', res.msg);
                setTimeout(() => location.reload(), 800);
            } else {
                showToast('error', 'Failed', res.msg);
            }
        } catch (e) {
            showToast('error', 'Error', 'System error adding record.');
        }
    }

    async function deleteRecord(id) {
        if (!confirm("Are you sure you want to delete this record?")) return;
        const fd = new FormData();
        fd.append('ajax_action', 'delete_record');
        fd.append('record_id', id);

        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            if (res.status === 'success') {
                showToast('success', 'Deleted', 'Record removed.');
                setTimeout(() => location.reload(), 500);
            } else {
                showToast('error', 'Failed', res.msg);
            }
        } catch (e) {
            showToast('error', 'Error', 'System error.');
        }
    }
</script>