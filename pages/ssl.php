<?php
require_once '../includes/config.php';
require_once '../includes/auth.php';
require_login();
check_permission('ssl_management');

// Get user domains
$domains = get_user_domains($_SESSION['user_id']);

// Handle SSL operations
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['upload_ssl'])) {
        $domain_id = intval($_POST['domain_id']);
        $certificate = $_POST['certificate'];
        $private_key = $_POST['private_key'];
        $ca_bundle = $_POST['ca_bundle'] ?? '';
        $expires_at = $_POST['expires_at'];
        $auto_renew = isset($_POST['auto_renew']) ? 1 : 0;
        
        // Verify domain ownership
        $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $_SESSION['user_id']]);
        $domain = $stmt->fetch();
        
        if ($domain) {
            $stmt = $pdo->prepare("INSERT INTO ssl_certificates (domain_id, certificate, private_key, ca_bundle, expires_at, auto_renew, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())");
            $stmt->execute([$domain_id, $certificate, $private_key, $ca_bundle, $expires_at, $auto_renew]);
            
            // Update domain SSL status
            $stmt = $pdo->prepare("UPDATE domains SET ssl_enabled = 1 WHERE id = ?");
            $stmt->execute([$domain_id]);
            
            header('Location: ssl.php?success=SSL certificate uploaded successfully');
            exit;
        }
    }
    
    if (isset($_POST['auto_ssl'])) {
        $domain_id = intval($_POST['domain_id']);
        
        // Verify domain ownership
        $stmt = $pdo->prepare("SELECT * FROM domains WHERE id = ? AND user_id = ?");
        $stmt->execute([$domain_id, $_SESSION['user_id']]);
        $domain = $stmt->fetch();
        
        if ($domain) {
            // In a real implementation, integrate with Let's Encrypt or similar service
            // For demo purposes, we'll just create a placeholder
            $certificate = "--- AUTO-GENERATED SSL CERTIFICATE ---";
            $private_key = "--- AUTO-GENERATED PRIVATE KEY ---";
            $expires_at = date('Y-m-d H:i:s', strtotime('+90 days'));
            
            $stmt = $pdo->prepare("INSERT INTO ssl_certificates (domain_id, certificate, private_key, expires_at, auto_renew, created_at) VALUES (?, ?, ?, ?, 1, NOW())");
            $stmt->execute([$domain_id, $certificate, $private_key, $expires_at]);
            
            // Update domain SSL status
            $stmt = $pdo->prepare("UPDATE domains SET ssl_enabled = 1 WHERE id = ?");
            $stmt->execute([$domain_id]);
            
            header('Location: ssl.php?success=Auto SSL certificate generated successfully');
            exit;
        }
    }
}

// Get SSL certificates
$stmt = $pdo->prepare("SELECT sc.*, d.domain_name FROM ssl_certificates sc JOIN domains d ON sc.domain_id = d.id WHERE d.user_id = ? ORDER BY sc.expires_at");
$stmt->execute([$_SESSION['user_id']]);
$certificates = $stmt->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SSL Management - SHM Panel</title>
</head>
<body>
    <?php include_once '../includes/header.php'; ?>

    <div class="main-content">
        <div class="header">
            <h1>SSL Certificate Management</h1>
        </div>

        <?php if (isset($_GET['success'])): ?>
            <div style="background: #d4edda; color: #155724; padding: 10px; border-radius: 3px; margin-bottom: 20px;">
                <?php echo $_GET['success']; ?>
            </div>
        <?php endif; ?>

        <div class="container">
            <div class="card">
                <div class="card-header">
                    <h3>Upload SSL Certificate</h3>
                </div>
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Domain</label>
                            <select name="domain_id" required>
                                <option value="">Select Domain</option>
                                <?php foreach ($domains as $domain): ?>
                                <option value="<?php echo $domain['id']; ?>"><?php echo $domain['domain_name']; ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Certificate (PEM format)</label>
                            <textarea name="certificate" rows="10" required placeholder="-----BEGIN CERTIFICATE-----"></textarea>
                        </div>
                        <div class="form-group">
                            <label>Private Key (PEM format)</label>
                            <textarea name="private_key" rows="10" required placeholder="-----BEGIN PRIVATE KEY-----"></textarea>
                        </div>
                        <div class="form-group">
                            <label>CA Bundle (Optional)</label>
                            <textarea name="ca_bundle" rows="5" placeholder="-----BEGIN CERTIFICATE-----"></textarea>
                        </div>
                        <div class="form-group">
                            <label>Expiration Date</label>
                            <input type="datetime-local" name="expires_at" required>
                        </div>
                        <div class="form-group">
                            <label>
                                <input type="checkbox" name="auto_renew" value="1"> Enable Auto Renewal
                            </label>
                        </div>
                        <button type="submit" name="upload_ssl" class="btn btn-primary">Upload Certificate</button>
                    </form>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3>Auto SSL (Let's Encrypt)</h3>
                </div>
                <div class="card-body">
                    <form method="post">
                        <div class="form-group">
                            <label>Domain</label>
                            <select name="domain_id" required>
                                <option value="">Select Domain</option>
                                <?php foreach ($domains as $domain): ?>
                                <option value="<?php echo $domain['id']; ?>"><?php echo $domain['domain_name']; ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="form-group">
                            <label>Email for Let's Encrypt (Optional)</label>
                            <input type="email" name="email" placeholder="admin@example.com">
                        </div>
                        <button type="submit" name="auto_ssl" class="btn btn-primary">Generate Auto SSL</button>
                    </form>
                </div>
            </div>

            <div class="card">
                <div class="card-header">
                    <h3>Your SSL Certificates</h3>
                </div>
                <div class="card-body">
                    <?php if (empty($certificates)): ?>
                        <p>No SSL certificates found.</p>
                    <?php else: ?>
                        <table>
                            <thead>
                                <tr>
                                    <th>Domain</th>
                                    <th>Expires</th>
                                    <th>Auto Renew</th>
                                    <th>Status</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($certificates as $cert): ?>
                                <tr>
                                    <td><?php echo $cert['domain_name']; ?></td>
                                    <td><?php echo date('Y-m-d', strtotime($cert['expires_at'])); ?></td>
                                    <td><?php echo $cert['auto_renew'] ? 'Yes' : 'No'; ?></td>
                                    <td>
                                        <?php
                                        $expires = strtotime($cert['expires_at']);
                                        $now = time();
                                        $days_left = floor(($expires - $now) / (60 * 60 * 24));
                                        
                                        if ($days_left > 30) {
                                            echo '<span style="color: green;">Valid (' . $days_left . ' days)</span>';
                                        } elseif ($days_left > 0) {
                                            echo '<span style="color: orange;">Expiring soon (' . $days_left . ' days)</span>';
                                        } else {
                                            echo '<span style="color: red;">Expired</span>';
                                        }
                                        ?>
                                    </td>
                                    <td>
                                        <button onclick="viewCertificate(<?php echo $cert['id']; ?>)">View</button>
                                        <button onclick="renewCertificate(<?php echo $cert['id']; ?>)">Renew</button>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    <?php endif; ?>
                </div>
            </div>
        </div>
    </div>

    <script>
        function viewCertificate(certId) {
            // In real implementation, show certificate details
            alert('Certificate details for ID: ' + certId);
        }
        
        function renewCertificate(certId) {
            if (confirm('Renew this SSL certificate?')) {
                // In real implementation, submit renewal request
                alert('Renewal requested for certificate ID: ' + certId);
            }
        }
    </script>
</body>
</html>