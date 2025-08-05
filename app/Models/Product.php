<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $fillable = ['name', 'price', 'status'];
    
    const STATUS_ALLOWED = 'Allowed';
    const STATUS_PROHIBITED = 'Prohibited';
    
    public static function statuses()
    {
        return [
            self::STATUS_ALLOWED,
            self::STATUS_PROHIBITED
        ];
    }
    
    public function scopeAllowed($query)
    {
        return $query->where('status', self::STATUS_ALLOWED);
    }
}