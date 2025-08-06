<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Services\GoogleSheetsService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Session;
use Illuminate\Support\Facades\Storage; // Добавлено

class ProductController extends Controller
{
    public function index()
    {
        $products = Product::paginate(10);
        // Изменено: чтение из файлового хранилища
        $currentSpreadsheetId = Storage::exists('spreadsheet_id.txt') 
            ? Storage::get('spreadsheet_id.txt') 
            : env('GOOGLE_SPREADSHEET_ID');
        return view('products.index', compact('products', 'currentSpreadsheetId'));
    }

    public function create()
    {
        return view('products.create');
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'status' => 'required|in:Allowed,Prohibited',
        ]);

        Product::create($request->all());

        return redirect()->route('products.index')
            ->with('success', 'Product created successfully.');
    }

    public function show(Product $product)
    {
        return view('products.show', compact('product'));
    }

    public function edit(Product $product)
    {
        return view('products.edit', compact('product'));
    }

    public function update(Request $request, Product $product)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'status' => 'required|in:Allowed,Prohibited',
        ]);

        $product->update($request->all());

        return redirect()->route('products.index')
            ->with('success', 'Product updated successfully.');
    }

    public function destroy(Product $product)
    {
        $product->delete();

        return redirect()->route('products.index')
            ->with('success', 'Product deleted successfully.');
    }

    public function generateDemoData()
    {
        $statuses = ['Allowed', 'Prohibited'];
        
        for ($i = 0; $i < 1000; $i++) {
            Product::create([
                'name' => 'Product ' . ($i+1),
                'price' => rand(100, 10000) / 100,
                'status' => $statuses[rand(0, 1)]
            ]);
        }

        return redirect()->back()->with('success', '1000 demo records generated!');
    }

    public function clearAll()
    {
        Product::truncate();
        return redirect()->back()->with('success', 'All products deleted!');
    }

      public function setSpreadsheetUrl(Request $request)
    {
        $request->validate([
            'spreadsheet_url' => 'required|url'
        ]);
        
        $url = $request->input('spreadsheet_url');
        
        // Улучшенная проверка URL
        $patterns = [
            '/\/d\/([a-zA-Z0-9-_]+)/',         // Стандартный URL
            '/spreadsheets\/d\/([a-zA-Z0-9-_]+)/', // URL для редактирования
            '/key=([a-zA-Z0-9-_]+)/',           // Старый формат
            '/[\/=]([a-zA-Z0-9-_]{44})/'        // Универсальный по длине
        ];
        
        $spreadsheetId = null;
        
        foreach ($patterns as $pattern) {
            if (preg_match($pattern, $url, $matches)) {
                $spreadsheetId = $matches[1];
                break;
            }
        }
        
        // Валидация ID
        if ($spreadsheetId && (strlen($spreadsheetId) >= 30 && strlen($spreadsheetId) <= 50)) {
            // Сохраняем в файловое хранилище
            Storage::put('spreadsheet_id.txt', $spreadsheetId);
            return redirect()->back()->with('success', 'Spreadsheet ID updated!');
        }
        
        return redirect()->back()->with('error', 'Invalid Google Sheets URL');
    }

    public function resetSpreadsheet()
    {
        // Удаляем из файлового хранилища
        if (Storage::exists('spreadsheet_id.txt')) {
            Storage::delete('spreadsheet_id.txt');
        }
        return redirect()->back()->with('success', 'Spreadsheet reset to default!');
    }

    public function sync(GoogleSheetsService $sheets)
    {
        try {
            // Получаем текущий ID таблицы
            $spreadsheetId = Session::get('user_spreadsheet_id', env('GOOGLE_SPREADSHEET_ID'));
            
            // Устанавливаем в сервисе
            $sheets->setSpreadsheetId($spreadsheetId);
            
            // Вызываем команду синхронизации
            \Artisan::call('sync:google-sheets');
            
            return redirect()->back()->with('success', 'Synchronization started!');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Synchronization failed: ' . $e->getMessage());
        }
    }
}