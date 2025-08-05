<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Services\GoogleSheetsService;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function index()
    {
        $products = Product::paginate(10);
        $spreadsheetId = env('GOOGLE_SPREADSHEET_ID');
        return view('products.index', compact('products', 'spreadsheetId'));
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

    public function setSpreadsheetUrl(Request $request, GoogleSheetsService $sheets)
    {
        $url = $request->input('spreadsheet_url');
        
        preg_match('/\/d\/([a-zA-Z0-9-_]+)/', $url, $matches);
        $spreadsheetId = $matches[1] ?? null;

        if ($spreadsheetId) {
            $sheets->setSpreadsheetId($spreadsheetId);
            return redirect()->back()->with('success', 'Spreadsheet ID updated!');
        }

        return redirect()->back()->with('error', 'Invalid Google Sheets URL');
    }

    public function sync(GoogleSheetsService $sheets)
    {
        \Artisan::call('sync:google-sheets');
        return redirect()->back()->with('success', 'Synchronization started!');
    }
}