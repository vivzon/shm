<?php

namespace App\Modules\Admin\Models;

use App\Core\Database;

class Reseller
{
    public static function count($search = '')
    {
        $sql = "SELECT COUNT(*) FROM users WHERE role = 'reseller'";
        $params = [];
        if ($search) {
            $sql .= " AND (username LIKE ? OR email LIKE ?)";
            $params[] = "%$search%";
            $params[] = "%$search%";
        }
        return Database::fetchColumn($sql, $params);
    }

    public static function getAll($limit = 10, $offset = 0, $search = '')
    {
        $sql = "SELECT * FROM users WHERE role = 'reseller'";
        $params = [];

        if ($search) {
            $sql .= " AND (username LIKE ? OR email LIKE ?)";
            $params[] = "%$search%";
            $params[] = "%$search%";
        }

        $sql .= " ORDER BY id DESC LIMIT $limit OFFSET $offset";
        return Database::fetchAll($sql, $params);
    }

    public static function exists($username)
    {
        return Database::fetch("SELECT id FROM users WHERE username = ?", [$username]);
    }

    public static function create($username, $email, $password, $limit_accounts = 10, $limit_disk = 10000)
    {
        $hash = password_hash($password, PASSWORD_BCRYPT);
        // Note: We might need a 'limits' table or store limits in features/JSON if not in main table
        // For now assuming existing schema doesn't have specific reseller limits columns, 
        // we might store them in a JSON field if available, or just create the user first.
        // The migration added 'features' to packages, maybe we need 'metadata' in users?
        // Let's just create the user with role 'reseller'.

        Database::query(
            "INSERT INTO users (username, email, password, role, status) VALUES (?, ?, ?, 'reseller', 'active')",
            [$username, $email, $hash]
        );
        return Database::pdo()->lastInsertId();
    }

    public static function find($id)
    {
        return Database::fetch("SELECT * FROM users WHERE id = ? AND role = 'reseller'", [$id]);
    }

    public static function delete($id)
    {
        // Recursively delete clients owned by reseller? 
        // Or reassign? For now, strict delete.
        Database::query("DELETE FROM users WHERE id = ?", [$id]);
    }

    public static function updateStatus($id, $status)
    {
        Database::query("UPDATE users SET status = ? WHERE id = ?", [$status, $id]);
    }
}
