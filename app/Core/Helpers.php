<?php

/**
 * Global Helper Functions
 */

if (!function_exists('cmd')) {
    function cmd($command)
    {
        // Windows Safety Check
        if (strtoupper(substr(PHP_OS, 0, 3)) === 'WIN') {
            return "Command '$command' simulated on Windows.";
        }

        // Production Linux Execution
        $output = shell_exec("sudo /usr/local/bin/shm-manage " . $command);
        // Note: The above line presumes shm-manage is symlinked to /usr/local/bin
        // Since we moved the source to scripts/shm-manage, we should ensure the symlink is updated during deployment/install
        // For now, we keep the global command or use absolute path if needed.
        // Let's assume the install script handles the symlinking.
        return trim($output);
    }
}

function response($data, $status = 200)
{
    http_response_code($status);
    header('Content-Type: application/json');
    echo json_encode($data);
    exit;
}

/**
 * Branding Helper
 * Automatically derives branding from the domain name if not explicitly set.
 */
if (!function_exists('get_branding')) {
    function get_branding()
    {
        global $brand_name;
        if (isset($brand_name)) {
            return $brand_name;
        }

        // Default branding
        $brand = "SHM Provider";

        if (isset($_SERVER['HTTP_HOST'])) {
            $host = $_SERVER['HTTP_HOST'];

            // If it's an IP address, use generic
            if (filter_var($host, FILTER_VALIDATE_IP)) {
                return "SHM Panel";
            }

            // Extract domain parts
            $parts = explode('.', $host);

            // Handle subdomains like panel.example.com -> Example
            // or vivzon.cloud -> Vivzon

            // If we have at least 2 parts (domain.com)
            if (count($parts) >= 2) {
                // Common TLDs handling might be complex, so let's try a simple approach:
                // Take the SLD which is usually immediately before the TLD.
                $sld = $parts[count($parts) - 2];
                $brand = ucfirst($sld);
            }
        }

        return $brand;
    }
}
