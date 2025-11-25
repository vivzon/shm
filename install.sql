-- phpMyAdmin SQL Dump
-- version 5.2.1deb3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Nov 22, 2025 at 01:38 AM
-- Server version: 8.0.44-0ubuntu0.24.04.1
-- PHP Version: 8.4.14

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `shm_panel`
--

-- --------------------------------------------------------

--
-- Table structure for table `databases`
--

CREATE TABLE `databases` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `domain_id` int DEFAULT NULL,
  `db_name` varchar(64) NOT NULL,
  `db_user` varchar(32) NOT NULL,
  `db_pass` varchar(255) NOT NULL,
  `created_at` datetime NOT NULL,
  `status` enum('active','inactive') NOT NULL DEFAULT 'active'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- --------------------------------------------------------

--
-- Table structure for table `dns_records`
--

CREATE TABLE `dns_records` (
  `id` int NOT NULL,
  `domain_id` int NOT NULL,
  `record_type` enum('A','AAAA','CNAME','MX','TXT','NS') NOT NULL DEFAULT 'A',
  `record_name` varchar(255) NOT NULL,
  `record_value` varchar(500) NOT NULL,
  `ttl` int DEFAULT '3600',
  `priority` int DEFAULT NULL,
  `created_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- --------------------------------------------------------

--
-- Table structure for table `domains`
--

CREATE TABLE `domains` (
  `id` int NOT NULL,
  `user_id` int DEFAULT NULL,
  `parent_id` int DEFAULT NULL,
  `domain_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `document_root` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `php_version` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '8.4',
  `ssl_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `status` enum('active','inactive','suspended') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `expiry_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `domains`
--

INSERT INTO `domains` (`id`, `user_id`, `parent_id`, `domain_name`, `document_root`, `php_version`, `ssl_enabled`, `status`, `created_at`, `expiry_date`) VALUES
(3, 1, NULL, 'server.vivzon.in', '/var/www/server.vivzon.in', '8.4', 0, 'active', '2025-11-18 07:27:38', NULL),
(4, 1, NULL, 'hosting.vivzon.in', '/var/www/hosting.vivzon.in', '8.4', 0, 'active', '2025-11-18 07:29:13', NULL),
(6, 2, NULL, 'creativekey.in', '/var/www/creativekey.in', '8.2', 0, 'active', '2025-11-19 12:30:23', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `domain_aliases`
--

CREATE TABLE `domain_aliases` (
  `id` int NOT NULL,
  `domain_id` int NOT NULL,
  `alias_name` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `domain_redirects`
--

CREATE TABLE `domain_redirects` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `source_domain` varchar(255) NOT NULL,
  `destination_url` text NOT NULL,
  `redirect_type` int NOT NULL DEFAULT '301',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `email_accounts`
--

CREATE TABLE `email_accounts` (
  `id` int NOT NULL,
  `domain_id` int DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `quota_mb` int DEFAULT '1024',
  `status` enum('active','inactive') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `files`
--

CREATE TABLE `files` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `domain_id` int NOT NULL,
  `file_path` varchar(1000) NOT NULL,
  `file_name` varchar(255) NOT NULL,
  `file_size` bigint DEFAULT '0',
  `file_type` varchar(100) DEFAULT NULL,
  `permissions` varchar(10) DEFAULT '644',
  `created_at` datetime NOT NULL,
  `modified_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- --------------------------------------------------------

--
-- Table structure for table `ftp_accounts`
--

CREATE TABLE `ftp_accounts` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `domain_id` int NOT NULL,
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL COMMENT 'Store hashed passwords only!',
  `home_path` varchar(255) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `hosting_plans`
--

CREATE TABLE `hosting_plans` (
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

INSERT INTO `hosting_plans` (`id`, `name`, `disk_space_mb`, `bandwidth_gb`, `max_domains`, `max_databases`, `max_emails`, `price_monthly`, `price_annually`, `is_visible`, `created_at`) VALUES
(1, 'Basic', 10000, 10, 1, 1, 1, 399.00, 169.00, 1, '2025-11-19 03:18:07'),
(2, 'Standard', 2000, 30, 3, 3, 3, 649.00, 249.00, 1, '2025-11-19 06:09:21'),
(3, 'Premium', 50000, 50, 50, 50, 5, 799.00, 299.00, 1, '2025-11-19 06:14:31'),
(4, 'Business', 100000, 100, 100, 100, 10, 1699.00, 799.00, 1, '2025-11-19 06:58:31');

-- --------------------------------------------------------

--
-- Table structure for table `sessions`
--

CREATE TABLE `sessions` (
  `id` varchar(128) NOT NULL,
  `user_id` int DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `payload` text NOT NULL,
  `last_activity` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- --------------------------------------------------------

--
-- Table structure for table `ssl_certificates`
--

CREATE TABLE `ssl_certificates` (
  `id` int NOT NULL,
  `domain_id` int NOT NULL,
  `certificate` text NOT NULL,
  `private_key` text NOT NULL,
  `ca_bundle` text,
  `expires_at` datetime NOT NULL,
  `auto_renew` tinyint(1) DEFAULT '1',
  `created_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

--
-- Dumping data for table `ssl_certificates`
--

INSERT INTO `ssl_certificates` (`id`, `domain_id`, `certificate`, `private_key`, `ca_bundle`, `expires_at`, `auto_renew`, `created_at`) VALUES
(1, 4, 'Iz3vxtNQxUFXIsEWUPHrCDo6RryizXM6aKmc8ziWdsuTkeSVlh9ckxR2iybVRTOf8KohBphUezUGOKsOPPeaG39Xd4LKBZ/+aqIZPRXe91LZugsxjtB5qe/8SguXLlNy+zpr2pnZQc/XTZBcvzskE1VL9rj8AntJuIKZbHo2Gib+dA==', 'znW4TJFKVZQUEiXq9yDDSjo6DYFxa4GHZ21rzwbtQ3+YNRMsIMKMHz/5Xxb4Fg6nAb7GzN0mOd4hKpWBeQdKE7Ao1Jgsg9ABmAt/B2ri4DA+9qIbqoh1mGn1NuwioqGSOYuBn3X3jJa70A+08lWggwR/FUqDpD0lWURnSjrN7eIThw==', NULL, '2026-02-16 12:44:19', 1, '2025-11-18 12:44:19'),
(2, 3, 'VRzd5XBLOU1q7JkRlysq+Do6NBW4RfTpA+a2UbPx4YMP9RFnub8v2lHmvHZsGSLCEZOp/9KHU3T9ouV8SN4ku6Wo0YTCAkv54gNfdXHSyIkO7IrciAFXV0Izo4DurbKYUBCsQWwdpV6+mX4cL3vD94dEJ0QSTQWvXYbvOwMansvggw==', '82apS5HnLmSQf5xMl6j94Do6XS3NFTMn5scsQyLQXfyH1a7ytKB0cZLVPQVq+Vcl23gPEhzceWJU1KYdAb0YbVDR3UO45e8I3uptxsyXaM5Lz+51/MxGK9yfo3TeHcgAVMOQL2qBnpyLUwUf6ax1utEy9E85U2IICCtpvS53kFOlBQ==', NULL, '2026-02-16 12:44:33', 1, '2025-11-18 12:44:33'),
(3, 6, 'paPfWkz2ylY410LUdoslNTo6ilPA1BmVEvAp2nfqVHTBQyqY8luHTkhOd7izBWEIyJmnqa+rJOM4AdgT74bm0Cb+Ms2yahLwf1PyMybQARwv2qsPm1Ai2SO6COqbiSMQ0ir5cYNmh5fFEIbxPylCTORO/Eb/FSBLX7o/0nb439BeLw==', 'rPHet7hPKVF8xSj5wvua6To6HYcNIcag4Ek9IiUyBqbKtIuhj3XrBOyoHdC2nSM3dOcx58vx7zmZjNJhzB/yQqvTIHGJ+BoAFt3BZWAuYgSeBflGCKUbzf2oLJfJ40WEDDu4nQuJmvTkTPyYGUgUjfB6UgZ8CPP1gK2RdumnA80FBQ==', NULL, '2026-02-17 12:30:38', 1, '2025-11-19 12:30:38');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('user','admin','superadmin') COLLATE utf8mb4_unicode_ci DEFAULT 'user',
  `plan_id` int DEFAULT NULL,
  `ssh_access_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `status` enum('active','inactive','suspended') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `last_login` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `email`, `password`, `role`, `plan_id`, `ssh_access_enabled`, `status`, `last_login`, `created_at`, `updated_at`) VALUES
(1, 'admin', 'vivekrajraja@gmail.com', '$2y$12$devT6s5HpTt3Um3A.aFcMO0guzzucjf.AsQ8bqKAi1J8uvRnIrWQ2', 'admin', NULL, 0, 'active', '2025-11-22 01:32:19', '2025-11-16 13:20:38', '2025-11-22 01:32:19'),
(2, 'vivzon', 'info@vivzon.in', '$2y$12$rVJ/8HK002/FMIB6GaWHGOyZM6VgJbmHflThjspErK6OQWEXMnxea', 'user', NULL, 0, 'active', '2025-11-20 08:02:12', '2025-11-18 13:44:13', '2025-11-20 08:02:12');

-- --------------------------------------------------------

--
-- Table structure for table `user_permissions`
--

CREATE TABLE `user_permissions` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `permission` varchar(50) NOT NULL,
  `allowed` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

--
-- Dumping data for table `user_permissions`
--

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

-- --------------------------------------------------------

--
-- Table structure for table `user_preferences`
--

CREATE TABLE `user_preferences` (
  `user_id` int NOT NULL,
  `default_domain_id` int DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `user_preferences`
--

INSERT INTO `user_preferences` (`user_id`, `default_domain_id`, `updated_at`) VALUES
(1, 4, '2025-11-18 11:36:55'),
(2, 6, '2025-11-19 12:30:59');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `databases`
--
ALTER TABLE `databases`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `db_name` (`db_name`),
  ADD UNIQUE KEY `db_user` (`db_user`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `domain_id` (`domain_id`);

--
-- Indexes for table `dns_records`
--
ALTER TABLE `dns_records`
  ADD PRIMARY KEY (`id`),
  ADD KEY `domain_id` (`domain_id`);

--
-- Indexes for table `domains`
--
ALTER TABLE `domains`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `domain_name` (`domain_name`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `parent_id` (`parent_id`);

--
-- Indexes for table `domain_aliases`
--
ALTER TABLE `domain_aliases`
  ADD PRIMARY KEY (`id`),
  ADD KEY `domain_id` (`domain_id`);

--
-- Indexes for table `domain_redirects`
--
ALTER TABLE `domain_redirects`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `email_accounts`
--
ALTER TABLE `email_accounts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `domain_id` (`domain_id`);

--
-- Indexes for table `files`
--
ALTER TABLE `files`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `domain_id` (`domain_id`);

--
-- Indexes for table `ftp_accounts`
--
ALTER TABLE `ftp_accounts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `domain_id` (`domain_id`);

--
-- Indexes for table `hosting_plans`
--
ALTER TABLE `hosting_plans`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `sessions`
--
ALTER TABLE `sessions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `ssl_certificates`
--
ALTER TABLE `ssl_certificates`
  ADD PRIMARY KEY (`id`),
  ADD KEY `domain_id` (`domain_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `username` (`username`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `user_permissions`
--
ALTER TABLE `user_permissions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `user_preferences`
--
ALTER TABLE `user_preferences`
  ADD PRIMARY KEY (`user_id`),
  ADD KEY `default_domain_id` (`default_domain_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `databases`
--
ALTER TABLE `databases`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `dns_records`
--
ALTER TABLE `dns_records`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `domains`
--
ALTER TABLE `domains`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `domain_aliases`
--
ALTER TABLE `domain_aliases`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `domain_redirects`
--
ALTER TABLE `domain_redirects`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `email_accounts`
--
ALTER TABLE `email_accounts`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `files`
--
ALTER TABLE `files`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ftp_accounts`
--
ALTER TABLE `ftp_accounts`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `hosting_plans`
--
ALTER TABLE `hosting_plans`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `ssl_certificates`
--
ALTER TABLE `ssl_certificates`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `user_permissions`
--
ALTER TABLE `user_permissions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `databases`
--
ALTER TABLE `databases`
  ADD CONSTRAINT `databases_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `databases_ibfk_2` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `dns_records`
--
ALTER TABLE `dns_records`
  ADD CONSTRAINT `dns_records_ibfk_1` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `domains`
--
ALTER TABLE `domains`
  ADD CONSTRAINT `domains_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `domain_aliases`
--
ALTER TABLE `domain_aliases`
  ADD CONSTRAINT `fk_alias_domain` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `email_accounts`
--
ALTER TABLE `email_accounts`
  ADD CONSTRAINT `email_accounts_ibfk_1` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `files`
--
ALTER TABLE `files`
  ADD CONSTRAINT `files_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `files_ibfk_2` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `ftp_accounts`
--
ALTER TABLE `ftp_accounts`
  ADD CONSTRAINT `fk_ftp_domain` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `sessions`
--
ALTER TABLE `sessions`
  ADD CONSTRAINT `sessions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `ssl_certificates`
--
ALTER TABLE `ssl_certificates`
  ADD CONSTRAINT `ssl_certificates_ibfk_1` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `user_permissions`
--
ALTER TABLE `user_permissions`
  ADD CONSTRAINT `user_permissions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `user_preferences`
--
ALTER TABLE `user_preferences`
  ADD CONSTRAINT `user_preferences_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_preferences_ibfk_2` FOREIGN KEY (`default_domain_id`) REFERENCES `domains` (`id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
