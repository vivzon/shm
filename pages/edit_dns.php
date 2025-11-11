<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('dns_management');

$record_id = intval($_GET['id']);

// Verify ownership through domain
$stmt = $pdo->prepare("SELECT dr.*, d.domain_name FROM dns_records dr JOIN domains d ON dr.domain_id = d.id WHERE dr.id = ? AND d.user_id = ?");
$stmt->execute([$record_id, $_SESSION['user_id']]);
$record = $stmt->fetch();

if (!$record) {
    die("DNS record not found or access denied");
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $record_type = sanitize_input($_POST['record_type']);
    $record_name = sanitize_input($_POST['record_name']);
    $record_value = sanitize_input($_POST['record_value']);
    $ttl = intval($_POST['ttl']);
    $priority = ($record_type === 'MX') ? intval($_POST['priority']) : null;
    
    $stmt = $pdo->prepare("UPDATE dns_records SET record_type = ?, record_name = ?, record_value = ?, ttl = ?, priority = ? WHERE id = ?");
    $stmt->execute([$record_type, $record_name, $record_value, $ttl, $priority, $record_id]);
    
    header('Location: dns.php?domain_id=' . $record['domain_id'] . '&success=DNS record updated successfully');
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Edit DNS Record - SHM Panel</title>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>Edit DNS Record for <?php echo $record['domain_name']; ?></h1>
        </div>

        <div class="container">
            <div class="card">
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Record Type</label>
                            <select name="record_type" id="recordType" onchange="togglePriorityField()">
                                <option value="A" <?php echo $record['record_type'] == 'A' ? 'selected' : ''; ?>>A (Address)</option>
                                <option value="AAAA" <?php echo $record['record_type'] == 'AAAA' ? 'selected' : ''; ?>>AAAA (IPv6 Address)</option>
                                <option value="CNAME" <?php echo $record['record_type'] == 'CNAME' ? 'selected' : ''; ?>>CNAME (Canonical Name)</option>
                                <option value="MX" <?php echo $record['record_type'] == 'MX' ? 'selected' : ''; ?>>MX (Mail Exchange)</option>
                                <option value="TXT" <?php echo $record['record_type'] == 'TXT' ? 'selected' : ''; ?>>TXT (Text)</option>
                                <option value="NS" <?php echo $record['record_type'] == 'NS' ? 'selected' : ''; ?>>NS (Name Server)</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Record Name</label>
                            <input type="text" name="record_name" value="<?php echo $record['record_name']; ?>" required>
                        </div>
                        <div class="form-group">
                            <label>Record Value</label>
                            <input type="text" name="record_value" value="<?php echo $record['record_value']; ?>" required>
                        </div>
                        <div class="form-group" id="priorityField" style="<?php echo $record['record_type'] === 'MX' ? 'display: block;' : 'display: none;' ?>">
                            <label>Priority (for MX records)</label>
                            <input type="number" name="priority" value="<?php echo $record['priority'] ?: 10; ?>" min="0" max="65535">
                        </div>
                        <div class="form-group">
                            <label>TTL (Time to Live)</label>
                            <select name="ttl">
                                <option value="300" <?php echo $record['ttl'] == 300 ? 'selected' : ''; ?>>5 minutes (300)</option>
                                <option value="1800" <?php echo $record['ttl'] == 1800 ? 'selected' : ''; ?>>30 minutes (1800)</option>
                                <option value="3600" <?php echo $record['ttl'] == 3600 ? 'selected' : ''; ?>>1 hour (3600)</option>
                                <option value="86400" <?php echo $record['ttl'] == 86400 ? 'selected' : ''; ?>>1 day (86400)</option>
                            </select>
                        </div>
                        <button type="submit" class="btn btn-primary">Update Record</button>
                        <a href="dns.php?domain_id=<?php echo $record['domain_id']; ?>" class="btn">Cancel</a>
                    </form>
                </div>
            </div>
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