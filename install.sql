-- SHM Panel Database Schema

SET FOREIGN_KEY_CHECKS=0;

-- Users table
CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('superadmin','admin','user') NOT NULL DEFAULT 'user',
  `plan_id` int DEFAULT NULL,
  `ssh_access_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_login` datetime DEFAULT NULL,
  `status` enum('active','inactive','suspended') NOT NULL DEFAULT 'active',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- Domains table
CREATE TABLE IF NOT EXISTS `domains` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `parent_id` int DEFAULT NULL,
  `domain_name` varchar(255) NOT NULL,
  `document_root` varchar(500) NOT NULL,
  `php_version` varchar(10) DEFAULT '7.4',
  `ssl_enabled` tinyint(1) DEFAULT '0',
  `ssl_cert` text,
  `ssl_key` text,
  `created_at` datetime NOT NULL,
  `expiry_date` date DEFAULT NULL
  `status` enum('active','suspended','pending') NOT NULL DEFAULT 'active',
  PRIMARY KEY (`id`),
  UNIQUE KEY `domain_name` (`domain_name`),
  KEY `user_id` (`user_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `domain_aliases`
--

CREATE TABLE IF NOT EXISTS `domain_aliases` (
  `id` int NOT NULL,
  `domain_id` int NOT NULL,
  `alias_name` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `domain_redirects`
--

CREATE TABLE IF NOT EXISTS `domain_redirects` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `source_domain` varchar(255) NOT NULL,
  `destination_url` text NOT NULL,
  `redirect_type` int NOT NULL DEFAULT '301',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Table structure for table `email_accounts`
--

CREATE TABLE IF NOT EXISTS `email_accounts` (
  `id` int NOT NULL,
  `domain_id` int DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `quota_mb` int DEFAULT '1024',
  `status` enum('active','inactive') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

-- Files table (for file management tracking)
CREATE TABLE IF NOT EXISTS `files` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `domain_id` int(11) NOT NULL,
  `file_path` varchar(1000) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_size` bigint(20) DEFAULT '0',
  `file_type` varchar(100) DEFAULT NULL,
  `permissions` varchar(10) DEFAULT '644',
  `created_at` datetime NOT NULL,
  `modified_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `domain_id` (`domain_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `ftp_accounts`
--

CREATE TABLE IF NOT EXISTS `ftp_accounts` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `domain_id` int NOT NULL,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL COMMENT 'Store hashed passwords only!',
  `home_path` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

-- Databases table
CREATE TABLE IF NOT EXISTS `databases` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `domain_id` int(11) DEFAULT NULL,
  `db_name` varchar(64) NOT NULL,
  `db_user` varchar(32) NOT NULL,
  `db_pass` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  `status` enum('active','inactive') NOT NULL DEFAULT 'active',
  PRIMARY KEY (`id`),
  UNIQUE KEY `db_name` (`db_name`),
  UNIQUE KEY `db_user` (`db_user`),
  KEY `user_id` (`user_id`),
  KEY `domain_id` (`domain_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- DNS records table
CREATE TABLE IF NOT EXISTS `dns_records` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `domain_id` int(11) NOT NULL,
  `record_type` enum('A','AAAA','CNAME','MX','TXT','NS') NOT NULL DEFAULT 'A',
  `record_name` varchar(255) NOT NULL,
  `record_value` varchar(500) NOT NULL,
  `ttl` int(11) DEFAULT '3600',
  `priority` int(11) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `domain_id` (`domain_id`),
  FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- SSL certificates table
CREATE TABLE IF NOT EXISTS `ssl_certificates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `domain_id` int(11) NOT NULL,
  `certificate` text NOT NULL,
  `private_key` text NOT NULL,
  `ca_bundle` text,
  `expires_at` datetime NOT NULL,
  `auto_renew` tinyint(1) DEFAULT '1',
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `domain_id` (`domain_id`),
  FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- User permissions table
CREATE TABLE IF NOT EXISTS `user_permissions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `permission` varchar(50) NOT NULL,
  `allowed` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `hosting_plans`
--

CREATE TABLE IF NOT EXISTS `hosting_plans` (
  `id` int NOT NULL,
  `name` varchar(255) NOT NULL,
  `disk_space_mb` int UNSIGNED NOT NULL DEFAULT '1000',
  `bandwidth_gb` int UNSIGNED NOT NULL DEFAULT '10',
  `max_domains` int UNSIGNED NOT NULL DEFAULT '1',
  `max_databases` int UNSIGNED NOT NULL DEFAULT '1',
  `max_emails` int UNSIGNED NOT NULL DEFAULT '5',
  `price_monthly` decimal(10,2) NOT NULL DEFAULT '0.00',
  `price_annually` decimal(10,2) NOT NULL DEFAULT '0.00',
  `is_visible` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `hosting_plans`
--

-- Sessions table
CREATE TABLE IF NOT EXISTS `sessions` (
  `id` varchar(128) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `payload` text NOT NULL,
  `last_activity` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `ssl_certificates`
--

CREATE TABLE IF NOT EXISTS `ssl_certificates` (
  `id` int NOT NULL,
  `domain_id` int NOT NULL,
  `certificate` text NOT NULL,
  `private_key` text NOT NULL,
  `ca_bundle` text,
  `expires_at` datetime NOT NULL,
  `auto_renew` tinyint(1) DEFAULT '1',
  `created_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;


CREATE TABLE IF NOT EXISTS `user_preferences` (
  `user_id` int NOT NULL,
  `default_domain_id` int DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `ssl_certificates`
--

-- Insert default permissions
INSERT INTO `user_permissions` (`id`, `user_id`, `permission`, `allowed`) VALUES
(1, 1, 'domain_management', 1),
(2, 1, 'file_management', 1),
(3, 1, 'database_management', 1),
(4, 1, 'ssl_management', 1),
(5, 1, 'dns_management', 1),
(6, 1, 'user_management', 1),
(7, 2, 'domain_management', 1),
(8, 2, 'file_management', 1),
(9, 2, 'database_management', 1),
(10, 2, 'ssl_management', 1),
(11, 2, 'dns_management', 1);

SET FOREIGN_KEY_CHECKS=1;
