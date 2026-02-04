<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SHM Panel - @yield('title')</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script defer src="https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js"></script>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        [x-cloak] {
            display: none !important;
        }
    </style>
</head>

<body class="bg-gray-100 dark:bg-gray-900 text-gray-800 dark:text-gray-200"
    x-data="{ sideBarOpen: true, darkMode: true }" :class="{ 'dark': darkMode }">
    <div class="flex h-screen overflow-hidden">
        <!-- Sidebar -->
        <aside class="bg-white dark:bg-gray-800 w-64 flex-shrink-0 transition-all duration-300"
            :class="{ '-ml-64': !sideBarOpen }">
            <div class="p-6">
                <h1 class="text-2xl font-bold text-indigo-600 dark:text-indigo-400">SHM Panel</h1>
            </div>
            <nav class="mt-6">
                <a href="{{ route('dashboard') }}"
                    class="flex items-center py-3 px-6 hover:bg-gray-100 dark:hover:bg-gray-700">
                    <i class="fas fa-home mr-3"></i> Dashboard
                </a>
                <a href="{{ route('domains.index') }}"
                    class="flex items-center py-3 px-6 hover:bg-gray-100 dark:hover:bg-gray-700">
                    <i class="fas fa-globe mr-3"></i> Domains
                </a>
                <a href="#" class="flex items-center py-3 px-6 hover:bg-gray-100 dark:hover:bg-gray-700">
                    <i class="fas fa-database mr-3"></i> Databases
                </a>
                <a href="#" class="flex items-center py-3 px-6 hover:bg-gray-100 dark:hover:bg-gray-700">
                    <i class="fas fa-envelope mr-3"></i> Email
                </a>
                <a href="#" class="flex items-center py-3 px-6 hover:bg-gray-100 dark:hover:bg-gray-700">
                    <i class="fas fa-file-alt mr-3"></i> File Manager
                </a>
            </nav>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 overflow-y-auto bg-gray-50 dark:bg-gray-900 transition-all duration-300">
            <!-- Header -->
            <header class="bg-white dark:bg-gray-800 shadow-sm px-6 py-4 flex justify-between items-center">
                <button @click="sideBarOpen = !sideBarOpen" class="text-gray-500 focus:outline-none">
                    <i class="fas fa-bars"></i>
                </button>
                <div class="flex items-center">
                    <button @click="darkMode = !darkMode" class="mr-4 text-gray-500">
                        <i :class="darkMode ? 'fas fa-sun' : 'fas fa-moon'"></i>
                    </button>
                    <div class="relative" x-data="{ open: false }">
                        <button @click="open = !open" class="flex items-center focus:outline-none">
                            <span class="mr-2">{{ Auth::user()->name ?? 'Admin' }}</span>
                            <i class="fas fa-chevron-down text-xs"></i>
                        </button>
                        <div x-show="open" @click.away="open = false"
                            class="absolute right-0 mt-2 w-48 bg-white dark:bg-gray-800 rounded-md shadow-lg py-2 z-20"
                            x-cloak>
                            <a href="#" class="block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700">Profile</a>
                            <a href="#" class="block px-4 py-2 hover:bg-gray-100 dark:hover:bg-gray-700">Logout</a>
                        </div>
                    </div>
                </div>
            </header>

            <!-- Page Content -->
            <div class="p-8">
                @if(session('success'))
                    <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">
                        {{ session('success') }}
                    </div>
                @endif
                @if(session('error'))
                    <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
                        {{ session('error') }}
                    </div>
                @endif

                @yield('content')
            </div>
        </main>
    </div>
</body>

</html>