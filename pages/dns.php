<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('dns_management');

// Get user domains
$domains = get_user_domains($_SESSION['user_id']);
$selected_domain = null;
$dns_records = [];

if (isset($_GET['domain_id'])) {
    $domain_id = intval($_GET['domain_id']);
    
    // Verify domain ownership
    $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
    $stmt->execute([$domain_id, $_SESSION['user_id']]);
    $selected_domain = $stmt->fetch();
    
    if ($selected_domain) {
        $dns_records = get_dns_records($domain_id);
    }
}

// Handle DNS operations
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['add_record'])) {
        $domain_id = intval($_POST['domain_id']);
        $record_type = sanitize_input($_POST['record_type']);
        $record_name = sanitize_input($_POST['record_name']);
        $record_value = sanitize_input($_POST['record_value']);
        $ttl = intval($_POST['ttl']);
        $priority = ($record_type === 'MX') ? intval($_POST['priority']) : null;
        
        // Verify domain ownership
        $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $_SESSION['user_id']]);
        $domain = $stmt->fetch();
        
        if ($domain) {
            if (add_dns_record($domain_id, $record_type, $record_name, $record_value, $ttl, $priority)) {
                header('Location: dns.php?domain_id=' . $domain_id . '&success=DNS record added successfully');
                exit;
            }
        }
    }
    
    if (isset($_POST['delete_record'])) {
        $record_id = intval($_POST['record_id']);
        $domain_id = intval($_POST['domain_id']);
        
        // Verify ownership through domain
        $stmt = $pdo->prepare("SELECT d.* FROM dns_records dr JOIN domains d ON dr.domain_id = d.id WHERE dr.id = ? AND d.user_id = ?");
        $stmt->execute([$record_id, $_SESSION['user_id']]);
        $record = $stmt->fetch();
        
        if ($record) {
            $stmt = $pdo->prepare("DELETE FROM dns_records WHERE id = ?");
            $stmt->execute([$record_id]);
            header('Location: dns.php?domain_id=' . $domain_id . '&success=DNS record deleted successfully');
            exit;
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DNS Management - SHM Panel</title>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>DNS Management</h1>
        </div>

        <?php if (isset($_GET['success'])): ?>
            <div style="background: #d4edda; color: #155724; padding: 10px; border-radius: 3px; margin-bottom: 20px;">
                <?php echo $_GET['success']; ?>
            </div>
        <?php endif; ?>

        <div class="container">
            <div class="card">
                <div class="card-header">
                    <h3>Select Domain</h3>
                </div>
                <div class="card-body">
                    <form method="get">
                        <div class="form-group">
                            <select name="domain_id" onchange="this.form.submit()">
                                <option value="">Select Domain</option>
                                <?php foreach ($domains as $domain): ?>
                                <option value="<?php echo $domain['id']; ?>" <?php echo (isset($_GET['domain_id']) && $_GET['domain_id'] == $domain['id']) ? 'selected' : ''; ?>>
                                    <?php echo $domain['domain_name']; ?>
                                </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </form>
                </div>
            </div>

            <?php if ($selected_domain): ?>
            <div class="card">
                <div class="card-header">
                    <h3>Add DNS Record for <?php echo $selected_domain['domain_name']; ?></h3>
                </div>
                <div class="card-body">
                    <form method="post">
                        <input type="hidden" name="domain_id" value="<?php echo $selected_domain['id']; ?>">
                        <div class="form-group">
                            <label>Record Type</label>
                            <select name="record_type" id="recordType" onchange="togglePriorityField()">
                                <option value="A">A (Address)</option>
                                <option value="AAAA">AAAA (IPv6 Address)</option>
                                <option value="CNAME">CNAME (Canonical Name)</option>
                                <option value="MX">MX (Mail Exchange)</option>
                                <option value="TXT">TXT (Text)</option>
                                <option value="NS">NS (Name Server)</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Record Name</label>
                            <input type="text" name="record_name" placeholder="e.g., www or @ for domain itself" required>
                        </div>
                        <div class="form-group">
                            <label>Record Value</label>
                            <input type="text" name="record_value" placeholder="e.g., 192.168.1.1 or example.com." required>
                        </div>
                        <div class="form-group" id="priorityField" style="display: none;">
                            <label>Priority (for MX records)</label>
                            <input type="number" name="priority" value="10" min="0" max="65535">
                        </div>
                        <div class="form-group">
                            <label>TTL (Time to Live)</label>
                            <select name="ttl">
                                <option value="300">5 minutes (300)</option>
                                <option value="1800">30 minutes (1800)</option>
                                <option value="3600" selected>1 hour (3600)</option>
                                <option value="86400">1 day (86400)</option>
                            </select>
                        </div>
                        <button type="submit" name="add_record" class="btn btn-primary">Add Record</button>
                    </form>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3>DNS Records for <?php echo $selected_domain['domain_name']; ?></h3>
                </div>
                <div class="card-body">
                    <?php if (empty($dns_records)): ?>
                        <p>No DNS records found.</p>
                    <?php else: ?>
                        <table>
                            <thead>
                                <tr>
                                    <th>Type</th>
                                    <th>Name</th>
                                    <th>Value</th>
                                    <th>TTL</th>
                                    <th>Priority</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($dns_records as $record): ?>
                                <tr>
                                    <td><?php echo $record['record_type']; ?></td>
                                    <td><?php echo $record['record_name']; ?></td>
                                    <td><?php echo $record['record_value']; ?></td>
                                    <td><?php echo $record['ttl']; ?></td>
                                    <td><?php echo $record['priority'] ?: '-'; ?></td>
                                    <td>
                                        <form method="post" style="display: inline;">
                                            <input type="hidden" name="domain_id" value="<?php echo $selected_domain['id']; ?>">
                                            <input type="hidden" name="record_id" value="<?php echo $record['id']; ?>">
                                            <button type="submit" name="delete_record" class="btn btn-danger" onclick="return confirm('Delete this DNS record?')">Delete</button>
                                        </form>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    <?php endif; ?>
                </div>
            </div>
            <?php endif; ?>
        </div>
    </div>

    <script>
        function togglePriorityField() {
            const recordType = document.getElementById('recordType').value;
            const priorityField = document.getElementById('priorityField');
            priorityField.style.display = (recordType === 'MX') ? 'block' : 'none';
        }
    </script>
</body>
</html>