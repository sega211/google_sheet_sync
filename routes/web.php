<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\FetchCommentsController;
Route::get('/health', function() {
    return response()->json([
        'status' => 'ok',
        'services' => [
            'nginx' => true,
            'php' => true,
            'db' => DB::connection()->getPdo() ? true : false
        ]
    ]);
});
Route::resource('products', ProductController::class);

Route::prefix('products')->group(function () {
    Route::post('/generate-demo', [ProductController::class, 'generateDemoData'])
        ->name('products.generate'); 
    
    Route::post('/clear', [ProductController::class, 'clearAll'])
        ->name('products.clear');
    
    Route::post('/set-spreadsheet', [ProductController::class, 'setSpreadsheetUrl'])
        ->name('products.set-spreadsheet');
    Route::post('/reset-spreadsheet', [ProductController::class, 'resetSpreadsheet'])->name('products.reset-spreadsheet');
    
    Route::post('/sync', [ProductController::class, 'sync'])
        ->name('products.sync');
});

// Fetch Comments Routes
Route::get('/fetch', [FetchCommentsController::class, 'fetch']);
Route::get('/fetch/{count}', [FetchCommentsController::class, 'fetch'])
    ->where('count', '[0-9]+');