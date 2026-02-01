<?php

namespace App\Modules\Auth\Models;

use App\Core\Database;
use PDO;

class User
{
    public static function find($username)
    {
        return Database::fetch("SELECT * FROM users WHERE username = ? OR email = ?", [$username, $username]);
    }

    // Deprecated wrappers for compatibility during migration
    public static function findClient($username)
    {
        return self::find($username);
    }

    public static function findAdmin($username)
    {
        return self::find($username);
    }
}
