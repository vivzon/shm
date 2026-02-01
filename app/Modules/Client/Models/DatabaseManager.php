<?php

namespace App\Modules\Client\Models;

use App\Core\Database;

class DatabaseManager
{
    public static function getLimits($clientId)
    {
        return Database::fetch("SELECT p.max_databases FROM clients c JOIN packages p ON c.package_id = p.id WHERE c.id = ?", [$clientId]);
    }

    public static function getDatabases($clientId, $limit, $offset)
    {
        return Database::fetchAll("SELECT cd.*, d.domain FROM client_databases cd LEFT JOIN domains d ON cd.domain_id = d.id WHERE cd.client_id = ? ORDER BY d.domain DESC LIMIT $limit OFFSET $offset", [$clientId]);
    }

    public static function getDatabaseCount($clientId)
    {
        $res = Database::fetch("SELECT COUNT(*) as cnt FROM client_databases WHERE client_id = ?", [$clientId]);
        return $res['cnt'];
    }

    public static function getDbUsers($clientId)
    {
        return Database::fetchAll("SELECT * FROM client_db_users WHERE client_id = ?", [$clientId]);
    }

    public static function createDatabase($clientId, $domainId, $dbName)
    {
        Database::query("INSERT INTO client_databases (client_id, domain_id, db_name) VALUES (?, ?, ?)", [$clientId, $domainId, $dbName]);
    }

    public static function createDbUser($clientId, $dbUser)
    {
        Database::query("INSERT INTO client_db_users (client_id, db_user) VALUES (?, ?)", [$clientId, $dbUser]);
    }

    public static function deleteDatabase($clientId, $dbName)
    {
        return Database::query("DELETE FROM client_databases WHERE db_name = ? AND client_id = ?", [$dbName, $clientId]);
    }

    public static function hasDatabaseAccess($clientId, $dbName)
    {
        return Database::fetch("SELECT id FROM client_databases WHERE db_name = ? AND client_id = ?", [$dbName, $clientId]);
    }

    public static function hasDbUserAccess($clientId, $dbUser)
    {
        return Database::fetch("SELECT id FROM client_db_users WHERE db_user = ? AND client_id = ?", [$dbUser, $clientId]);
    }
}
