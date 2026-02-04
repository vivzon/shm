@extends('layouts.app')

@section('title', 'Domain Management')

@section('content')
    <div class="flex justify-between items-center mb-8">
        <h2 class="text-3xl font-bold">Domains</h2>
        <button @click="$dispatch('open-modal', 'add-domain')"
            class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition duration-200">
            <i class="fas fa-plus mr-2"></i> Add Domain
        </button>
    </div>

    <!-- Domain List -->
    <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden border border-gray-100 dark:border-gray-700">
        <table class="w-full text-left border-collapse">
            <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                    <th class="px-6 py-4 font-semibold">Domain</th>
                    <th class="px-6 py-4 font-semibold">PHP Version</th>
                    <th class="px-6 py-4 font-semibold">SSL</th>
                    <th class="px-6 py-4 font-semibold">Status</th>
                    <th class="px-6 py-4 font-semibold text-right">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                @forelse($domains as $domain)
                    <tr>
                        <td class="px-6 py-4">
                            <div class="font-medium">{{ $domain->domain_name }}</div>
                            <div class="text-sm text-gray-500">{{ $domain->document_root }}</div>
                        </td>
                        <td class="px-6 py-4">
                            <span class="bg-blue-100 text-blue-700 px-2 py-1 rounded text-xs">PHP
                                {{ $domain->php_version }}</span>
                        </td>
                        <td class="px-6 py-4">
                            @if($domain->has_ssl)
                                <span class="text-green-500"><i class="fas fa-check-circle mr-1"></i> Active</span>
                            @else
                                <form action="{{ route('domains.ssl', $domain->id) }}" method="POST">
                                    @csrf
                                    <button class="text-indigo-600 hover:underline text-sm font-medium">Issue SSL</button>
                                </form>
                            @endif
                        </td>
                        <td class="px-6 py-4">
                            <span
                                class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium {{ $domain->status == 'active' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800' }}">
                                {{ ucfirst($domain->status) }}
                            </span>
                        </td>
                        <td class="px-6 py-4 text-right">
                            <button class="text-gray-400 hover:text-red-500 transition duration-150">
                                <i class="fas fa-trash"></i>
                            </button>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="5" class="px-6 py-12 text-center text-gray-500">
                            <div class="mb-4 text-4xl"><i class="fas fa-globe"></i></div>
                            <div>No domains found. Add your first domain to get started.</div>
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <!-- Add Domain Modal (Mockup with Alpine.js) -->
    <div x-data="{ open: false }" @open-modal.window="if($event.detail == 'add-domain') open = true" x-show="open"
        class="fixed inset-0 z-50 overflow-y-auto" style="display: none;">
        <div class="flex items-center justify-center min-h-screen px-4">
            <div class="fixed inset-0 bg-black opacity-50"></div>
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-xl w-full max-w-md relative z-10 overflow-hidden">
                <div class="p-6 border-b border-gray-100 dark:border-gray-700">
                    <h3 class="text-xl font-bold">Add New Domain</h3>
                </div>
                <form action="{{ route('domains.store') }}" method="POST" class="p-6">
                    @csrf
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Domain Name</label>
                        <input type="text" name="domain_name" placeholder="example.com"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 outline-none transition transition-all duration-200"
                            required>
                    </div>
                    <div class="mb-6">
                        <label class="block text-sm font-medium mb-1">PHP Version</label>
                        <select name="php_version"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 outline-none transition transition-all duration-200">
                            <option value="8.1">PHP 8.1 (Default)</option>
                            <option value="8.2">PHP 8.2</option>
                            <option value="8.0">PHP 8.0</option>
                            <option value="7.4">PHP 7.4</option>
                        </select>
                    </div>
                    <div class="flex justify-end gap-3">
                        <button type="button" @click="open = false"
                            class="px-4 py-2 text-gray-500 hover:text-gray-700 font-medium">Cancel</button>
                        <button type="submit"
                            class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2 rounded-lg font-bold transition duration-200">Create
                            Domain</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
@endsection