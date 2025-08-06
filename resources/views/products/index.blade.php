<!DOCTYPE html>
<html>
<head>
    <title>Products Management</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <h1 class="my-4">Products Management</h1>
        
        @if(session('success'))
            <div class="alert alert-success">
                {{ session('success') }}
            </div>
        @endif
        
        @if(session('error'))
            <div class="alert alert-danger">
                {{ session('error') }}
            </div>
        @endif
        
        <div class="mb-4">
            <a href="{{ route('products.create') }}" class="btn btn-primary">
                <i class="fas fa-plus"></i> Create Product
            </a>
            
            <div class="mt-3">
                <form action="{{ route('products.generate') }}" method="POST" class="d-inline">
                    @csrf
                    <button type="submit" class="btn btn-secondary">
                        <i class="fas fa-bolt"></i> Generate 1000 Products
                    </button>
                </form>
                
                <form action="{{ route('products.clear') }}" method="POST" class="d-inline ms-2">
                    @csrf
                    <button type="submit" class="btn btn-danger">
                        <i class="fas fa-trash"></i> Clear All Products
                    </button>
                </form>
                
                <form action="{{ route('products.sync') }}" method="POST" class="d-inline ms-2">
                    @csrf
                    <button type="submit" class="btn btn-success">
                        <i class="fas fa-sync"></i> Sync with Google Sheets
                    </button>
                </form>
            </div>
        </div>
        
        <div class="card mb-4">
            <div class="card-header">
                <h5>Google Sheets Integration</h5>
            </div>
           <div class="card-body">
                <form action="{{ route('products.set-spreadsheet') }}" method="POST">
                    @csrf
                    <div class="input-group mb-3">
                        <input type="url" name="spreadsheet_url" 
                            placeholder="Google Sheet URL" 
                            class="form-control"
                            required>
                        <button type="submit" class="btn btn-info">
                            <i class="fas fa-link"></i> Set Spreadsheet
                        </button>
                    </div>
                </form>

                @if($currentSpreadsheetId)
                    <div class="d-flex align-items-center justify-content-between">
                        <div>
                            <small class="text-muted">Current Spreadsheet ID:</small>
                            <strong>{{ $currentSpreadsheetId }}</strong>
                        </div>
                        <form action="{{ route('products.reset-spreadsheet') }}" method="POST">
                            @csrf
                            <button type="submit" class="btn btn-sm btn-warning">
                                <i class="fas fa-undo"></i> Reset
                            </button>
                        </form>
                    </div>
                @endif
            </div>
        </div>
        
        <div class="card">
            <div class="card-header">
                <h5>Products List</h5>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Name</th>
                                <th>Price</th>
                                <th>Status</th>
                                <th>Created</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach($products as $product)
                                <tr>
                                    <td>{{ $product->id }}</td>
                                    <td>{{ $product->name }}</td>
                                    <td>{{ number_format($product->price, 2) }}</td>
                                    <td>
                                        <span class="badge bg-{{ $product->status == 'Allowed' ? 'success' : 'danger' }}">
                                            {{ $product->status }}
                                        </span>
                                    </td>
                                    <td>{{ $product->created_at->format('Y-m-d') }}</td>
                                    <td>
                                        <a href="{{ route('products.show', $product) }}" 
                                            class="btn btn-sm btn-info">
                                            <i class="fas fa-eye"></i>
                                        </a>
                                        <a href="{{ route('products.edit', $product) }}" 
                                            class="btn btn-sm btn-warning">
                                            <i class="fas fa-edit"></i>
                                        </a>
                                        <form action="{{ route('products.destroy', $product) }}" 
                                            method="POST" class="d-inline">
                                            @csrf
                                            @method('DELETE')
                                            <button type="submit" class="btn btn-sm btn-danger"
                                                onclick="return confirm('Are you sure?')">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </form>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
                
                {{ $products->links() }}
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>