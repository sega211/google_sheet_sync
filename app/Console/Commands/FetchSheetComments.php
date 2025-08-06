<?php

namespace App\Console\Commands;

use App\Services\GoogleSheetsService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

class FetchSheetComments extends Command
{
    protected $signature = 'fetch:comments 
                            {--count= : Limit number of rows}
                            {--comments-only : Show only rows with comments}';
    
    protected $description = 'Fetch comments from Google Sheet';

    public function handle(GoogleSheetsService $sheets)
    {
        // Чтение ID из файлового хранилища
        if (Storage::exists('spreadsheet_id.txt')) {
            $spreadsheetId = Storage::get('spreadsheet_id.txt');
            $sheets->setSpreadsheetId($spreadsheetId);
        }

        $data = $sheets->getSheetData();
        $totalRecords = count($data);
        $this->info("Total records found: $totalRecords");
        
        if ($totalRecords === 0) {
            $this->info('No records found');
            return;
        }
        
        // Фильтрация данных
        $filteredData = [];
        $commentsCount = 0;
        
        foreach ($data as $row) {
            $comment = $row[6] ?? '';
            
            // Пропускаем пустые комментарии при включенной опции
            if ($this->option('comments-only') && (empty($comment) || $comment === 'No comment')) {
                continue;
            }
            
            $filteredData[] = $row;
            if (!empty($comment)) $commentsCount++;
        }
        
        $filteredCount = count($filteredData);
        $this->info("Filtered records: $filteredCount (with comments: $commentsCount)");
        
        // Ограничение количества
        $count = $this->option('count');
        if ($count) {
            $filteredData = array_slice($filteredData, 0, (int)$count);
            $this->info("Limited to $count records");
        }
        
        if (count($filteredData) === 0) {
            $this->info('No matching records found');
            return;
        }
        
        // Прогресс-бар и вывод
        $bar = $this->output->createProgressBar(count($filteredData));
        $bar->start();

        foreach ($filteredData as $row) {
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