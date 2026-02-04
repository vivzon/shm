-- SHM Database Schema
-- Multi-tenant design for Super Admin, Resellers, and Clients

CREATE DATABASE IF NOT EXISTS shm_panel;
USE shm_panel;

-- Users Table
CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('super_admin', 'reseller', 'client') NOT NULL DEFAULT 'client',
    parent_id BIGINT DEFAULT NULL, -- For resellers/sub-users
    two_factor_secret VARCHAR(255) DEFAULT NULL,
    status ENUM('active', 'suspended') NOT NULL DEFAULT 'active',
    disk_quota INT DEFAULT 1024, -- in MB
    bandwidth_quota INT DEFAULT 10240, -- in MB
    remember_token VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Hosting Packages
CREATE TABLE packages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    disk_limit INT DEFAULT 1024,
    bandwidth_limit INT DEFAULT 10240,
    domains_limit INT DEFAULT 1,
    subdomains_limit INT DEFAULT 5,
    databases_limit INT DEFAULT 5,
    emails_limit INT DEFAULT 5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Domains Table
CREATE TABLE domains (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    domain_name VARCHAR(255) NOT NULL UNIQUE,
    document_root VARCHAR(255) NOT NULL,
    php_version VARCHAR(10) DEFAULT '8.1',
    has_ssl BOOLEAN DEFAULT FALSE,
    ssl_provider ENUM('none', 'letsencrypt', 'custom') DEFAULT 'none',
    status ENUM('active', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Subdomains
CREATE TABLE subdomains (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    domain_id BIGINT NOT NULL,
    subdomain_name VARCHAR(255) NOT NULL,
    document_root VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE,
    UNIQUE(domain_id, subdomain_name)
);

-- Databases
CREATE TABLE user_databases (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    db_name VARCHAR(255) NOT NULL UNIQUE,
    db_user VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Email Accounts
CREATE TABLE email_accounts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    domain_id BIGINT NOT NULL,
    email_address VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    quota INT DEFAULT 250, -- in MB
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (domain_id) REFERENCES domains(id) ON DELETE CASCADE
);

-- Audit Logs
CREATE TABLE audit_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT,
    action VARCHAR(255) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
