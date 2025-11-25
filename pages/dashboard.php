<?php
// Make sure we can use the $pdo created in config.php
global $pdo;

// Ensure the user is logged in and session is available
$user_id = $_SESSION['user_id'] ?? null;

if (!$user_id) {
    // Optional: redirect if somehow reached without session
    header('Location: /login');
    exit;
}

// Get stats

// Domains
$domains_count = $pdo->prepare("SELECT COUNT(*) FROM domains WHERE user_id = ?");
$domains_count->execute([$user_id]);
$domains = $domains_count->fetchColumn();

// Databases (reserved keyword, so we use backticks)
$databases_count = $pdo->prepare("SELECT COUNT(*) FROM `databases` WHERE user_id = ?");
$databases_count->execute([$user_id]);
$databases = $databases_count->fetchColumn();

// SSL certificates
$ssl_count = $pdo->prepare("
    SELECT COUNT(*)
    FROM ssl_certificates sc
    JOIN domains d ON sc.domain_id = d.id
    WHERE d.user_id = ?
");
$ssl_count->execute([$user_id]);
$ssl = $ssl_count->fetchColumn();

// Simple “active domains” label (can be improved later)
$activeDomains = $domains;
?>

<style>
    /* LAYOUT GRID */
    .layout-grid {
        display: grid;
        grid-template-columns: 2fr 1.1fr;
        gap: 18px;
    }

    @media (max-width: 900px) {
        .layout-grid {
            grid-template-columns: 1fr;
        }
    }

    /* STATS CARDS */
    .stats {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
        gap: 14px;
    }

    .stat-card {
        background: var(--bg-card);
        border-radius: var(--radius-lg);
        padding: 14px 14px 12px;
        border: 1px solid var(--border-soft);
        box-shadow: var(--shadow-soft);
        transition: transform 0.12s ease, box-shadow 0.12s ease;
    }

    .stat-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 14px 30px rgba(15, 23, 42, 0.08);
    }

    .stat-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 8px;
    }

    .stat-title {
        font-size: 12px;
        font-weight: 500;
        color: var(--text-muted);
        text-transform: uppercase;
        letter-spacing: .06em;
    }

    .stat-tag {
        font-size: 11px;
        padding: 3px 8px;
        border-radius: 999px;
        background: #f3f4f6;
        color: var(--text-muted);
    }

    .stat-body {
        display: flex;
        justify-content: space-between;
        align-items: flex-end;
        gap: 10px;
    }

    .stat-number {
        font-size: 26px;
        font-weight: 600;
        color: var(--primary-dark);
    }

    .stat-label {
        font-size: 12px;
        color: var(--text-muted);
        margin-top: 3px;
    }

    .stat-icon {
        width: 36px;
        height: 36px;
        border-radius: 10px;
        background: #eff6ff;
        color: #1d4ed8;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 18px;
    }

    .sub-stat {
        margin-top: 10px;
        display: flex;
        gap: 8px;
        flex-wrap: wrap;
        font-size: 11px;
    }

    .sub-pill {
        padding: 3px 8px;
        border-radius: 999px;
        background: #f9fafb;
        border: 1px solid #e5e7eb;
        color: var(--text-muted);
    }

    .sub-pill strong {
        color: var(--text-main);
    }

    /* RIGHT PANEL */
    .right-panel {
        background: var(--bg-card);
        border-radius: var(--radius-lg);
        padding: 14px 14px 16px;
        border: 1px solid var(--border-soft);
        box-shadow: var(--shadow-soft);
    }

    .right-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 8px;
    }

    .right-title {
        font-size: 13px;
        font-weight: 500;
    }

    .right-subtitle {
        font-size: 11px;
        color: var(--text-muted);
    }

    .right-status-pill {
        font-size: 11px;
        padding: 4px 9px;
        border-radius: 999px;
        border: 1px solid var(--border-soft);
        background: #f9fafb;
        color: var(--text-muted);
    }

    .activity-placeholder {
        margin-top: 8px;
        background: #f9fafb;
        border-radius: 10px;
        border: 1px dashed var(--border-soft);
        padding: 10px 10px 8px;
        font-size: 12px;
        color: var(--text-muted);
    }

    .activity-placeholder p {
        margin-bottom: 4px;
    }

    .activity-placeholder small {
        font-size: 11px;
    }

    .right-footer {
        margin-top: 8px;
        font-size: 11px;
        color: var(--text-muted);
        text-align: right;
    }

    /* RESPONSIVE SIDEBAR */
    @media (max-width: 840px) {
        .sidebar {
            display: none;
        }
        .main-content {
            margin-left: 0;
            padding: 14px 14px 20px;
        }
        .header {
            flex-direction: column;
            align-items: flex-start;
        }
        .header-right {
            justify-content: space-between;
            width: 100%;
        }
    }
</style>

<main class="main-content">

    <!-- HEADER -->
    <section class="header">
        <div class="header-left">
            <div class="page-title">Dashboard</div>
            <div class="page-subtitle">Quick overview of your domains, databases and SSL certificates.</div>
        </div>
        <div class="header-right">
            <span class="chip chip-live">● Session Active</span>
            <div class="user-info">
                <div class="user-avatar">
                    <?php
                    $initial = strtoupper(substr($_SESSION['username'] ?? 'U', 0, 1));
                    echo htmlspecialchars($initial);
                    ?>
                </div>
                <div class="user-meta">
                    <span class="user-name"><?php echo htmlspecialchars($_SESSION['username'] ?? 'User'); ?></span>
                    <span class="user-role"><?php echo is_admin() ? 'Administrator' : 'User'; ?></span>
                </div>
            </div>
        </div>
    </section>

    <!-- LAYOUT GRID -->
    <section class="layout-grid">
        <!-- LEFT: STATS -->
        <div>
            <div class="stats">
                <!-- Domains -->
                <div class="stat-card">
                    <div class="stat-header">
                        <div class="stat-title">Domains</div>
                        <span class="stat-tag">Your websites</span>
                    </div>
                    <div class="stat-body">
                        <div>
                            <div class="stat-number"><?php echo (int) $domains; ?></div>
                            <div class="stat-label">Total domains linked to your account.</div>
                        </div>
                        <div class="stat-icon">🌐</div>
                    </div>
                    <div class="sub-stat">
                        <div class="sub-pill"><strong><?php echo (int) $activeDomains; ?></strong> active</div>
                        <div class="sub-pill"><strong>0</strong> expiring soon (label)</div>
                    </div>
                </div>

                <!-- Databases -->
                <div class="stat-card">
                    <div class="stat-header">
                        <div class="stat-title">Databases</div>
                        <span class="stat-tag">Data storage</span>
                    </div>
                    <div class="stat-body">
                        <div>
                            <div class="stat-number"><?php echo (int) $databases; ?></div>
                            <div class="stat-label">Databases created for your projects.</div>
                        </div>
                        <div class="stat-icon">🗄️</div>
                    </div>
                    <div class="sub-stat">
                        <div class="sub-pill"><strong>Secure</strong> &amp; private</div>
                        <div class="sub-pill"><strong>Backups</strong> recommended</div>
                    </div>
                </div>

                <!-- SSL -->
                <div class="stat-card">
                    <div class="stat-header">
                        <div class="stat-title">SSL Certificates</div>
                        <span class="stat-tag">Security</span>
                    </div>
                    <div class="stat-body">
                        <div>
                            <div class="stat-number"><?php echo (int) $ssl; ?></div>
                            <div class="stat-label">HTTPS protection for your domains.</div>
                        </div>
                        <div class="stat-icon">🔐</div>
                    </div>
                    <div class="sub-stat">
                        <div class="sub-pill"><strong>Auto-renew</strong> status (label)</div>
                        <div class="sub-pill"><strong>0</strong> expiring soon (label)</div>
                    </div>
                </div>
            </div>
        </div>

        <!-- RIGHT: ACTIVITY PANEL -->
        <aside class="right-panel">
            <div class="right-header">
                <div>
                    <div class="right-title">Recent Activity</div>
                    <div class="right-subtitle">This area will show the latest changes you make.</div>
                </div>
                <span class="right-status-pill">Updated in real time</span>
            </div>

            <div class="activity-placeholder">
                <p>No activity yet.</p>
                <small>
                    Once you add or edit domains, databases, SSL or DNS records,
                    a short history will appear here so you can quickly see what's changed.
                </small>
            </div>

            <div class="right-footer">
                Tip: Start by adding a domain to see more detailed information here.
            </div>
        </aside>
    </section>
</main>
