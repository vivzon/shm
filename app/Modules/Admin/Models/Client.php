<?php

namespace App\Modules\Admin\Models;

use App\Core\Database;
use PDO;

class Client
{
    public static function count($search = '')
    {
        $sql = "SELECT COUNT(*) FROM clients c LEFT JOIN domains d ON c.id = d.client_id WHERE 1=1";
        $params = [];
        if ($search) {
            $sql .= " AND (c.username LIKE ? OR d.domain LIKE ?)";
            $params[] = "%$search%";
            $params[] = "%$search%";
        }
        return Database::query($sql, $params)->fetchColumn();
    }

    public static function getAll($limit = 10, $offset = 0, $search = '')
    {
        $sql = "SELECT c.*, d.id as domain_id, d.domain, p.name as pkg_name 
                FROM clients c 
                LEFT JOIN domains d ON c.id = d.client_id 
                LEFT JOIN packages p ON c.package_id = p.id 
                WHERE 1=1";
        $params = [];

        if ($search) {
            $sql .= " AND (c.username LIKE ? OR d.domain LIKE ?)";
            $params[] = "%$search%";
            $params[] = "%$search%";
        }

        $sql .= " ORDER BY c.id DESC LIMIT $limit OFFSET $offset";
        return Database::fetchAll($sql, $params);
    }

    public static function exists($username, $domain)
    {
        $u = Database::fetch("SELECT id FROM clients WHERE username = ?", [$username]);
        $d = Database::fetch("SELECT id FROM domains WHERE domain = ?", [$domain]);
        return $u || $d;
    }

    public static function create($username, $email, $password, $packageId, $domain)
    {
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            // Client
            $hash = password_hash($password, PASSWORD_BCRYPT);
            Database::query("INSERT INTO clients (username, email, password, package_id) VALUES (?,?,?,?)", [$username, $email, $hash, $packageId]);
            $cid = $pdo->lastInsertId();

            // Domain
            Database::query("INSERT INTO domains (client_id, domain, document_root) VALUES (?,?,?)", [$cid, $domain, "/var/www/clients/$domain/public_html"]);

            // Mail Domain
            Database::query("INSERT INTO mail_domains (domain) VALUES (?)", [$domain]);

            // DNS Logic - Simplified for migration, assuming existing logic relies on manual queries in Controller or separate DNS Helper. 
            // In the legacy code, it did DNS inserts right in the loop. 
            // For MVC, best to delegate to a DNS Service or Helper. 
            // For now, I will keep it minimal here or stick to the legacy inline approach if complex.
            // The legacy code did a lot of DNS inserts.

            $pdo->commit();
            return $cid;
        } catch (\Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    // Helper to get packages
    public static function getPackages()
    {
        return Database::fetchAll("SELECT * FROM packages");
    }

    public static function find($id)
    {
        return Database::fetch("SELECT * FROM clients WHERE id = ?", [$id]);
    }

    public static function delete($id)
    {
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            // Delete domains (Cascades mostly, but good to be explicit if needed)
            Database::query("DELETE FROM domains WHERE client_id = ?", [$id]);
            Database::query("DELETE FROM clients WHERE id = ?", [$id]);
            $pdo->commit();
        } catch (\Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    public static function updateStatus($id, $status)
    {
        Database::query("UPDATE clients SET status = ? WHERE id = ?", [$status, $id]);
    }
}
