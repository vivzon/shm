<?php

namespace App\Modules\Client\Controllers;

use App\Core\Controller;
use App\Core\Database;
use App\Modules\Client\Models\Domain;

class EmailsController extends Controller
{
    public function index()
    {
        if (!isset($_SESSION['cid']))
            $this->redirect('/login');

        $clientId = $_SESSION['cid'];
        $page = isset($_GET['page']) ? (int) $_GET['page'] : 1;
        $perPage = 10;
        $offset = ($page - 1) * $perPage;

        // Models logic inline or separate? Separating is cleaner but keeping simple here.
        // Counts
        $countSql = "SELECT COUNT(*) FROM mail_users mu JOIN mail_domains md ON mu.domain_id = md.id WHERE md.domain IN (SELECT domain FROM domains WHERE client_id = ?)";
        $total = Database::fetch($countSql, [$clientId])['COUNT(*)'] ?? 0; // fetch returns assoc, so key might be needed or fetchVal
        // Correction: fetch returns row. fetchColumn better.
        $total = Database::pdo()->prepare($countSql);
        $total->execute([$clientId]);
        $total = $total->fetchColumn();

        $totalPages = ceil($total / $perPage);

        $sql = "SELECT mu.* FROM mail_users mu JOIN mail_domains md ON mu.domain_id = md.id WHERE md.domain IN (SELECT domain FROM domains WHERE client_id = ?) LIMIT $perPage OFFSET $offset";
        $emails = Database::fetchAll($sql, [$clientId]);

        $domains = Domain::getAll($clientId);

        // Base domain
        $host = $_SERVER['HTTP_HOST'];
        $parts = explode('.', $host);
        $baseDomain = (count($parts) >= 2) ? implode('.', array_slice($parts, -2)) : $host;

        $this->view('Client::emails/index', [
            'emails' => $emails,
            'domains' => $domains,
            'total' => $total,
            'totalPages' => $totalPages,
            'currentPage' => $page,
            'baseDomain' => $baseDomain
        ]);
    }

    public function action()
    {
        if (!isset($_SESSION['cid']))
            $this->json(['status' => 'error', 'msg' => 'Unauthorized'], 403);
        $clientId = $_SESSION['cid'];
        $action = $this->input('ajax_action');

        try {
            if ($action == 'add_email') {
                $this->addEmail($clientId);
            } elseif ($action == 'delete_email') {
                $this->deleteEmail($clientId);
            } elseif ($action == 'reset_mail_pass') {
                $this->resetPass($clientId);
            }
        } catch (\Exception $e) {
            $this->json(['status' => 'error', 'msg' => $e->getMessage()]);
        }
    }

    private function addEmail($clientId)
    {
        $limits = Database::fetch("SELECT p.max_emails FROM clients c JOIN packages p ON c.package_id = p.id WHERE c.id = ?", [$clientId]);
        // Count existing
        $curr = Database::pdo()->prepare("SELECT COUNT(*) FROM mail_users WHERE domain_id IN (SELECT id FROM mail_domains WHERE domain IN (SELECT domain FROM domains WHERE client_id = ?))");
        $curr->execute([$clientId]);
        if ($curr->fetchColumn() >= $limits['max_emails'])
            throw new \Exception("Email limit reached.");

        $domain = $this->input('domain');
        $user = $this->input('user');
        $pass = $this->input('pass');

        // Get Domain ID in mail_domains, create if needed (legacy logic)
        $msgDomain = Database::fetch("SELECT id FROM mail_domains WHERE domain = ?", [$domain]);
        if ($msgDomain) {
            $did = $msgDomain['id'];
        } else {
            // Verify domain belongs to client first!
            $dCheck = Database::fetch("SELECT id FROM domains WHERE domain = ? AND client_id = ?", [$domain, $clientId]);
            if (!$dCheck)
                throw new \Exception("Invalid Domain");

            Database::query("INSERT INTO mail_domains (domain) VALUES (?)", [$domain]);
            $did = Database::pdo()->lastInsertId();
        }

        Database::query(
            "INSERT INTO mail_users (domain_id, email, password) VALUES (?, ?, ?)",
            [$did, $user . "@" . $domain, password_hash($pass, PASSWORD_BCRYPT)]
        );

        $this->json(['status' => 'success', 'msg' => 'Email Created']);
    }

    private function deleteEmail($clientId)
    {
        $email = $this->input('email');
        // Ownership check
        $check = Database::fetch("SELECT m.id FROM mail_users m JOIN mail_domains md ON m.domain_id = md.id JOIN domains d ON md.domain = d.domain WHERE m.email = ? AND d.client_id = ?", [$email, $clientId]);
        if (!$check)
            throw new \Exception("Access Denied");

        Database::query("DELETE FROM mail_users WHERE email = ?", [$email]);
        $this->json(['status' => 'success', 'msg' => 'Email Deleted']);
    }

    private function resetPass($clientId)
    {
        $email = $this->input('email');
        $pass = $this->input('new_pass');

        $check = Database::fetch("SELECT m.id FROM mail_users m JOIN mail_domains md ON m.domain_id = md.id JOIN domains d ON md.domain = d.domain WHERE m.email = ? AND d.client_id = ?", [$email, $clientId]);
        if (!$check)
            throw new \Exception("Access Denied");

        Database::query("UPDATE mail_users SET password = ? WHERE email = ?", [password_hash($pass, PASSWORD_BCRYPT), $email]);
        $this->json(['status' => 'success', 'msg' => 'Password Reset']);
    }
}
