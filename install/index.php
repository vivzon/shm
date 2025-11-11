<?php
// Check if already installed
if (file_exists('../includes/config.php')) {
    header('Location: ../index.php');
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SHM Panel - Installation</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { text-align: center; margin-bottom: 30px; color: #333; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; color: #555; }
        input[type="text"], input[type="password"], input[type="email"] { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
        button { background: #007bff; color: white; padding: 12px 30px; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; width: 100%; }
        button:hover { background: #0056b3; }
        .step { display: none; }
        .step.active { display: block; }
        .progress { display: flex; margin-bottom: 30px; }
        .progress-step { flex: 1; text-align: center; padding: 10px; background: #e9ecef; border-radius: 5px; margin: 0 5px; }
        .progress-step.active { background: #007bff; color: white; }
        .error { color: red; margin-top: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>SHM Panel Installation</h1>
        
        <div class="progress">
            <div class="progress-step active">1. Database</div>
            <div class="progress-step">2. Admin Account</div>
            <div class="progress-step">3. Complete</div>
        </div>

        <form id="installForm" action="process.php" method="post">
            <!-- Step 1: Database Configuration -->
            <div class="step active" id="step1">
                <div class="form-group">
                    <label>Database Host</label>
                    <input type="text" name="db_host" value="localhost" required>
                </div>
                <div class="form-group">
                    <label>Database Name</label>
                    <input type="text" name="db_name" value="shm_panel" required>
                </div>
                <div class="form-group">
                    <label>Database Username</label>
                    <input type="text" name="db_user" value="root" required>
                </div>
                <div class="form-group">
                    <label>Database Password</label>
                    <input type="password" name="db_pass">
                </div>
                <button type="button" onclick="nextStep(2)">Next</button>
            </div>

            <!-- Step 2: Admin Account -->
            <div class="step" id="step2">
                <div class="form-group">
                    <label>Admin Username</label>
                    <input type="text" name="admin_user" value="admin" required>
                </div>
                <div class="form-group">
                    <label>Admin Email</label>
                    <input type="email" name="admin_email" required>
                </div>
                <div class="form-group">
                    <label>Admin Password</label>
                    <input type="password" name="admin_pass" required>
                </div>
                <div class="form-group">
                    <label>Confirm Password</label>
                    <input type="password" name="admin_pass_confirm" required>
                </div>
                <button type="button" onclick="prevStep(1)">Previous</button>
                <button type="submit">Install</button>
            </div>
        </form>

        <div id="messages"></div>
    </div>

    <script>
        function nextStep(step) {
            document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
            document.querySelectorAll('.progress-step').forEach(s => s.classList.remove('active'));
            document.getElementById('step' + step).classList.add('active');
            document.querySelectorAll('.progress-step')[step-1].classList.add('active');
        }

        function prevStep(step) {
            document.querySelectorAll('.step').forEach(s => s.classList.remove('active'));
            document.querySelectorAll('.progress-step').forEach(s => s.classList.remove('active'));
            document.getElementById('step' + step).classList.add('active');
            document.querySelectorAll('.progress-step')[step-1].classList.add('active');
        }

        document.getElementById('installForm').addEventListener('submit', function(e) {
            e.preventDefault();
            const formData = new FormData(this);
            
            fetch('process.php', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    window.location.href = 'success.php';
                } else {
                    document.getElementById('messages').innerHTML = 
                        '<div class="error">' + data.message + '</div>';
                }
            });
        });
    </script>
</body>
</html>