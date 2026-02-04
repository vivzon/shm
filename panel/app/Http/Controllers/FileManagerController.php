<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\File;
use Symfony\Component\HttpFoundation\Response;

class FileManagerController extends Controller
{
    /**
     * Get the base directory for the current user.
     */
    protected function getBaseDir()
    {
        $user = Auth::user();
        $path = "/home/{$user->name}/public_html";

        // Ensure path exists for local testing if not on server
        if (!File::exists($path)) {
            // fallback for dev environment simulation
            $path = storage_path("app/public/simulated_home/{$user->name}");
            if (!File::exists($path))
                File::makeDirectory($path, 0755, true);
        }

        return realpath($path);
    }

    public function index(Request $request)
    {
        $baseDir = $this->getBaseDir();
        $currentPath = $request->get('path', '');

        $targetDir = realpath($baseDir . '/' . $currentPath);

        // Security: Prevent directory traversal
        if ($targetDir === false || strpos($targetDir, $baseDir) !== 0) {
            $targetDir = $baseDir;
            $currentPath = '';
        }

        $directories = [];
        $files = [];

        foreach (File::directories($targetDir) as $dir) {
            $directories[] = [
                'name' => basename($dir),
                'path' => str_replace($baseDir, '', str_replace('\\', '/', $dir)),
                'type' => 'directory',
                'size' => '-',
                'modified' => date('Y-m-d H:i:s', File::lastModified($dir))
            ];
        }

        foreach (File::files($targetDir) as $file) {
            $files[] = [
                'name' => $file->getFilename(),
                'path' => str_replace($baseDir, '', str_replace('\\', '/', $file->getRealPath())),
                'type' => 'file',
                'extension' => $file->getExtension(),
                'size' => number_format($file->getSize() / 1024, 2) . ' KB',
                'modified' => date('Y-m-d H:i:s', $file->getMTime())
            ];
        }

        return view('filemanager.index', [
            'directories' => $directories,
            'files' => $files,
            'currentPath' => trim($currentPath, '/'),
            'parentPath' => $currentPath ? dirname($currentPath) : null
        ]);
    }

    public function upload(Request $request)
    {
        $request->validate([
            'files.*' => 'required|file',
            'path' => 'nullable|string'
        ]);

        $baseDir = $this->getBaseDir();
        $targetDir = $baseDir . '/' . trim($request->get('path', ''), '/');

        if (strpos(realpath($targetDir), $baseDir) !== 0) {
            return redirect()->back()->with('error', 'Invalid upload path.');
        }

        foreach ($request->file('files') as $file) {
            $file->move($targetDir, $file->getClientOriginalName());
        }

        return redirect()->back()->with('success', 'Files uploaded successfully!');
    }

    public function delete(Request $request)
    {
        $baseDir = $this->getBaseDir();
        $path = trim($request->get('path'), '/');
        $fullPath = $baseDir . '/' . $path;

        if (strpos(realpath($fullPath), $baseDir) !== 0) {
            return redirect()->back()->with('error', 'Security Violation.');
        }

        if (File::isDirectory($fullPath)) {
            File::deleteDirectory($fullPath);
        } else {
            File::delete($fullPath);
        }

        return redirect()->back()->with('success', 'Deleted successfully.');
    }
}
