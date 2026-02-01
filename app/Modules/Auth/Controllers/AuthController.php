<?php

namespace App\Modules\Auth\Controllers;

use App\Core\Controller;
use App\Modules\Auth\Models\User;

class AuthController extends Controller
{
    // CLIENT ACTIONS

    public function login()
    {
        if (isset($_SESSION['client'])) {
            $this->redirect('/dashboard'); // Client Dashboard
        }
        $this->view('Auth::login_client');
    }

    public function authenticate()
    {
        $u = $this->input('u');
        $p = $this->input('p');

        if (!$u || !$p) {
            $this->view('Auth::login_client', ['error' => 'Please fill in all fields.']);
            return;
        }

        $user = User::find($u);

        if ($user && password_verify($p, $user['password'])) {
            if (isset($user['status']) && $user['status'] === 'suspended') {
                $this->view('Auth::login_client', ['error' => 'Account suspended.']);
                return;
            }

            session_regenerate_id(true);

            // Set session based on role
            $_SESSION['user_id'] = $user['id'];
            $_SESSION['username'] = $user['username'];
            $_SESSION['role'] = $user['role'];

            // Role-based Redirect
            if (in_array($user['role'], ['super_admin', 'admin'])) {
                $_SESSION['admin'] = $user['username']; // Legacy support
                $this->redirect('/admin/dashboard');
            } elseif ($user['role'] === 'reseller') {
                $_SESSION['reseller'] = $user['username'];
                $_SESSION['cid'] = $user['id']; // Resellers act as clients too usually
                $this->redirect('/reseller/dashboard');
            } else {
                $_SESSION['client'] = $user['username']; // Legacy support
                $_SESSION['cid'] = $user['id'];
                $this->redirect('/dashboard');
            }
        } else {
            // Log Attempt (Optional: call Model)
            $this->view('Auth::login_client', ['error' => 'Invalid credentials.']);
        }
    }

    public function logout()
    {
        unset($_SESSION['client']);
        unset($_SESSION['cid']);
        // Destroy session fully? using logic from logout.php
        $this->redirect('/login');
    }

    // ADMIN ACTIONS

    public function adminLogin()
    {
        if (isset($_SESSION['admin'])) {
            $this->redirect('/admin/dashboard');
        }
        $this->view('Auth::login_admin');
    }

    public function adminAuthenticate()
    {
        $u = $this->input('u');
        $p = $this->input('p');

        $user = User::find($u);

        if ($user && password_verify($p, $user['password'])) {
            // Strictly check role for Admin Login page
            if (!in_array($user['role'], ['super_admin', 'admin'])) {
                $this->view('Auth::login_admin', ['error' => 'Access Denied']);
                return;
            }

            $_SESSION['admin'] = $user['username'];
            $_SESSION['user_id'] = $user['id'];
            $_SESSION['role'] = $user['role'];

            $this->redirect('/admin/dashboard');
        } else {
            $this->view('Auth::login_admin', ['error' => 'Invalid credentials']);
        }
    }

    public function adminLogout()
    {
        unset($_SESSION['admin']);
        $this->redirect('/admin/login');
    }
}
