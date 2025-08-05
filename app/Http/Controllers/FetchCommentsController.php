<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Artisan;
use Symfony\Component\Console\Output\BufferedOutput;

class FetchCommentsController extends Controller
{
    public function fetch($count = null)
    {
        $output = new BufferedOutput;
        $options = [];
        if ($count) {
            $options['--count'] = $count;
        }
               
        try {
            Artisan::call('fetch:comments', $options, $output);
            $result = $output->fetch();
            return response('<pre>' . $result . '</pre>', 200)
                ->header('Content-Type', 'text/plain');
        } catch (\Exception $e) {
            return response('<pre>Error: ' . $e->getMessage() . '</pre>', 500)
                ->header('Content-Type', 'text/plain');
        }
    }
}