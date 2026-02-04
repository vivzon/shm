@extends('layouts.app')

@section('title', 'Cron Job Manager')

@section('content')
    <div class="mb-8">
        <h2 class="text-3xl font-bold">Cron Job Manager</h2>
        <p class="text-gray-500">Schedule tasks to run automatically at specific intervals.</p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <!-- List Jobs -->
        <div class="lg:col-span-2">
            <div
                class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 overflow-hidden">
                <div class="p-6 border-b border-gray-100 dark:border-gray-700">
                    <h3 class="font-bold">Active Cron Jobs</h3>
                </div>
                <table class="w-full text-left border-collapse">
                    <thead class="bg-gray-50 dark:bg-gray-700">
                        <tr>
                            <th class="px-6 py-4 font-semibold w-16">#</th>
                            <th class="px-6 py-4 font-semibold">Job Definition</th>
                            <th class="px-6 py-4 font-semibold text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                        @forelse($cronJobs as $job)
                            <tr class="hover:bg-gray-50 dark:hover:bg-gray-750">
                                <td class="px-6 py-4 text-sm text-gray-500">{{ $job['line_num'] }}</td>
                                <td class="px-6 py-4 font-mono text-sm">{{ $job['content'] }}</td>
                                <td class="px-6 py-4 text-right">
                                    <form action="{{ route('cron.destroy', $job['line_num']) }}" method="POST" class="inline"
                                        onsubmit="return confirm('Remove this cron job?')">
                                        @csrf @method('DELETE')
                                        <button class="text-red-500 hover:text-red-700"><i class="fas fa-trash"></i></button>
                                    </form>
                                </td>
                            </tr>
                        @empty
                            <tr>
                                <td colspan="3" class="px-6 py-12 text-center text-gray-500">
                                    No cron jobs scheduled.
                                </td>
                            </tr>
                        @endforelse
                    </tbody>
                </table>
            </div>
        </div>

        <!-- Add Job -->
        <div>
            <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700">
                <h3 class="text-xl font-bold mb-6">Add New Job</h3>
                <form action="{{ route('cron.store') }}" method="POST">
                    @csrf
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Common Settings</label>
                        <select
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 outline-none"
                            onchange="document.getElementById('schedule').value = this.value">
                            <option value="">-- Settings --</option>
                            <option value="* * * * *">Every Minute (* * * * *)</option>
                            <option value="0 * * * *">Every Hour (0 * * * *)</option>
                            <option value="0 0 * * *">Twice a Day (0 0 * * *)</option>
                            <option value="0 0 0 * *">Once a Day (0 0 0 * *)</option>
                            <option value="0 0 0 0 *">Once a Week (0 0 0 0 *)</option>
                        </select>
                    </div>
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Schedule (Cron Syntax)</label>
                        <input type="text" id="schedule" name="schedule" placeholder="* * * * *"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 outline-none"
                            required>
                    </div>
                    <div class="mb-6">
                        <label class="block text-sm font-medium mb-1">Command</label>
                        <textarea name="command" rows="3"
                            placeholder="/usr/bin/php /home/user/public_html/artisan schedule:run"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 outline-none"
                            required></textarea>
                    </div>
                    <button type="submit"
                        class="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded-lg transition duration-200">
                        Add Cron Job
                    </button>
                </form>
            </div>
        </div>
    </div>
@endsection