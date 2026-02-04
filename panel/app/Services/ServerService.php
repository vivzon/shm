<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Symfony\Component\Process\Process;

class ServerService
{
    /**
     * Execute a command via shm-manage
     */
    public function execute($command, array $args = [])
    {
        $commandArray = array_merge(['sudo', '/usr/local/bin/shm-manage', $command], $args);

        $process = new Process($commandArray);
        $process->run();

        if (!$process->isSuccessful()) {
            Log::error("SHM Command Failed: " . $process->getErrorOutput());
            throw new \Exception("Server error: " . $process->getErrorOutput());
        }

        return $process->getOutput();
    }

    public function createUser($username, $password, $email)
    {
        return $this->execute('user-create', [$username, $password, $email]);
    }

    public function createSite($username, $domain, $phpVersion = '8.1')
    {
        return $this->execute('site-create', [$username, $domain, $phpVersion]);
    }

    public function createDatabase($dbName, $dbUser, $dbPass)
    {
        return $this->execute('db-create', [$dbName, $dbUser, $dbPass]);
    }

    public function issueSsl($domain)
    {
        return $this->execute('ssl-issue', [$domain]);
    }
}
