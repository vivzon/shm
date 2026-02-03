<?php

namespace App\Modules\Client\Models;

use App\Core\Database;

class Domain
{
    public static function getAll($clientId)
    {
        return Database::fetchAll("SELECT * FROM domains WHERE client_id = ? ORDER BY id DESC", [$clientId]);
    }

    public static function find($id, $clientId)
    {
        return Database::fetch("SELECT * FROM domains WHERE id = ? AND client_id = ?", [$id, $clientId]);
    }

    public static function create($clientId, $domain, $path)
    {
        Database::query("INSERT INTO domains (client_id, domain, document_root) VALUES (?,?,?)", [$clientId, $domain, $path]);
        return Database::pdo()->lastInsertId();
    }

    public static function delete($id, $clientId)
    {
        Database::query("DELETE FROM domains WHERE id = ? AND client_id = ?", [$id, $clientId]);
    }

    public static function exists($domain)
    {
        return Database::fetch("SELECT id FROM domains WHERE domain = ?", [$domain]);
    }

    public static function existsForClient($domain, $clientId)
    {
        return Database::fetch("SELECT id FROM domains WHERE domain = ? AND client_id = ?", [$domain, $clientId]);
    }
}
