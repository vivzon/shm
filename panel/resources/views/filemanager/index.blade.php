@extends('layouts.app')

@section('title', 'File Manager')

@section('content')
    <div class="mb-8 flex justify-between items-center">
        <div>
            <h2 class="text-3xl font-bold text-gray-800 dark:text-white">File Manager</h2>
            <p class="text-sm text-gray-500 mt-1">
                <i class="fas fa-folder-open mr-1"></i> /index{{ $currentPath ? '/' . $currentPath : '' }}
            </p>
        </div>
        <div class="flex gap-3">
            <form action="{{ route('filemanager.upload') }}" method="POST" enctype="multipart/form-data" class="inline">
                @csrf
                <input type="hidden" name="path" value="{{ $currentPath }}">
                <label
                    class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg cursor-pointer transition duration-200">
                    <i class="fas fa-upload mr-2"></i> Upload
                    <input type="file" name="files[]" multiple class="hidden" onchange="this.form.submit()">
                </label>
            </form>
        </div>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 overflow-hidden">
        <table class="w-full text-left border-collapse">
            <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                    <th class="px-6 py-4 font-semibold w-1/2">Name</th>
                    <th class="px-6 py-4 font-semibold">Size</th>
                    <th class="px-6 py-4 font-semibold">Last Modified</th>
                    <th class="px-6 py-4 font-semibold text-right">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                @if($parentPath !== null)
                    <tr class="hover:bg-gray-50 dark:hover:bg-gray-750 transition duration-150">
                        <td colspan="4" class="px-6 py-4">
                            <a href="{{ route('filemanager.index', ['path' => $parentPath == '.' ? '' : $parentPath]) }}"
                                class="flex items-center text-indigo-600 dark:text-indigo-400 font-bold">
                                <i class="fas fa-level-up-alt mr-3"></i> ..
                            </a>
                        </td>
                    </tr>
                @endif

                @foreach($directories as $dir)
                    <tr class="hover:bg-gray-50 dark:hover:bg-gray-750 transition duration-150">
                        <td class="px-6 py-4">
                            <a href="{{ route('filemanager.index', ['path' => trim($dir['path'], '/')]) }}"
                                class="flex items-center">
                                <i class="fas fa-folder text-yellow-400 mr-3 text-lg"></i>
                                <span class="font-medium text-gray-800 dark:text-gray-200">{{ $dir['name'] }}</span>
                            </a>
                        </td>
                        <td class="px-6 py-4 text-sm text-gray-500">{{ $dir['size'] }}</td>
                        <td class="px-6 py-4 text-sm text-gray-500">{{ $dir['modified'] }}</td>
                        <td class="px-6 py-4 text-right">
                            <form action="{{ route('filemanager.delete') }}" method="POST" class="inline"
                                onsubmit="return confirm('Truly delete this folder?')">
                                @csrf @method('DELETE')
                                <input type="hidden" name="path" value="{{ trim($dir['path'], '/') }}">
                                <button class="text-gray-400 hover:text-red-500"><i class="fas fa-trash"></i></button>
                            </form>
                        </td>
                    </tr>
                @endforeach

                @foreach($files as $file)
                    <tr class="hover:bg-gray-50 dark:hover:bg-gray-750 transition duration-150">
                        <td class="px-6 py-4">
                            <div class="flex items-center">
                                <i class="fas fa-file-code text-blue-400 mr-3 text-lg"></i>
                                <span class="text-gray-700 dark:text-gray-300">{{ $file['name'] }}</span>
                            </div>
                        </td>
                        <td class="px-6 py-4 text-sm text-gray-500">{{ $file['size'] }}</td>
                        <td class="px-6 py-4 text-sm text-gray-500">{{ $file['modified'] }}</td>
                        <td class="px-6 py-4 text-right">
                            <div class="flex justify-end gap-3 text-gray-400">
                                <a href="#" title="Download" class="hover:text-indigo-600"><i class="fas fa-download"></i></a>
                                <form action="{{ route('filemanager.delete') }}" method="POST" class="inline"
                                    onsubmit="return confirm('Delete this file?')">
                                    @csrf @method('DELETE')
                                    <input type="hidden" name="path" value="{{ trim($file['path'], '/') }}">
                                    <button class="hover:text-red-500"><i class="fas fa-trash"></i></button>
                                </form>
                            </div>
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>
@endsection