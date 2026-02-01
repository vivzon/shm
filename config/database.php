<?php
// config/database.php

// Attempt to load from environment or legacy local config if needed
// For now, hardcoding based on legacy shared/config.php fallback
return [
    'host' => 'localhost',
    'dbname' => 'shm_panel',
    'username' => 'shm_admin',
    'password' => 'SHMPanel_Secure_Pass_2025',
    'charset' => 'utf8mb4'
];
