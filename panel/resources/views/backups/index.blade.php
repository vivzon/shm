@extends('layouts.app')

@section('title', 'Backups')

@section('content')
    <div class="flex justify-between items-center mb-8">
        <h2 class="text-3xl font-bold">Account Backups</h2>
        <form action="{{ route('backups.store') }}" method="POST">
            @csrf
            <button type="submit"
                class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition duration-200">
                <i class="fas fa-plus mr-2"></i> Generate Backup
            </button>
        </form>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden border border-gray-100 dark:border-gray-700">
        <table class="w-full text-left border-collapse">
            <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                    <th class="px-6 py-4 font-semibold">Filename</th>
                    <th class="px-6 py-4 font-semibold">Size</th>
                    <th class="px-6 py-4 font-semibold">Created At</th>
                    <th class="px-6 py-4 font-semibold text-right">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                @forelse($backups as $backup)
                    <tr>
                        <td class="px-6 py-4 font-medium">{{ $backup['filename'] }}</td>
                        <td class="px-6 py-4 text-sm text-gray-500">{{ $backup['size'] }}</td>
                        <td class="px-6 py-4 text-sm text-gray-500">{{ $backup['date'] }}</td>
                        <td class="px-6 py-4 text-right">
                            <a href="{{ route('backups.download', $backup['filename']) }}"
                                class="text-indigo-600 hover:text-indigo-800 mr-4 font-medium">
                                <i class="fas fa-download"></i> Download
                            </a>
                            <button class="text-red-500 hover:text-red-700 transition duration-150">
                                <i class="fas fa-trash"></i>
                            </button>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="4" class="px-6 py-12 text-center text-gray-500">
                            <div class="mb-4 text-4xl"><i class="fas fa-archive"></i></div>
                            <div>No backups found. Generate one to keep your data safe.</div>
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <div class="mt-8 p-6 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-100 dark:border-yellow-900 rounded-xl">
        <div class="flex">
            <div class="flex-shrink-0">
                <i class="fas fa-info-circle text-yellow-600"></i>
            </div>
            <div class="ml-3">
                <h3 class="text-sm font-bold text-yellow-800 dark:text-yellow-400">Backup Information</h3>
                <div class="mt-2 text-sm text-yellow-700 dark:text-yellow-300">
                    <p>Backups include your website files (public_html) and all associated MySQL databases. Backups are
                        stored locally on the server by default. We recommend downloading them for off-site storage.</p>
                </div>
            </div>
        </div>
    </div>
@endsection