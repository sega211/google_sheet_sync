<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Services\GoogleSheetsService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class SyncGoogleSheets extends Command
{
    protected $signature = 'sync:google-sheets';
    protected $description = 'Synchronize products with Google Sheets';

    public function handle(GoogleSheetsService $sheets)
    {
        try {
            // Используем scope allowed
            $products = Product::allowed()->get();
            
            $this->info('Found ' . $products->count() . ' allowed products');
            
            $data = [];
            foreach ($products as $product) {
                $data[] = [
                    $product->id,
                    $product->name,
                    $product->price,
                    $product->status,
                    $product->created_at->format('Y-m-d H:i:s'),
                    $product->updated_at->format('Y-m-d H:i:s')
                ];
            }
            
            $this->info('Updating Google Sheet with ' . count($data) . ' rows...');
            $sheets->updateSheetData($data);
            
            $this->info('Successfully synchronized with Google Sheets!');
        } catch (\Exception $e) {
            Log::error('Google Sheets sync error: ' . $e->getMessage());
            $this->error('Synchronization failed: ' . $e->getMessage());
        }
    }
}