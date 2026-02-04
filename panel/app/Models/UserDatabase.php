<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserDatabase extends Model
{
    protected $table = 'user_databases';

    protected $fillable = [
        'user_id',
        'db_name',
        'db_user',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
