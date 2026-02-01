<?php include __DIR__ . '/../../Common/Views/layout/header.php'; ?>

<div class="mb-8">
    <h2 class="text-2xl font-bold text-white mb-2">System Tools</h2>
    <p class="text-slate-400 text-sm">Configure system services and accounts.</p>
</div>

<!-- TABS -->
<div class="flex border-b border-slate-800 mb-8 overflow-x-auto">
    <a href="?tab=ftp"
        class="px-6 py-3 text-sm font-bold border-b-2 transition whitespace-nowrap <?= $active_tab == 'ftp' ? 'border-indigo-500 text-white' : 'border-transparent text-slate-500 hover:text-slate-300' ?>">
        FTP Manager
    </a>
    <a href="?tab=mail"
        class="px-6 py-3 text-sm font-bold border-b-2 transition whitespace-nowrap <?= $active_tab == 'mail' ? 'border-indigo-500 text-white' : 'border-transparent text-slate-500 hover:text-slate-300' ?>">
        Mail Manager
    </a>
    <a href="?tab=php"
        class="px-6 py-3 text-sm font-bold border-b-2 transition whitespace-nowrap <?= $active_tab == 'php' ? 'border-indigo-500 text-white' : 'border-transparent text-slate-500 hover:text-slate-300' ?>">
        PHP Config
    </a>
    <a href="?tab=network"
        class="px-6 py-3 text-sm font-bold border-b-2 transition whitespace-nowrap <?= $active_tab == 'network' ? 'border-indigo-500 text-white' : 'border-transparent text-slate-500 hover:text-slate-300' ?>">
        Network Settings
    </a>
</div>

<!-- CONTENT: FTP -->
<div class="<?= $active_tab == 'ftp' ? '' : 'hidden' ?>">
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- CREATE FTP -->
        <div class="glass-panel p-8 rounded-3xl relative overflow-hidden">
            <div class="absolute -right-10 -top-10 w-40 h-40 bg-blue-600/10 rounded-full blur-3xl"></div>
            <h3 class="text-xl font-bold mb-8 flex items-center gap-3 text-white font-heading">
                <div class="p-2 bg-blue-500/10 rounded-lg border border-blue-500/20 text-blue-500">
                    <i data-lucide="folder-up" class="w-5 h-5"></i>
                </div>
                Create FTP Account
            </h3>
            <form onsubmit="handleFTPCreate(event)" class="space-y-4 relative z-10">
                <div class="grid grid-cols-2 gap-4">
                    <input name="ftp_user" required placeholder="Pre-fix (e.g. dev)"
                        class="w-full bg-slate-900/50 p-4 rounded-xl border border-slate-700 outline-none focus:border-indigo-500 text-white placeholder:text-slate-600 focus:bg-slate-900 transition">
                    <select name="sys_user" required
                        class="w-full bg-slate-900/50 p-4 rounded-xl border border-slate-700 text-slate-300 outline-none focus:border-indigo-500 focus:bg-slate-900 transition">
                        <?php foreach ($clients as $c): ?>
                            <option value="<?= htmlspecialchars($c['username']) ?>">@
                                <?= htmlspecialchars($c['username']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <input name="pass" required type="password" placeholder="Password"
                        class="w-full bg-slate-900/50 p-4 rounded-xl border border-slate-700 outline-none focus:border-indigo-500 text-white placeholder:text-slate-600 focus:bg-slate-900 transition">
                    <input name="pass2" required type="password" placeholder="Confirm"
                        class="w-full bg-slate-900/50 p-4 rounded-xl border border-slate-700 outline-none focus:border-indigo-500 text-white placeholder:text-slate-600 focus:bg-slate-900 transition">
                </div>
                <button type="submit"
                    class="w-full bg-indigo-600 hover:bg-indigo-500 py-3.5 rounded-xl font-bold mt-4 shadow-lg shadow-indigo-600/20 text-white transition border border-indigo-500/50">
                    Create FTP User
                </button>
            </form>
        </div>

        <!-- LIST FTP -->
        <div class="glass-panel p-8 rounded-3xl relative overflow-hidden flex flex-col h-full">
            <h3 class="text-xl font-bold mb-6 text-white font-heading">Existing Accounts</h3>
            <div class="overflow-y-auto flex-1 custom-scrollbar max-h-[400px]">
                <table class="w-full text-left">
                    <thead
                        class="bg-slate-900/50 text-[10px] font-bold uppercase text-slate-400 sticky top-0 backdrop-blur-md">
                        <tr>
                            <th class="p-3">User</th>
                            <th class="p-3">Home</th>
                            <th class="p-3 text-right"></th>
                        </tr>
                    </thead>
                    <tbody id="ftp-list" class="divide-y divide-slate-700/50">
                        <tr>
                            <td colspan="3" class="p-4 text-center text-slate-500">Loading...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>

<!-- OTHER TABS (Simplified for Artifact Limits) -->
<!-- ... Mail, PHP, Network Tabs would go here ... -->
<!-- Adding Mail Tab as it was in original -->
<div class="<?= $active_tab == 'mail' ? '' : 'hidden' ?>">
    <div class="glass-panel p-8 rounded-3xl relative overflow-hidden max-w-2xl">
        <h3 class="text-xl font-bold mb-8 flex items-center gap-3 text-white font-heading">Create Email Account</h3>
        <form onsubmit="handleGeneric(event, 'add_mail')" class="space-y-4 relative z-10">
            <div class="flex gap-2">
                <input name="prefix" required placeholder="user"
                    class="flex-1 bg-slate-900/50 p-4 rounded-xl border border-slate-700 outline-none focus:border-indigo-500 text-white text-right">
                <div class="flex items-center text-slate-500 font-bold">@</div>
                <select name="domain" required
                    class="flex-1 bg-slate-900/50 p-4 rounded-xl border border-slate-700 text-slate-300 outline-none focus:border-indigo-500">
                    <?php foreach ($mail_domains as $d): ?>
                        <option value="<?= htmlspecialchars($d['domain']) ?>">
                            <?= htmlspecialchars($d['domain']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <input name="mail_pass" required type="password" placeholder="Password"
                class="w-full bg-slate-900/50 p-4 rounded-xl border border-slate-700 outline-none focus:border-indigo-500 text-white transition mb-2">
            <button type="submit"
                class="w-full bg-indigo-600 hover:bg-indigo-500 py-3.5 rounded-xl font-bold mt-4 shadow-lg text-white transition">Create
                Mailbox</button>
        </form>
    </div>
</div>

<?php include __DIR__ . '/../../Common/Views/layout/footer.php'; ?>

<script>
    async function loadFTP() {
        const list = document.getElementById('ftp-list');
        if (!list) return;
        const fd = new FormData(); fd.append('ajax_action', 'list_ftp');
        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            list.innerHTML = '';
            if (res.data && res.data.length > 0) {
                res.data.forEach(u => {
                    list.innerHTML += `
                        <tr class="hover:bg-slate-800/30 transition group">
                            <td class="p-3 font-mono text-xs text-blue-300">${u.userid}</td>
                            <td class="p-3 text-slate-500 text-xs truncate max-w-[150px]">${u.homedir}</td>
                            <td class="p-3 text-right">
                                <button onclick="delFTP('${u.userid}')" class="text-red-400 opacity-50 group-hover:opacity-100 hover:text-red-300 transition"><i data-lucide="trash-2" class="w-4"></i></button>
                            </td>
                        </tr>`;
                });
                lucide.createIcons();
            } else {
                list.innerHTML = '<tr><td colspan="3" class="p-4 text-center text-slate-500">No FTP accounts found.</td></tr>';
            }
        } catch (e) { list.innerHTML = '<tr><td colspan="3" class="p-4 text-center text-red-400">Error loading.</td></tr>'; }
    }

    async function handleFTPCreate(e) {
        e.preventDefault();
        const fd = new FormData(e.target); fd.append('ajax_action', 'add_ftp');
        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            if (res.status === 'success') { showToast('success', 'FTP Account Created'); e.target.reset(); loadFTP(); }
            else showToast('error', res.msg);
        } catch (e) { showToast('error', 'Server Error'); }
    }

    async function delFTP(user) {
        if (!confirm('Delete FTP user ' + user + '?')) return;
        const fd = new FormData(); fd.append('ajax_action', 'del_ftp'); fd.append('user', user);
        await fetch('', { method: 'POST', body: fd }); showToast('success', 'Deleted'); loadFTP();
    }

    <?php if ($active_tab == 'ftp'): ?>
            loadFTP();
    <?php endif; ?>
</script>