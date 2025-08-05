@extends('layouts.app')

@section('content')
<div class="container">
    <h1>Product Details</h1>
    <div class="card">
        <div class="card-body">
            <h5 class="card-title">{{ $product->name }}</h5>
            <p class="card-text">
                <strong>ID:</strong> {{ $product->id }}<br>
                <strong>Price:</strong> ${{ number_format($product->price, 2) }}<br>
                <strong>Status:</strong> 
                <span class="badge bg-{{ $product->status == 'Allowed' ? 'success' : 'danger' }}">
                    {{ $product->status }}
                </span><br>
                <strong>Created:</strong> {{ $product->created_at->format('Y-m-d H:i') }}<br>
                <strong>Updated:</strong> {{ $product->updated_at->format('Y-m-d H:i') }}
            </p>
            <a href="{{ route('products.index') }}" class="btn btn-primary">
                <i class="fas fa-arrow-left"></i> Back to List
            </a>
        </div>
    </div>
</div>
@endsection