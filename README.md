# SHM Panel v6.0 (Next-Gen Hosting Control Panel)

> **The Professional Alternative to cPanel/WHM**
> Built for performance, security, and scalability. Now with Multi-Role Support (Admin, Reseller, Client) and a One-Click Auto Installer.



## 📖 Overview

**SHM Panel** is a modern, light-weight, and powerful hosting control panel designed for Ubuntu 20.04/22.04 and Debian 11/12 servers. It replaces the traditional heavy control panels with a sleek MVC-based interface and a robust Bash backend.

**Version 6.0** introduces a complete architectural overhaul:
- **MVC Architecture**: Clean separation of logic using a modular PHP framework.
- **Multi-Role System**: Native support for **Super Admin**, **Reseller**, and **Client** roles.
- **API-First Design**: Ready for WHMCS/Blesta integration.

---

## 🚀 Key Features

### 🏢 Multi-Role Management
- **Super Admin**: Full server control, manage all accounts, packages, and system settings.
- **Reseller**: Create and manage own sub-clients, overselling controls, and custom branding.
- **Client**: Manage domains, emails, databases, and files in a cPanel-like interface.

### ⚡ One-Click App Installer (Softaculous-like)
- **Installs in Seconds**: WordPress, Laravel, CodeIgniter 4, React (Vite).
- **Node.js Support**: Deploys Node apps with **PM2** and Nginx Reverse Proxy automatically.
- **Auto-Config**: Generates `wp-config.php`, `.env`, and Nginx VHosts automatically.

### 🔒 Enterprise Security
- **Isolation**: Each user runs in a dedicated Linux environment (CageFS-style isolation).
- **Hardened Kernel**: Sysctl tuning for high-traffic loads.
- **Active Protection**: Integrated Fail2Ban, ClamAV Malware Scanner, and CSRF protection.
- **SSL**: Automatic free Wildcard SSLs via Let's Encrypt.

### 🛠️ Developer Friendly
- **Versions**: Switchable PHP Versions (8.1, 8.2, 8.3).
- **Databases**: MariaDB 10.11 with phpMyAdmin (Secured).
- **Email**: Postfix/Dovecot with Roundcube Webmail, SPF, DKIM, and DMARC support.

---

## 💿 Installation (One-Click)

Reflash your VPS with **Ubuntu 20.04** or **22.04 LTS** and run the following command as `root`:

```bash
# Download and Install
cd /root
git clone https://github.com/vivzon/shm-panel.git
cd shm-panel
chmod +x scripts/install.sh

# Run Installer (Interactive)
./scripts/install.sh

# OR Run Non-Interactive (Auto Mode)
./scripts/install.sh --domain panel.example.com --email admin@example.com --yes
```

The installer will automatically:
1.  Install Nginx, PHP, MariaDB, Redis, Mail Stack.
2.  Deploy the MVC core and Backend Engine.
3.  Configure Firewalls, Swap, and Kernel Security.
4.  Generate Admin Credentials.

---

## 💻 Tech Stack

- **Frontend**: Blade-style Template Engine, TailwindCSS, Alpine.js.
- **Backend (Web)**: Custom PHP MVC Framework (Lightweight).
- **Backend (Core)**: Bash Scripts (`shm-manage`), Systemd Services.
- **Database**: MariaDB.
- **Cache**: Redis.

---

## 📂 Project Structure (V6)

```
shm-panel/
├── app/                    # Core Application Logic (MVC)
│   ├── Core/               # Framework Core (Router, DB, View)
│   ├── Modules/            # Modular Features
│   │   ├── Admin/          # Admin & Reseller Logic
│   │   ├── Client/         # Client Dashboard
│   │   └── Auth/           # Authentication System
├── public/                 # Web Entry Point (index.php)
├── scripts/                # Backend Automation Tools
│   ├── install.sh          # Primary VPS Installer
│   ├── shm-manage          # System Management CLI
│   ├── migrations/         # Database Schema Changes
│   └── installurs/         # One-Click App Installers
├── config/                 # Global Configuration
└── systemd/                # Service Definitions
```

---

## 🤝 Contributing

We welcome contributions! Please fork the repository and submit a Pull Request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

(c) 2026 SHM Panel. Built for the Community.
