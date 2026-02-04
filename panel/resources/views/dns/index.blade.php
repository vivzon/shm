@extends('layouts.app')

@section('title', 'DNS Management')

@section('content')
    <div class="mb-8">
        <h2 class="text-3xl font-bold">DNS Management</h2>
        <p class="text-gray-500">Select a domain to manage its DNS zones and records.</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        @foreach($domains as $domain)
            <div
                class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 hover:shadow-md transition duration-200">
                <div class="flex items-center mb-4">
                    <div
                        class="w-10 h-10 bg-indigo-100 dark:bg-indigo-900 rounded-lg flex items-center justify-center text-indigo-600 dark:text-indigo-400 mr-4">
                        <i class="fas fa-globe"></i>
                    </div>
                    <h3 class="text-lg font-bold">{{ $domain->domain_name }}</h3>
                </div>
                <div class="flex justify-between items-center mt-6">
                    <span class="text-sm text-gray-500">{{ $domain->dnsRecords()->count() }} Records</span>
                    <a href="{{ route('dns.show', $domain->id) }}"
                        class="text-indigo-600 dark:text-indigo-400 font-bold hover:underline">Manage DNS</a>
                </div>
            </div>
        @endforeach
    </div>
@endsection