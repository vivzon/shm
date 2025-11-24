<?php
// Security: Prevent accessing this page if not actually installed
if (!file_exists('../includes/db.php')) {
    header('Location: index.php');
    exit;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Installation Complete - SHM Panel</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f0f2f5; display: flex; align-items: center; justify-content: center; height: 100vh; }
        
        .container { 
            background: white; 
            padding: 40px; 
            border-radius: 12px; 
            box-shadow: 0 5px 20px rgba(0,0,0,0.1); 
            text-align: center; 
            max-width: 500px; 
            width: 90%; 
        }

        .success-icon {
            width: 80px;
            height: 80px;
            background: #28a745;
            color: white;
            border-radius: 50%;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 40px;
            margin-bottom: 20px;
            animation: popIn 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275);
        }

        h1 { color: #333; margin-bottom: 10px; }
        p { color: #666; margin-bottom: 25px; line-height: 1.5; }

        .btn {
            display: inline-block;
            background: #007bff;
            color: white;
            padding: 15px 40px;
            text-decoration: none;
            border-radius: 8px;
            font-weight: bold;
            font-size: 16px;
            transition: background 0.3s;
            width: 100%;
        }
        
        .btn:hover { background: #0056b3; }

        .security-notice {
            margin-top: 30px;
            padding: 15px;
            background: #fff3cd;
            border: 1px solid #ffeeba;
            color: #856404;
            border-radius: 6px;
            font-size: 14px;
            text-align: left;
        }

        @keyframes popIn {
            0% { transform: scale(0); opacity: 0; }
            100% { transform: scale(1); opacity: 1; }
        }
    </style>
</head>
<body>

    <div class="container">
        <div class="success-icon">✓</div>
        <h1>Installation Successful!</h1>
        <p>SHM Panel has been installed correctly. The database is setup and your admin account is ready.</p>

        <a href="../index.php" class="btn">Go to Login Page</a>

        <div class="security-notice">
            <strong>⚠️ Security Warning:</strong><br>
            Please delete the <code>/install</code> folder from your server now to prevent anyone else from re-installing the system.
        </div>
    </div>

</body>
</html>
