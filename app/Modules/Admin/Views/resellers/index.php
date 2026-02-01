<?php $this->layout('admin'); ?>

<div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-gray-800">Reseller Management</h1>
    <button onclick="openModal('createResellerModal')"
        class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
        <i class="fas fa-plus mr-2"></i>Create Reseller
    </button>
</div>

<div class="bg-white rounded-lg shadow overflow-hidden">
    <div class="p-4 border-b">
        <form method="GET" class="flex gap-2">
            <input type="text" name="search" placeholder="Search resellers..."
                value="<?= htmlspecialchars($_GET['search'] ?? '') ?>" class="border rounded px-3 py-2 w-64">
            <button type="submit" class="bg-gray-100 px-4 py-2 rounded hover:bg-gray-200">Search</button>
        </form>
    </div>

    <table class="w-full">
        <thead class="bg-gray-50">
            <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">ID</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Username</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
            <?php foreach ($resellers as $r): ?>
                <tr>
                    <td class="px-6 py-4 whitespace-nowrap">
                        <?= $r['id'] ?>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap font-medium">
                        <?= htmlspecialchars($r['username']) ?>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                        <?= htmlspecialchars($r['email']) ?>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                        <span
                            class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full <?= $r['status'] === 'active' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800' ?>">
                            <?= ucfirst($r['status']) ?>
                        </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button
                            onclick="suspendReseller(<?= $r['id'] ?>, <?= $r['status'] === 'active' ? 'true' : 'false' ?>)"
                            class="text-orange-600 hover:text-orange-900 mr-3">
                            <?= $r['status'] === 'active' ? 'Suspend' : 'Unsuspend' ?>
                        </button>
                        <button onclick="deleteReseller(<?= $r['id'] ?>)"
                            class="text-red-600 hover:text-red-900">Delete</button>
                    </td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>

    <!-- Pagination -->
    <?php if ($total_pages > 1): ?>
        <div class="px-4 py-3 border-t bg-gray-50 flex justify-center">
            <?php for ($i = 1; $i <= $total_pages; $i++): ?>
                <a href="?page=<?= $i ?>&search=<?= htmlspecialchars($search ?? '') ?>"
                    class="mx-1 px-3 py-1 rounded <?= $i == $page ? 'bg-blue-600 text-white' : 'bg-white border' ?>">
                    <?= $i ?>
                </a>
            <?php endfor; ?>
        </div>
    <?php endif; ?>
</div>

<!-- Create Modal -->
<div id="createResellerModal" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
    <div class="bg-white rounded-lg p-6 w-96">
        <h2 class="text-lg font-bold mb-4">Create Reseller</h2>
        <form id="createResellerForm">
            <input type="hidden" name="ajax_action" value="create_reseller">
            <div class="mb-4">
                <label class="block text-gray-700 text-sm font-bold mb-2">Username</label>
                <input type="text" name="username"
                    class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                    required>
            </div>
            <div class="mb-4">
                <label class="block text-gray-700 text-sm font-bold mb-2">Email</label>
                <input type="email" name="email"
                    class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                    required>
            </div>
            <div class="mb-6">
                <label class="block text-gray-700 text-sm font-bold mb-2">Password</label>
                <input type="password" name="password"
                    class="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                    required>
            </div>
            <div class="flex justify-end">
                <button type="button" onclick="closeModal('createResellerModal')"
                    class="bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded mr-2">Cancel</button>
                <button type="submit"
                    class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Create</button>
            </div>
        </form>
    </div>
</div>

<script>
    document.getElementById('createResellerForm').onsubmit = async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
        if (res.status === 'success') {
            location.reload();
        } else {
            alert(res.msg);
        }
    };

    async function deleteReseller(id) {
        if (!confirm('Are you sure?')) return;
        const fd = new FormData();
        fd.append('ajax_action', 'delete_reseller');
        fd.append('id', id);
        const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
        if (res.status === 'success') location.reload();
    }

    async function suspendReseller(id, suspend) {
        const fd = new FormData();
        fd.append('ajax_action', 'suspend_reseller');
        fd.append('id', id);
        fd.append('suspend', suspend);
        const res = await fetch('', { method: 'POST', body: fd }).then(r => r.json());
        if (res.status === 'success') location.reload();
    }
</script>