@extends('layouts.app')

@section('title', 'Dashboard')

@section('content')
    <div class="mb-8">
        <h2 class="text-3xl font-bold">Welcome back, {{ Auth::user()->name ?? 'Admin' }}!</h2>
        <p class="text-gray-500">Here's what's happening with your server today.</p>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700">
            <div class="flex items-center text-indigo-600 mb-4">
                <i class="fas fa-globe text-2xl"></i>
                <span class="ml-auto text-sm font-semibold text-gray-400">Domains</span>
            </div>
            <div class="text-3xl font-bold">{{ $stats['domains_count'] }}</div>
        </div>
        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700">
            <div class="flex items-center text-green-600 mb-4">
                <i class="fas fa-database text-2xl"></i>
                <span class="ml-auto text-sm font-semibold text-gray-400">Databases</span>
            </div>
            <div class="text-3xl font-bold">{{ $stats['databases_count'] }}</div>
        </div>
        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700">
            <div class="flex items-center text-blue-600 mb-4">
                <i class="fas fa-envelope text-2xl"></i>
                <span class="ml-auto text-sm font-semibold text-gray-400">Emails</span>
            </div>
            <div class="text-3xl font-bold">{{ $stats['emails_count'] }}</div>
        </div>
        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700">
            <div class="flex items-center text-yellow-600 mb-4">
                <i class="fas fa-hdd text-2xl"></i>
                <span class="ml-auto text-sm font-semibold text-gray-400">Disk Usage</span>
            </div>
            <div class="text-3xl font-bold">{{ $stats['disk_usage'] }} <span class="text-sm font-normal text-gray-500">/
                    {{ $stats['disk_quota'] }} MB</span></div>
        </div>
    </div>

    <!-- Resource Monitoring -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div
            class="lg:col-span-2 bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700">
            <h3 class="text-xl font-bold mb-6">Server Resources</h3>

            <div class="space-y-6">
                <div>
                    <div class="flex justify-between mb-2">
                        <span class="text-sm font-medium">CPU Usage</span>
                        <span class="text-sm font-medium">{{ $serverHealth['cpu_load'] }}%</span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div class="bg-indigo-600 h-2 rounded-full" style="width: {{ $serverHealth['cpu_load'] }}%"></div>
                    </div>
                </div>

                <div>
                    <div class="flex justify-between mb-2">
                        <span class="text-sm font-medium">RAM Usage</span>
                        <span class="text-sm font-medium">{{ $serverHealth['ram_usage'] }}%</span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div class="bg-green-500 h-2 rounded-full" style="width: {{ $serverHealth['ram_usage'] }}%"></div>
                    </div>
                </div>

                <div>
                    <div class="flex justify-between mb-2">
                        <span class="text-sm font-medium">System Disk</span>
                        <span class="text-sm font-medium">{{ $serverHealth['disk_usage'] }}%</span>
                    </div>
                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                        <div class="bg-yellow-500 h-2 rounded-full" style="width: {{ $serverHealth['disk_usage'] }}%"></div>
                    </div>
                </div>
            </div>
        </div>

        <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700">
            <h3 class="text-xl font-bold mb-6">Service Health</h3>
            <div class="space-y-4">
                <div class="flex items-center justify-between">
                    <span class="flex items-center"><i class="fas fa-circle text-green-500 text-[10px] mr-3"></i>
                        Nginx</span>
                    <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded">Running</span>
                </div>
                <div class="flex items-center justify-between">
                    <span class="flex items-center"><i class="fas fa-circle text-green-500 text-[10px] mr-3"></i>
                        MySQL</span>
                    <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded">Running</span>
                </div>
                <div class="flex items-center justify-between">
                    <span class="flex items-center"><i class="fas fa-circle text-green-500 text-[10px] mr-3"></i>
                        PHP-FPM</span>
                    <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded">Running</span>
                </div>
                <div class="flex items-center justify-between">
                    <span class="flex items-center"><i class="fas fa-circle text-red-500 text-[10px] mr-3"></i>
                        Postfix</span>
                    <span class="text-xs bg-red-100 text-red-800 px-2 py-1 rounded">Stopped</span>
                </div>
            </div>

            <div class="mt-8 p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
                <div class="text-sm text-gray-500 mb-1">System Uptime</div>
                <div class="font-bold">{{ $serverHealth['uptime'] }}</div>
            </div>
        </div>
    </div>
@endsection