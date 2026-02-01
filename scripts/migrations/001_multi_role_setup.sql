-- Migration: 001_multi_role_setup
-- Description: Unifies Admins and Clients into Users table, adds Reseller support.

-- 1. Rename clients to users (Central Auth Table)
RENAME TABLE `clients` TO `users`;

-- 2. Add Role and Owner columns
ALTER TABLE `users` 
    ADD COLUMN `role` ENUM('super_admin','admin','reseller','client') NOT NULL DEFAULT 'client' AFTER `email`,
    ADD COLUMN `owner_id` INT DEFAULT NULL AFTER `role`,
    ADD COLUMN `last_login` TIMESTAMP NULL;

-- 3. Modify status column to be compatible
-- Current: ENUM('active','suspended')
-- We keep it as is for now.

-- 4. Migrate existing Admins to Users table
-- Note: 'superadmin' in admins table maps to 'super_admin' or 'admin' in new enum.
INSERT INTO `users` (username, password, email, role, created_at) 
SELECT username, password, email, CASE WHEN role = 'superadmin' THEN 'super_admin' ELSE 'admin' END, created_at 
FROM `admins`;

-- 5. Drop old admins table
DROP TABLE `admins`;

-- 6. Update Packages for Reseller Ownership & Features
ALTER TABLE `packages` 
    ADD COLUMN `owner_id` INT DEFAULT NULL AFTER `name`,
    MODIFY COLUMN `features` JSON DEFAULT NULL;

-- 7. Create Login Attempts (Brute Force Protection)
CREATE TABLE IF NOT EXISTS `login_attempts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `ip_address` VARCHAR(45) NOT NULL,
    `username` VARCHAR(255) DEFAULT NULL,
    `attempted_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `success` BOOLEAN DEFAULT 0,
    INDEX `idx_ip` (`ip_address`),
    INDEX `idx_time` (`attempted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Add Foreign Key for User Hierarchy (Self-Reference)
-- Optional: Enforce referential integrity
ALTER TABLE `users`
    ADD CONSTRAINT `fk_user_owner`
    FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`)
    ON DELETE SET NULL;

-- 9. Update existing foreign keys in other tables to point to 'users' (metadata update usually automatic on RENAME)
-- But checking column names is good practice. 
-- For now we keep 'client_id' columns in other tables to minimize regression, 
-- but conceptually they refer to 'users.id'.

