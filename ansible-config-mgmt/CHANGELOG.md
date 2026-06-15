# =============================================================================
# CHANGELOG — Ansible Configuration Management
# =============================================================================
# Format: [version] — date
#   Added   — new features
#   Changed — changes in existing functionality
#   Fixed   — bug fixes
#   Removed — removed features
#   Security — security-related changes
# =============================================================================

## [1.0.0] — 2026-06-14

### Added
- **Role: common** — baseline security for all servers
  - Package installation & apt hygiene
  - Deploy user creation with passwordless sudo
  - SSH hardening (modern ciphers, key-only auth, configurable port)
  - UFW firewall (deny-all default, dynamic per-role rules)
  - fail2ban (SSH + DDoS jails, configurable ban times)
  - Kernel sysctl hardening (11 security parameters)
  - Chrony NTP time synchronisation
  - Automatic security patching (unattended-upgrades)
  - Application log rotation (14-day retention)

- **Role: nginx** — production-grade reverse proxy
  - NGINX installation from apt
  - Self-signed TLS generation (staging only)
  - HTTP → HTTPS redirect
  - HSTS header (365 days)
  - TLS 1.2/1.3 only with modern ciphers
  - Security headers (X-Frame-Options, X-Content-Type, X-XSS-Protection)
  - Rate limiting zones (general: 10r/s, api: 30r/s)
  - Upstream load balancing with least_conn
  - Gzip compression
  - Static asset caching (30-day Cache-Control)
  - Per-role UFW firewall rules

- **Role: postgresql** — production-tuned database
  - PostgreSQL 15 from official PGDG repository
  - Parameterised postgresql.conf (memory, WAL, connections)
  - Dynamic pg_hba.conf (subnet-scoped access control)
  - Application database + least-privilege user creation
  - PUBLIC privilege revocation
  - Slow query logging (>500ms)
  - Per-role UFW firewall rules

- **Role: myapp** — full application lifecycle management
  - Dedicated system user (no login shell)
  - Capistrano-style release directory structure
  - Artifact download from URL or local copy
  - Timestamped release directories
  - Atomic `current` symlink deployment
  - Vault-sourced environment file (0600 permissions)
  - Sandboxed systemd service unit (NoNewPrivileges, ProtectSystem)
  - HTTP health check with 10x retry
  - Automatic old release cleanup (keep last N)
  - Per-role UFW firewall rules

- **Role: backup** — automated S3 database backups
  - pg_dump with gzip compression
  - S3 upload with STANDARD_IA storage class
  - Configurable retention and schedule
  - Structured shell logging
  - Cron job management
  - Backup log rotation

- **Playbooks**
  - `site.yml` — phased full convergence (common → web → db → app)
  - `deploy.yml` — rolling app-only deployment with deploy info banner
  - `patch.yml` — OS patching with conditional reboot + service verification
  - `backup.yml` — on-demand database backup with output display
  - `rollback.yml` — validated release rollback with health check

- **Inventories**
  - Staging: 1 host per tier (Vagrant), port 22, relaxed settings
  - Production: 2 hosts per tier (HA), port 2222, strict settings

- **Vault**
  - Per-environment encrypted secret files
  - Staging and production secret templates

- **Documentation**
  - `README.md` — project overview, quick start, commands reference
  - `docs/ARCHITECTURE.md` — system design, security design, component map
  - `docs/RUNBOOK.md` — operational procedures, incident response, troubleshooting
  - `CHANGELOG.md` — this file

- **Scripts**
  - `scripts/health-check.sh` — automated system health verification

- **Configuration**
  - `ansible.cfg` — SSH pipelining, fact caching, vault integration
  - `Vagrantfile` — 3-VM local lab (Ubuntu 22.04)
  - `requirements.yml` — Galaxy collections (community.general, community.postgresql, ansible.posix)
  - `.gitignore` — vault passwords, SSH keys, Vagrant state excluded
