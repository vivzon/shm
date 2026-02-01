<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="grid grid-cols-1 md:grid-cols-3 gap-8">
    <!-- CREATE DB FORM -->
    <div class="space-y-8">
        <div>
            <h3 class="font-bold mb-4 text-white">Create Database</h3>
            <form onsubmit="handleGeneric(event, 'add_db')" class="glass-card p-6 space-y-4 rounded-xl">
                <div class="flex items-center bg-slate-900/50 rounded-xl border border-slate-700 overflow-hidden">
                    <div class="px-4 py-4 bg-slate-800 text-slate-400 font-mono text-sm border-r border-slate-700">
                        <?= htmlspecialchars($username) ?>_
                    </div>
                    <input name="db_name" required placeholder="dbname"
                        class="w-full bg-transparent p-4 outline-none text-white placeholder-slate-600">
                </div>
                <select name="domain_id"
                    class="w-full bg-slate-900/50 border border-slate-700 p-4 rounded-xl outline-none focus:border-blue-500 text-slate-300">
                    <option value="">Global (No Domain Associated)</option>
                    <?php foreach ($domains as $d): ?>
                        <option value="<?= $d['id'] ?>">Associate with
                            <?= htmlspecialchars($d['domain']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <button
                    class="w-full bg-blue-600 text-white p-4 rounded-xl font-bold hover:bg-blue-500 transition shadow-lg shadow-blue-600/20">Create
                    Database</button>
            </form>
        </div>

        <div>
            <h3 class="font-bold mb-4 text-white">Create Database User</h3>
            <form onsubmit="handleGeneric(event, 'add_db_user')" class="glass-card p-6 space-y-4 rounded-xl">
                <div class="flex items-center bg-slate-900/50 rounded-xl border border-slate-700 overflow-hidden">
                    <div class="px-4 py-4 bg-slate-800 text-slate-400 font-mono text-sm border-r border-slate-700">
                        <?= htmlspecialchars($username) ?>_
                    </div>
                    <input name="db_user" required placeholder="dbuser"
                        class="w-full bg-transparent p-4 outline-none text-white placeholder-slate-600">
                </div>
                <input name="db_pass" type="password" required placeholder="Password"
                    class="w-full bg-slate-900/50 border border-slate-700 p-4 rounded-xl outline-none focus:border-blue-500 text-white placeholder-slate-600 transition">
                <select name="target_db"
                    class="w-full bg-slate-900/50 border border-slate-700 p-4 rounded-xl outline-none focus:border-blue-500 text-slate-300">
                    <?php foreach ($myDbs as $db): ?>
                        <option value="<?= htmlspecialchars($db['db_name']) ?>">Access to:
                            <?= htmlspecialchars($db['db_name']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <button
                    class="w-full bg-slate-800 text-white p-4 rounded-xl font-bold hover:bg-slate-700 transition border border-slate-700">Create
                    User</button>
            </form>
        </div>
    </div>

    <!-- DB LIST & USERS -->
    <div class="md:col-span-2 space-y-8">
        <div>
            <h3 class="font-bold mb-4 text-white">Your Databases</h3>
            <div class="glass-panel rounded-2xl overflow-hidden">
                <table class="w-full text-left">
                    <thead
                        class="bg-slate-900/50 text-[10px] font-bold uppercase text-slate-400 tracking-widest border-b border-slate-800">
                        <tr>
                            <th class="p-6">Database Name</th>
                            <th class="p-6 text-right">Login / Action</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-800/50">
                        <?php foreach ($myDbs as $db): ?>
                            <tr class="hover:bg-slate-800/30 transition">
                                <td class="p-6">
                                    <div class="font-bold text-slate-200">
                                        <?= htmlspecialchars($db['db_name']) ?>
                                    </div>
                                    <?php if ($db['domain']): ?>
                                        <div class="text-xs text-blue-400 flex items-center gap-1 mt-1"><i data-lucide="link"
                                                class="w-3"></i>
                                            <?= htmlspecialchars($db['domain']) ?>
                                        </div>
                                    <?php else: ?>
                                        <div class="text-xs text-slate-500 italic mt-1">Global Database</div>
                                    <?php endif; ?>
                                </td>
                                <td class="p-6 text-right">
                                    <a href="http://phpmyadmin.<?= htmlspecialchars($baseDomain) ?>" target="_blank"
                                        class="text-blue-400 font-bold text-xs mr-4 uppercase hover:text-blue-300">phpMyAdmin</a>
                                    <button
                                        onclick="deleteAction('delete_db', 'db_name', '<?= htmlspecialchars($db['db_name']) ?>')"
                                        class="text-red-400 hover:bg-red-500/10 p-2 rounded-lg transition"><i
                                            data-lucide="trash-2" class="w-4"></i></button>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        <?php if (empty($myDbs)): ?>
                            <tr>
                                <td colspan="2" class="p-6 text-center text-slate-500">No databases found.</td>
                            </tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
            <!-- Pagination Placeholder -->
            <?php if ($totalPages > 1): ?>
                <div class="flex justify-between items-center mt-6">
                    <div class="text-xs text-slate-500 font-bold">Page
                        <?= $currentPage ?> of
                        <?= $totalPages ?>
                    </div>
                    <div class="flex gap-2">
                        <?php if ($currentPage > 1): ?>
                            <a href="?page=<?= $currentPage - 1 ?>"
                                class="bg-slate-800 text-white px-4 py-2 rounded-lg text-xs font-bold hover:bg-slate-700">Prev</a>
                        <?php endif; ?>
                        <?php if ($currentPage < $totalPages): ?>
                            <a href="?page=<?= $currentPage + 1 ?>"
                                class="bg-slate-800 text-white px-4 py-2 rounded-lg text-xs font-bold hover:bg-slate-700">Next</a>
                        <?php endif; ?>
                    </div>
                </div>
            <?php endif; ?>
        </div>

        <div>
            <h3 class="font-bold mb-4 text-white">Database Users</h3>
            <div class="glass-panel rounded-2xl overflow-hidden">
                <table class="w-full text-left">
                    <thead
                        class="bg-slate-900/50 text-[10px] font-bold uppercase text-slate-400 border-b border-slate-800">
                        <tr>
                            <th class="p-6">User</th>
                            <th class="p-6 text-right">Action</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-800/50">
                        <?php foreach ($dbUsers as $u): ?>
                            <tr class="hover:bg-slate-800/30 transition">
                                <td class="p-6 font-bold text-slate-300">
                                    <?= htmlspecialchars($u['db_user']) ?>
                                </td>
                                <td class="p-6 text-right">
                                    <button
                                        onclick="resetPassword('reset_db_pass', 'db_user', '<?= htmlspecialchars($u['db_user']) ?>')"
                                        class="text-orange-400 hover:bg-orange-500/10 p-2 rounded-lg transition mr-2"><i
                                            data-lucide="key" class="w-4 h-4"></i></button>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>

<script>
    async function deleteAction(action, key, val) {
        if (!confirm("Permanent Action: Are you sure?")) return;
        const fd = new FormData();
        fd.append('ajax_action', action);
        fd.append(key, val);

        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            if (res.status === 'success') {
                showToast('success', 'Deleted', 'Item deleted successfully.');
                setTimeout(() => location.reload(), 1000);
            } else {
                showToast('error', 'Delete Failed', res.msg || 'Could not delete item.');
            }
        } catch (e) {
            showToast('error', 'Error', 'System error during deletion.');
        }
    }

    async function resetPassword(action, keyName, keyValue) {
        const newPass = prompt("Enter new password for " + keyValue + ":");
        if (!newPass) return;

        const fd = new FormData();
        fd.append('ajax_action', action);
        fd.append(keyName, keyValue);
        fd.append('new_pass', newPass);

        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            if (res.status === 'success') {
                showToast('success', 'Password Updated', 'The password has been changed successfully.');
            } else {
                showToast('error', 'Update Failed', res.msg);
            }
        } catch (e) {
            showToast('error', 'Error', 'System error during password reset.');
        }
    }
</script>