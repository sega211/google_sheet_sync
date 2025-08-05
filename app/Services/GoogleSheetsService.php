<?php

namespace App\Services;

use Google_Client;
use Google_Service_Sheets;
use Google_Service_Sheets_ValueRange;
use Google_Service_Sheets_ClearValuesRequest;
use Illuminate\Support\Facades\Log;

class GoogleSheetsService
{
    protected $service;
    protected $spreadsheetId;

    public function __construct()
    {
        $client = new Google_Client();
        $jsonPath = storage_path(env('GOOGLE_SERVICE_ACCOUNT_JSON'));
    
        if (!file_exists($jsonPath)) {
            throw new \Exception("Google service account JSON file not found at: $jsonPath");
        }
    
        $client->setAuthConfig($jsonPath);
        $client->addScope(Google_Service_Sheets::SPREADSHEETS);
        $this->service = new Google_Service_Sheets($client);
        $this->spreadsheetId = env('GOOGLE_SPREADSHEET_ID');
    }

    public function setSpreadsheetId($spreadsheetId)
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