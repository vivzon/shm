<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="flex justify-between items-center mb-8 gap-4">
    <div class="flex items-center gap-4">
        <h2 class="text-2xl font-bold text-white font-heading">Client Accounts <span
                class="text-slate-500 text-lg ml-2">(
                <?= $total ?>)
            </span></h2>

        <!-- Search Form -->
        <form method="GET" action="/admin/accounts" class="relative group">
            <i data-lucide="search"
                class="w-4 absolute left-3 top-3 text-slate-500 group-focus-within:text-blue-400 transition"></i>
            <input name="search" value="<?= htmlspecialchars($_GET['search'] ?? '') ?>" placeholder="Search clients..."
                class="bg-slate-900/50 border border-slate-700/50 rounded-xl pl-10 pr-4 py-2.5 text-sm w-64 focus:w-80 transition-all outline-none focus:border-blue-500 focus:bg-slate-900 text-white placeholder-slate-600">
        </form>
    </div>
    <button onclick="openAccModal()"
        class="bg-blue-600 hover:bg-blue-500 text-white px-5 py-2.5 rounded-xl font-bold shadow-lg shadow-blue-900/20 text-sm flex items-center gap-2 transition border border-blue-500/50">
        <i data-lucide="plus-circle" class="w-4"></i> Create Account
    </button>
</div>

<div class="glass-panel rounded-2xl overflow-hidden">
    <table id="acc-table" class="w-full text-left border-collapse">
        <thead
            class="bg-slate-900/50 text-slate-400 text-[10px] font-bold uppercase tracking-widest border-b border-slate-800">
            <tr>
                <th class="p-5">Client / Domain</th>
                <th class="p-5">Plan</th>
                <th class="p-5">Status</th>
                <th class="p-5 text-right">Management</th>
            </tr>
        </thead>
        <tbody class="divide-y divide-slate-800/50">
            <?php foreach ($clients as $c): ?>
                <tr class="hover:bg-slate-800/30 transition-colors group">
                    <td class="p-5">
                        <div class="font-bold text-white text-sm">
                            <?= htmlspecialchars($c['username']) ?>
                        </div>
                        <a href="http://<?= $c['domain'] ?>" target="_blank"
                            class="text-xs text-blue-400 hover:underline flex items-center gap-1">
                            <?= htmlspecialchars($c['domain']) ?> <i data-lucide="external-link"
                                class="w-3 opacity-0 group-hover:opacity-100 transition"></i>
                        </a>
                    </td>
                    <td class="p-5">
                        <span
                            class="bg-slate-800 border border-slate-700 px-3 py-1 rounded-full text-[10px] font-bold text-slate-300">
                            <?= htmlspecialchars($c['pkg_name'] ?? 'N/A') ?>
                        </span>
                    </td>
                    <td class="p-5">
                        <?php if ($c['status'] == 'suspended'): ?>
                            <span
                                class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold bg-red-500/10 text-red-500 border border-red-500/20">
                                <span class="w-1.5 h-1.5 rounded-full bg-red-500"></span> Suspended
                            </span>
                        <?php else: ?>
                            <span
                                class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-500 border border-emerald-500/20">
                                <span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span> Active
                            </span>
                        <?php endif; ?>
                    </td>
                    <td class="p-5 text-right flex justify-end gap-2">
                        <button onclick="loginAs('<?= $c['username'] ?>', <?= $c['id'] ?>)"
                            class="p-2 hover:bg-blue-500/10 text-slate-400 hover:text-blue-400 rounded-lg transition"
                            title="Access Account">
                            <i data-lucide="key" class="w-4"></i>
                        </button>
                        <?php if ($c['status'] == 'active'): ?>
                            <button onclick="toggleSuspend('<?= $c['username'] ?>', true)"
                                class="p-2 hover:bg-orange-500/10 text-slate-400 hover:text-orange-400 rounded-lg transition"
                                title="Suspend">
                                <i data-lucide="pause-circle" class="w-4"></i>
                            </button>
                        <?php else: ?>
                            <button onclick="toggleSuspend('<?= $c['username'] ?>', false)"
                                class="p-2 hover:bg-emerald-500/10 text-slate-400 hover:text-emerald-400 rounded-lg transition"
                                title="Unsuspend">
                                <i data-lucide="play-circle" class="w-4"></i>
                            </button>
                        <?php endif; ?>
                        <!-- Edit Button (Requires full migration of Modal Logic) -->
                        <button onclick='openAccModal(<?= json_encode($c) ?>)'
                            class="p-2 hover:bg-blue-500/10 text-slate-400 hover:text-blue-400 rounded-lg transition border border-transparent hover:border-blue-500/20"
                            title="Edit">
                            <i data-lucide="edit-3" class="w-4"></i>
                        </button>
                        <button onclick="delAcc(<?= $c['id'] ?>, '<?= $c['username'] ?>', '<?= $c['domain'] ?>')"
                            class="p-2 hover:bg-red-500/10 text-slate-400 hover:text-red-400 rounded-lg transition border border-transparent hover:border-red-500/20"
                            title="Delete">
                            <i data-lucide="trash-2" class="w-4"></i>
                        </button>
                    </td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
</div>

<!-- Pagination -->
<?php if ($total_pages > 1): ?>
    <div class="flex justify-between items-center mt-6">
        <div class="text-xs text-slate-500 font-bold">
            Page
            <?= $page ?> of
            <?= $total_pages ?>
        </div>
        <div class="flex gap-2">
            <?php if ($page > 1): ?>
                <a href="?page=<?= $page - 1 ?>"
                    class="bg-slate-800 text-white px-4 py-2 rounded-lg text-xs font-bold hover:bg-slate-700 transition">Previous</a>
            <?php endif; ?>
            <?php if ($page < $total_pages): ?>
                <a href="?page=<?= $page + 1 ?>"
                    class="bg-slate-800 text-white px-4 py-2 rounded-lg text-xs font-bold hover:bg-slate-700 transition">Next</a>
            <?php endif; ?>
        </div>
    </div>
<?php endif; ?>

<!-- Include Legacy Modal Script & HTML (Simplified for brevity) -->
<!-- In a real scenario, we'd break this into a partial -->
<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>

<script>
    // Minimal JS integration for the MVC route
    async function toggleSuspend(user, suspend) {
        if (!confirm('Are you sure?')) return;
        const fd = new FormData();
        fd.append('ajax_action', 'suspend_account');
        fd.append('user', user);
        fd.append('suspend', suspend);

        const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
        if (res.status === 'success') location.reload();
        else alert(res.msg);
    }

    // ... Other JS functions (delAcc, etc) adapting to relative paths
    async function delAcc(id, user, dom) {
        if (!confirm('PERMANENTLY DELETE ' + dom + '?')) return;
        const fd = new FormData();
        fd.append('ajax_action', 'delete_account');
        fd.append('id', id);
        fd.append('user', user);

        const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
        if (res.status === 'success') location.reload();
        else alert(res.msg);
    }
</script>