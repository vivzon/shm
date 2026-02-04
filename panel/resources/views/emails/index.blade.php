@extends('layouts.app')

@section('title', 'Email Management')

@section('content')
    <div class="flex justify-between items-center mb-8">
        <h2 class="text-3xl font-bold">Email Accounts</h2>
        <button @click="$dispatch('open-modal', 'add-email')"
            class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg transition duration-200">
            <i class="fas fa-plus mr-2"></i> Create Email
        </button>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden border border-gray-100 dark:border-gray-700">
        <table class="w-full text-left border-collapse">
            <thead class="bg-gray-50 dark:bg-gray-700">
                <tr>
                    <th class="px-6 py-4 font-semibold">Email Address</th>
                    <th class="px-6 py-4 font-semibold">Domain</th>
                    <th class="px-6 py-4 font-semibold">Quota</th>
                    <th class="px-6 py-4 font-semibold text-right">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                @forelse($emails as $email)
                    <tr>
                        <td class="px-6 py-4 font-medium">{{ $email->email_address }}</td>
                        <td class="px-6 py-4">{{ $email->domain->domain_name }}</td>
                        <td class="px-6 py-4">{{ $email->quota }} MB</td>
                        <td class="px-6 py-4 text-right">
                            <button class="text-indigo-600 hover:text-indigo-800 mr-4 font-medium">Change Password</button>
                            <button class="text-red-500 hover:text-red-700 transition duration-150">
                                <i class="fas fa-trash"></i>
                            </button>
                        </td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="4" class="px-6 py-12 text-center text-gray-500">
                            <div class="mb-4 text-4xl"><i class="fas fa-envelope"></i></div>
                            <div>No email accounts found. Create your first one to get started.</div>
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

    <!-- Create Email Modal -->
    <div x-data="{ open: false }" @open-modal.window="if($event.detail == 'add-email') open = true" x-show="open"
        class="fixed inset-0 z-50 overflow-y-auto" style="display: none;">
        <div class="flex items-center justify-center min-h-screen px-4">
            <div class="fixed inset-0 bg-black opacity-50"></div>
            <div class="bg-white dark:bg-gray-800 rounded-xl shadow-xl w-full max-w-md relative z-10 overflow-hidden">
                <div class="p-6 border-b border-gray-100 dark:border-gray-700">
                    <h3 class="text-xl font-bold">New Email Account</h3>
                </div>
                <form action="{{ route('emails.store') }}" method="POST" class="p-6">
                    @csrf
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Domain</label>
                        <select name="domain_id"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 outline-none transition-all">
                            @foreach($domains as $domain)
                                <option value="{{ $domain->id }}">{{ $domain->domain_name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Username</label>
                        <div class="flex items-center">
                            <input type="text" name="email_user" placeholder="info"
                                class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 outline-none transition-all"
                                required>
                        </div>
                    </div>
                    <div class="mb-4">
                        <label class="block text-sm font-medium mb-1">Password</label>
                        <input type="password" name="password"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 outline-none transition-all"
                            required>
                    </div>
                    <div class="mb-6">
                        <label class="block text-sm font-medium mb-1">Quota (MB)</label>
                        <input type="number" name="quota" value="250"
                            class="w-full bg-gray-50 dark:bg-gray-700 border border-gray-200 dark:border-gray-600 rounded-lg px-4 py-2 focus:ring-2 focus:ring-indigo-500 outline-none transition-all"
                            required>
                    </div>
                    <div class="flex justify-end gap-3">
                        <button type="button" @click="open = false"
                            class="px-4 py-2 text-gray-500 hover:text-gray-700">Cancel</button>
                        <button type="submit"
                            class="bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2 rounded-lg font-bold transition-all">Create
                            Account</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
@endsection