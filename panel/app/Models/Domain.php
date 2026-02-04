<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Domain extends Model
{
    protected $fillable = [
        'user_id',
        'domain_name',
        'document_root',
        'php_version',
        'has_ssl',
        'ssl_provider',
        'status',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function subdomains()
    {
        return $this->hasMany(Subdomain::class);
    }

    public function emailAccounts()
    {
        return $this->hasMany(EmailAccount::class);
    }
}
