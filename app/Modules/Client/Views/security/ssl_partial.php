<?php
// SSL Tab Content Snippet
?>
<div class="glass-panel p-8 mb-8 rounded-2xl">
    <h3 class="font-bold mb-4 text-white">Issue Free Let's Encrypt SSL</h3>
    <p class="text-slate-400 text-sm mb-6">Select a domain to secure with a free, auto-renewing SSL certificate.</p>

    <form onsubmit="issueSSL(event)" class="flex gap-4">
        <select id="ssl-domain-select" name="domain" required
            class="flex-1 bg-slate-900/50 border border-slate-700 p-3 rounded-xl outline-none focus:border-blue-500 text-white">
            <option value="">Loading domains...</option>
        </select>
        <button class="bg-blue-600 text-white px-6 py-3 rounded-xl font-bold hover:bg-blue-500 transition">Issue
            SSL</button>
    </form>
</div>

<div class="glass-panel p-8 rounded-2xl">
    <h3 class="font-bold mb-6 text-white text-lg">Active SSL Certificates</h3>
    <div id="ssl-list" class="space-y-2 text-slate-400 text-sm">
        <div class="animate-pulse flex space-x-4">
            <div class="flex-1 space-y-4 py-1">
                <div class="h-4 bg-slate-700 rounded w-3/4"></div>
            </div>
        </div>
    </div>
</div>

<script>
    async function loadSSLDomains() {
        const select = document.getElementById('ssl-domain-select');
        const fd = new FormData(); fd.append('ajax_action', 'list_ssl_domains');
        try {
            const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
            select.innerHTML = '<option value="">Select Domain</option>';
            if (res.data) {
                res.data.forEach(d => {
                    select.innerHTML += `<option value="${d.domain}">${d.domain}</option>`;
                });
            }
        } catch (e) { select.innerHTML = '<option value="">Error loading</option>'; }
    }

    async function issueSSL(e) {
        if (!confirm('This process may take up to 2 minutes. Proceed?')) return;
        await handleGeneric(e, 'issue_ssl');
    }

    // Initial load for SSL tab
    if ('<?php echo $active_tab; ?>' === 'ssl') {
        loadSSLDomains();
    }
</script>