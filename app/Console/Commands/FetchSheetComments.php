<?php

namespace App\Console\Commands;

use App\Services\GoogleSheetsService;
use Illuminate\Console\Command;

class FetchSheetComments extends Command
{
    protected $signature = 'fetch:comments {--count=}';
    protected $description = 'Fetch comments from Google Sheet';

    public function handle(GoogleSheetsService $sheets)
    {
        $data = $sheets->getSheetData();
        $count = $this->option('count');
        
        if ($count) {
            $data = array_slice($data, 0, (int)$count);
        }
        
        $this->info("Found " . count($data) . " records");
        
        if (count($data) === 0) {
            $this->info('No records found');
            return;
        }
        
        $bar = $this->output->createProgressBar(count($data));
        $bar->start();

        foreach ($data as $row) {
            $id = $row[0] ?? 'N/A';
            $comment = $row[6] ?? 'No comment';
            
            $this->info("\nID: {$id} | Comment: {$comment}");
            $bar->advance();
        }

        $bar->finish();
        $this->newLine();
        $this->info('Completed!');
    }
}