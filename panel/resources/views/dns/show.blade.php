@extends('layouts.app')

@section('title', 'Manage DNS: ' . $domain->domain_name)

@section('content')
    <div class="mb-8 flex items-center">
        <a href="{{ route('dns.index') }}" class="mr-4 text-gray-500 hover:text-indigo-600 transition duration-150">
            <i class="fas fa-arrow-left"></i>
        </a>
        <h2 class="text-3xl font-bold">DNS Records: {{ $domain->domain_name }}</h2>
    </div>

    <div
        class="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden border border-gray-100 dark:border-gray-700 mb-8">
        <div class="p-6 border-b border-gray-100 dark:border-gray-700 flex justify-between items-center">
            <h3 class="font-bold">Zone Records</h3>
            <button @click="$dispatch('open-modal', 'add-record')"
                class="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1.5 rounded-lg text-sm font-bold transition duration-200">
                <i class="fas fa-plus mr-2"></i> Add Record
            </button>
        </div>
        <table class="w-full text-left border-collapse">
            <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                    <th class="px-6 py-4 font-semibold">Type</th>
                    <th class="px-6 py-4 font-semibold">Name</th>
                    <th class="px-6 py-4 font-semibold">Content</th>
                    <th class="px-6 py-4 font-semibold">TTL</th>
                    <th class="px-6 py-4 font-semibold text-right">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                @forelse($records as $record)
                    <tr>
                        <td class="px-6 py-4">
                            <span
                                class="bg-blue-100 text-blue-700 px-2 py-0.5 rounded text-xs font-bold">{{ $record->type }}</span>
                        </td>
                        <td class="px-6 py-4 text-sm">{{ $record->name }}</td>
                        <td class="px-6 py-4 text-sm font-mono truncate max-w-xs">{{ $record->content }}</td>
                        <td class="px-6 py-4 text-sm text-gray-500">{{ $record->ttl }}</td>
                        <td class="px-6 py-4 text-right">
                            <button class="text-red-500 hover:text-red-700 transition duration-150">
                                <i class="fas fa-trash"></i>
                            </button>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="5" class="px-6 py-12 text-center text-gray-500">
                            No custom DNS records found for this domain.
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <!-- Add Record Modal -->
    <div x-data="{ open: false }" @open-modal.window="if($event.detail == 'add-record') open = true" x-show="open"
        class="fixed inset-0 z-50 overflow-y-auto" style="display: none;">
        <div class="flex items-center justify-center min-h-screen px-4">
            <div class="fixed inset-0 bg-black opacity-50"></div>
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-xl w-full max-w-md relative z-10 overflow-hidden">
                <div class="p-6 border-b border-gray-100 dark:border-gray-700">
                    <h3 class="text-xl font-bold">Add DNS Record</h3>
                </div>
                <form action="{{ route('dns.store', $domain->id) }}" method="POST" class="p-6">
                    @csrf
                    <div class="grid grid-cols-2 gap-4 mb-4">
                        <div>
                            <label class="block text-sm font-medium mb-1">Type</label>
                            <select name="type"
                                class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-3 py-2 outline-none">
                                <option value="A">A</option>
                                <option value="AAAA">AAAA</option>
                                <option value="CNAME">CNAME</option>
                                <option value="MX">MX</option>
                                <option value="TXT">TXT</option>
                                <option value="SRV">SRV</option>
                            </select>
                        </div>
                        <div>
                            <label class="block text-sm font-medium mb-1">TTL</label>
                            <input type="number" name="ttl" value="3600"
                                class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-3 py-2 outline-none">
                        </div>
                    </div>
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Name (Host)</label>
                        <div class="flex items-center">
                            <input type="text" name="name" placeholder="www"
                                class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 outline-none">
                            <span class="ml-2 text-gray-400">.{{ $domain->domain_name }}</span>
                        </div>
                    </div>
                    <div class="mb-6">
                        <label class="block text-sm font-medium mb-1">Content (Value)</label>
                        <input type="text" name="content" placeholder="127.0.0.1"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 outline-none"
                            required>
                    </div>
                    <div class="flex justify-end gap-3">
                        <button type="button" @click="open = false"
                            class="px-4 py-2 text-gray-500 hover:text-gray-700">Cancel</button>
                        <button type="submit"
                            class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2 rounded-lg font-bold transition-all">Add
                            Record</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
@endsection