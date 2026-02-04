<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmailAccount extends Model
{
    protected $fillable = [
        'domain_id',
        'email_address',
        'password_hash',
        'quota',
    ];

    public function domain()
    {
        return $this->belongsTo(Domain::class);
    }
}
