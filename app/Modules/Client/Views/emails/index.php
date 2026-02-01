<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="space-y-10">
    <!-- CREATE EMAIL -->
    <div class="glass-panel p-10 rounded-2xl">
        <h2 class="text-2xl font-bold mb-8 text-white">Create Email Account</h2>
        <form onsubmit="handleGeneric(event, 'add_email')" class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <input name="user" required placeholder="mailbox name"
                class="bg-slate-900/50 border border-slate-700 p-4 rounded-xl outline-none focus:border-blue-500 text-white placeholder-slate-600 transition">
            <select name="domain"
                class="bg-slate-900/50 border border-slate-700 p-4 rounded-xl outline-none focus:border-blue-500 text-slate-300">
                <?php foreach ($domains as $d): ?>
                    <option value="<?= htmlspecialchars($d['domain']) ?>">@
                        <?= htmlspecialchars($d['domain']) ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <input name="pass" type="password" required placeholder="Password"
                class="bg-slate-900/50 border border-slate-700 p-4 rounded-xl outline-none focus:border-blue-500 text-white placeholder-slate-600 transition">
            <button
                class="bg-blue-600 text-white rounded-xl font-bold shadow-lg shadow-blue-600/20 hover:bg-blue-500 transition">Create
                Mailbox</button>
        </form>
    </div>

    <!-- LIST -->
    <div class="glass-panel rounded-2xl overflow-hidden">
        <table class="w-full text-left">
            <thead class="bg-slate-900/50 text-[10px] font-bold uppercase text-slate-400 border-b border-slate-800">
                <tr>
                    <th class="p-6">Active Email Account</th>
                    <th class="p-6 text-right">Webmail / Action</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-slate-800/50">
                <?php foreach ($emails as $mail): ?>
                    <tr class="hover:bg-slate-800/30 transition">
                        <td class="p-6 font-bold text-slate-300">
                            <?= htmlspecialchars($mail['email']) ?>
                        </td>
                        <td class="p-6 text-right">
                            <a href="http://webmail.<?= htmlspecialchars($baseDomain) ?>" target="_blank"
                                class="text-blue-400 font-bold text-xs mr-4 uppercase tracking-tighter hover:text-blue-300">Login</a>
                            <button onclick="resetPassword('reset_mail_pass', 'email', '<?= htmlspecialchars($mail['email']) ?>')"
                                class="text-orange-400 hover:bg-orange-500/10 p-2 rounded-lg transition mr-2"><i
                                    data-lucide="key" class="w-4 h-4"></i></button>
                            <button onclick="deleteAction('delete_email', 'email', '<?= htmlspecialchars($mail['email']) ?>')"
                                class="text-red-400 hover:bg-red-500/10 p-2 rounded-lg transition"><i data-lucide="trash-2"
                                    class="w-4"></i></button>
                        </td>
                    </tr>
                <?php endforeach; ?>
                <?php if (empty($emails)): ?>
                    <tr><td colspan="2" class="p-6 text-center text-slate-500">No email accounts found.</td></tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>

     <?php if ($totalPages > 1): ?>
        <div class="flex justify-between items-center mt-6">
            <div class="text-xs text-slate-500 font-bold">Page <?= $currentPage ?> of <?= $totalPages ?></div>
            <div class="flex gap-2">
                <?php if ($currentPage > 1): ?>
                        <a href="?page=<?= $currentPage - 1 ?>" class="bg-slate-800 text-white px-4 py-2 rounded-lg text-xs font-bold hover:bg-slate-700">Prev</a>
                <?php endif; ?>
                <?php if ($currentPage < $totalPages): ?>
                        <a href="?page=<?= $currentPage + 1 ?>" class="bg-slate-800 text-white px-4 py-2 rounded-lg text-xs font-bold hover:bg-slate-700">Next</a>
                <?php endif; ?>
            </div>
        </div>
    <?php endif; ?>
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
                showToast('error', 'Delete Failed', res.msg);
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
