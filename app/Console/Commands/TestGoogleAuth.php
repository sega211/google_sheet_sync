<?php
namespace App\Console\Commands;

use Illuminate\Console\Command;
use Google_Client;
use Illuminate\Support\Facades\Log;

class TestGoogleAuth extends Command
{
    protected $signature = 'test:google-auth';
    protected $description = 'Test Google API authentication';

    public function handle()
    {
        try {
            $client = new Google_Client();
            $base64Json = env('GOOGLE_SERVICE_ACCOUNT_JSON_BASE64');
            
            if (!$base64Json) {
                $this->error('GOOGLE_SERVICE_ACCOUNT_JSON_BASE64 not set');
                return 1;
            }
            
            $jsonContent = base64_decode($base64Json);
            if ($jsonContent === false) {
                $this->error('Failed to decode base64 content');
                return 1;
            }
            
            $tempJsonPath = '/tmp/test-service-account.json';
            file_put_contents($tempJsonPath, $jsonContent);
            
            if (!file_exists($tempJsonPath)) {
                $this->error('Failed to create temporary file');
                return 1;
            }
            
            $client->setAuthConfig($tempJsonPath);
            $client->addScope('https://www.googleapis.com/auth/spreadsheets');
            $client->fetchAccessTokenWithAssertion();
            
            $token = $client->getAccessToken();
            $this->info('Authentication successful!');
            $this->line('Access token: ' . $token['access_token']);
            $this->line('Expires at: ' . date('Y-m-d H:i:s', $token['created'] + $token['expires_in']));
            
            return 0;
        } catch (\Exception $e) {
            $this->error('Authentication failed: ' . $e->getMessage());
            Log::error('Google auth test failed', ['error' => $e->getMessage()]);
            return 1;
        }
    }
}