<?php

namespace App\Services;

use Google_Client;
use Google_Service_Sheets;
use Google_Service_Sheets_ValueRange;
use Google_Service_Sheets_ClearValuesRequest;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

class GoogleSheetsService
{
      protected $service;
    protected $spreadsheetId;

    public function __construct()
    {
        $client = new Google_Client();
        $client->setAuthConfig($this->getServiceAccountConfig());
        $client->addScope(Google_Service_Sheets::SPREADSHEETS);
        $client->setAccessType('offline');
        
        $this->service = new Google_Service_Sheets($client);
        $this->spreadsheetId = env('GOOGLE_SPREADSHEET_ID');
        
        Log::debug('Google Sheets service initialized', [
            'spreadsheet_id' => $this->spreadsheetId
        ]);
    }

    protected function getServiceAccountConfig(): array
    {
        $base64Json = env('GOOGLE_SERVICE_ACCOUNT_JSON_BASE64');
        
        if (!$base64Json) {
            throw new \Exception("Переменная GOOGLE_SERVICE_ACCOUNT_JSON_BASE64 не установлена");
        }
        
        $jsonContent = base64_decode($base64Json);
        
        if ($jsonContent === false) {
            throw new \Exception("Не удалось декодировать строку base64");
        }
        
        $config = json_decode($jsonContent, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new \Exception("Содержимое не является валидным JSON: " . json_last_error_msg());
        }
        
        // Исправляем формат приватного ключа
        if (isset($config['private_key'])) {
            $config['private_key'] = str_replace('\n', "\n", $config['private_key']);
        }
        
        return $config;
    }

 public function setSpreadsheetId(string $spreadsheetId): void
    {
        $this->spreadsheetId = $spreadsheetId;
    }

    public function getSheetData()
    {
        $range = 'A2:H';
        $response = $this->service->spreadsheets_values->get($this->spreadsheetId, $range);
        return $response->getValues() ?? [];
    }
    
    public function getSheetDataWithComments()
    {
        return $this->getSheetData();
    }

    public function updateSheetData($data)
    {
        try {
            $comments = $this->getCommentsMap();
            
            $newData = [];
            foreach ($data as $row) {
                $id = $row[0];
                $newRow = $row; 
                
                $newRow[] = $comments[$id] ?? '';
                
                $newData[] = $newRow;
            }
            
            $this->updateSheet($newData);
            
            Log::info('Google Sheets updated with ' . count($newData) . ' rows');
        } catch (\Exception $e) {
            Log::error('Google Sheets update error: ' . $e->getMessage());
            throw $e;
        }
    }

    private function getCommentsMap()
    {
        $comments = [];
        $range = 'A2:G'; 
        $response = $this->service->spreadsheets_values->get(
            $this->spreadsheetId,
            $range
        );
        
        $data = $response->getValues() ?? [];
        
        foreach ($data as $row) {
            if (!empty($row[0])) {
                $comment = '';
                
                if (count($row) > 6 && isset($row[6])) {
                    $comment = $row[6];
                }
                
                $comments[$row[0]] = $comment;
            }
        }
        
        return $comments;
    }

    private function updateSheet(array $data)
    {
        $range = 'A2'; 
        $body = new Google_Service_Sheets_ValueRange([
            'values' => $data
        ]);
        
        $params = [
            'valueInputOption' => 'RAW',
            'includeValuesInResponse' => true
        ];
        
        $this->clearDataRange();
        
        $this->service->spreadsheets_values->update(
            $this->spreadsheetId,
            $range,
            $body,
            $params
        );
    }

    private function clearDataRange()
    {
        try {
            $response = $this->service->spreadsheets_values->get(
                $this->spreadsheetId,
                'A2:A' 
            );
            
            $values = $response->getValues();
            $rowCount = $values ? count($values) : 0;

            if ($rowCount > 0) {
                $range = 'A2:F' . ($rowCount + 1); 
                $clearRequest = new Google_Service_Sheets_ClearValuesRequest();
                $this->service->spreadsheets_values->clear(
                    $this->spreadsheetId,
                    $range,
                    $clearRequest
                );
                Log::info('Cleared data range: ' . $range);
            }
        } catch (\Exception $e) {
            Log::error('Error clearing data range: ' . $e->getMessage());
            throw $e;
        }
    }
}