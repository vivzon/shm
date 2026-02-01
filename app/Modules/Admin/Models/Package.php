<?php

namespace App\Modules\Admin\Models;

use App\Core\Database;

class Package
{
    public static function getAll()
    {
        return Database::fetchAll("SELECT * FROM packages");
    }

    public static function find($id)
    {
        return Database::fetch("SELECT * FROM packages WHERE id = ?", [$id]);
    }

    public static function exists($name, $excludeId = 0)
    {
        return Database::fetch("SELECT id FROM packages WHERE name = ? AND id != ?", [$name, $excludeId]);
    }

    public static function create($name, $disk, $domains, $emails)
    {
        Database::query(
            "INSERT INTO packages (name, disk_mb, max_domains, max_emails) VALUES (?,?,?,?)",
            [$name, $disk, $domains, $emails]
        );
    }

    public static function update($id, $name, $disk, $domains, $emails)
    {
        Database::query(
            "UPDATE packages SET name=?, disk_mb=?, max_domains=?, max_emails=? WHERE id=?",
            [$name, $disk, $domains, $emails, $id]
        );
    }

    public static function delete($id)
    {
        Database::query("DELETE FROM packages WHERE id = ?", [$id]);
    }
}
