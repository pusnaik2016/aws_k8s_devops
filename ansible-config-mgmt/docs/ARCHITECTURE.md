# Architecture & Design — Ansible Configuration Management at Scale

> **Version:** 1.0  
> **Last Updated:** June 2026  
> **Audience:** DevOps Engineers, Platform Engineers, Architects

---

## 1. Overview

This document describes the architecture, design decisions, and technical rationale for the **Production Configuration Management System** built with Ansible.

The system automates the full server lifecycle across a multi-tier infrastructure:
- **Security hardening** (baseline for every server)
- **Web tier** (NGINX reverse proxy + TLS termination)
- **Application tier** (application deployment + systemd management)
- **Database tier** (PostgreSQL + pg_hba access control)
- **Operations** (automated backups, log rotation, OS patching, rollback)

---

## 2. System Architecture

### 2.1 High-Level Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                      INTERNET / USERS                           │
└─────────────────────────────┬───────────────────────────────────┘
                              │ HTTPS (443)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     WEB TIER (DMZ)                              │
│   ┌─────────────────┐      ┌─────────────────┐                  │
│   │  web-prod-01    │      │  web-prod-02    │  (Active-Active) │
│   │  NGINX 1.24     │      │  NGINX 1.24     │                  │
│   │  TLS 1.2/1.3    │      │  TLS 1.2/1.3    │                  │
│   │  UFW + fail2ban │      │  UFW + fail2ban │                  │
│   └────────┬────────┘      └────────┬────────┘                  │
└────────────┼───────────────────────┼────────────────────────────┘
             │ HTTP proxy_pass        │
             ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APP TIER (Private Subnet)                     │
│   ┌─────────────────┐      ┌─────────────────┐                  │
│   │  app-prod-01    │      │  app-prod-02    │  (Active-Active) │
│   │  MyApp :8080    │      │  MyApp :8080    │                  │
│   │  systemd svc    │      │  systemd svc    │                  │
│   │  Java/Runtime   │      │  Java/Runtime   │                  │
│   └────────┬────────┘      └────────┬────────┘                  │
└────────────┼───────────────────────┼────────────────────────────┘
             │ PostgreSQL :5432       │
             ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DB TIER (Private Subnet)                    │
│   ┌─────────────────┐      ┌─────────────────┐                  │
│   │  db-prod-01     │      │  db-prod-02     │  (Primary +      │
│   │  PostgreSQL 15  │─────▶│  PostgreSQL 15  │   Replica)       │
│   │  Primary        │  WAL │  Replica        │                  │
│   └─────────────────┘  Rep └─────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     CONTROL PLANE                               │
│                                                                  │
│  ┌──────────────────────┐   ┌──────────────────────────────┐   │
│  │  Ansible Control Node │   │  Ansible Vault               │   │
│  │  SSH → all tiers     │   │  AES-256 Encrypted Secrets   │   │
│  └──────────────────────┘   └──────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────┐   ┌──────────────────────────────┐   │
│  │  AWS S3              │   │  journald / logrotate        │   │
│  │  Encrypted Backups   │   │  Application Logs            │   │
│  └──────────────────────┘   └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Environment Architecture

| Environment | Purpose | Hosts Per Tier | SSH Port | Backup Retention |
|-------------|---------|---------------|----------|-----------------|
| **Staging** | Dev/test parity | 1 (Vagrant) | 22 | 7 days |
| **Production** | Live traffic | 2 (HA) | 2222 | 30 days |

### 2.3 Network Segmentation

```
Internet → Port 80/443  → Web Tier   (DMZ subnet: 10.0.1.0/24)
Web Tier → Port 8080    → App Tier   (Private subnet: 10.0.2.0/24)
App Tier → Port 5432    → DB Tier    (Private subnet: 10.0.3.0/24)
Control  → Port 2222    → All Tiers  (Management subnet: 10.0.0.0/24)
```

**No direct access** from the internet to App or DB tiers. Each tier's UFW firewall enforces subnet-scoped rules.

---

## 3. Component Design

### 3.1 Role Architecture

```
roles/
├── common          ← Applied to ALL hosts (always runs first)
│   ├── packages    ← apt, unattended-upgrades, logrotate
│   ├── users       ← deploy user, SSH keys, sudo
│   ├── ntp         ← chrony time sync
│   └── security    ← SSH hardening, UFW, fail2ban, sysctl
│
├── nginx           ← Web tier only
│   ├── install     ← NGINX from apt
│   ├── configure   ← nginx.conf (performance-tuned)
│   └── vhost       ← app-vhost.conf (HTTPS, proxy_pass)
│
├── postgresql      ← DB tier only
│   ├── install     ← PostgreSQL 15 from official PG repo
│   ├── configure   ← postgresql.conf (memory-tuned)
│   ├── hba         ← pg_hba.conf (subnet-scoped access)
│   └── provision   ← DB + user creation, privilege revocation
│
├── myapp           ← App tier only
│   ├── system      ← app user, directory structure (release dirs)
│   ├── deploy      ← artifact download, symlink, env file
│   ├── service     ← systemd unit (sandboxed)
│   └── health      ← HTTP health check with retries
│
└── backup          ← DB tier only
    ├── script      ← pg_dump → gzip → S3
    └── schedule    ← cron job + log rotation
```

### 3.2 Playbook Execution Flow

```
site.yml
  │
  ├── Phase 1: common [ALL hosts] ──────────────────────────────┐
  │     packages → users → ntp → security                       │
  │     (parallel across hosts)                                  │
  │                                                              ▼
  ├── Phase 2: nginx [web hosts] ────────────────────────────┐
  │     install → config → vhost → firewall rules              │
  │                                                             ▼
  ├── Phase 3: postgresql + backup [db hosts] ────────────┐
  │     install → config → hba → db/user → backup          │
  │                                                          ▼
  └── Phase 4: myapp [app hosts, serial: 1] ────────────┐
        user → dirs → artifact → config → symlink         │
        → service → health check → cleanup                 ▼
                                              DONE ✅
```

### 3.3 Variable Precedence (Ansible standard)

```
Highest priority
       │
       ├── Extra vars    (-e "key=value")          ← deploy.yml version overrides
       ├── Task vars     (set_fact)
       ├── Host vars     (not used here)
       ├── Group vars    (inventories/<env>/group_vars/)   ← environment-specific
       ├── Role vars     (vars/main.yml)            ← not used
       ├── Role defaults (defaults/main.yml)        ← safe baseline
       │
Lowest priority
```

**Design decision:** All environment differences live in `group_vars/`. Role `defaults/` contain safe fallback values. Nothing is hardcoded in tasks.

---

## 4. Security Design

### 4.1 Defense in Depth

```
Layer 1: Network       → Subnet segmentation, UFW deny-all default
Layer 2: Authentication → SSH key-only, no root login, modern ciphers
Layer 3: Intrusion     → fail2ban brute-force protection
Layer 4: Kernel        → sysctl hardening (11 parameters)
Layer 5: Application   → Least-privilege service users, no shell
Layer 6: Systemd       → NoNewPrivileges, ProtectSystem, PrivateTmp
Layer 7: Secrets       → Ansible Vault AES-256, never plaintext
Layer 8: Patching      → unattended-upgrades for automatic CVE fixes
```

### 4.2 SSH Hardening Configuration

| Parameter | Staging | Production |
|-----------|---------|------------|
| Port | 22 | 2222 |
| Root login | no | no |
| Password auth | no | no |
| Max auth tries | 3 | 3 |
| Ciphers | Modern only | Modern only |
| Key exchange | curve25519, DH-group16/18 | Same |

### 4.3 Firewall Rules Matrix

| Source | Destination | Port | Protocol | Rule |
|--------|-------------|------|----------|------|
| Any | Web tier | 80, 443 | TCP | ALLOW |
| VPC | Any | SSH port | TCP | ALLOW |
| Web subnet | App tier | 8080 | TCP | ALLOW |
| App subnet | DB tier | 5432 | TCP | ALLOW |
| Any | Any | All others | Any | DENY |

### 4.4 Secrets Management

```
Developer creates secret
        │
        ▼
ansible-vault encrypt vault/<env>-secrets.yml
        │
        ├── File stored encrypted in Git ✅
        ├── .vault-pass file in .gitignore ✅
        ├── Decrypted only in memory at runtime ✅
        └── Referenced in tasks as {{ vault_* }} variables ✅
```

---

## 5. Deployment Design

### 5.1 Release Management (Capistrano-style)

```
/opt/myapp/
├── current → releases/20260614T120000  (symlink — atomic switch)
├── releases/
│   ├── 20260614T120000/   ← current release
│   ├── 20260613T180000/   ← previous release (rollback target)
│   ├── 20260612T090000/   ← older release
│   ├── 20260611T140000/   ← older release
│   └── 20260610T080000/   ← oldest kept release
└── shared/
    ├── config/.env        ← persistent (not in release dir)
    ├── log/               ← persistent logs
    └── tmp/               ← persistent temp files
```

**Rolling deployment** (`serial: 1`): Deploys to one app server at a time. Health check must pass before proceeding to the next host — prevents full outage.

### 5.2 Health Check Flow

```
Deploy new release
       │
       ▼
Symlink → new release
       │
       ▼
Restart systemd service
       │
       ▼
HTTP GET /health  (retry 10x, every 3s)
       │
       ├── 200 OK → proceed to next host ✅
       │
       └── timeout/error → report warning ⚠️
              (Manual intervention required)
```

### 5.3 Rollback Flow

```
ansible-playbook playbooks/rollback.yml \
  -e "rollback_release=20260613T180000"
       │
       ▼
Validate release directory exists
       │
       ▼
Symlink → target release (atomic)
       │
       ▼
Restart systemd service
       │
       ▼
HTTP GET /health
       │
       ├── 200 OK → Rollback successful ✅
       └── error  → Rollback applied, investigate ⚠️
```

---

## 6. Data Architecture

### 6.1 Backup Strategy

| Aspect | Configuration |
|--------|--------------|
| Tool | pg_dump (logical backup) |
| Compression | gzip |
| Schedule | Daily at 1AM (production), 2AM (staging) |
| Storage | AWS S3 (STANDARD_IA storage class) |
| Retention (staging) | 7 days |
| Retention (production) | 30 days |
| Naming convention | `{db}_{hostname}_{timestamp}.sql.gz` |
| Encryption at rest | S3 server-side encryption |

### 6.2 Log Architecture

| Log Type | Location | Rotation |
|----------|----------|---------|
| Application | `/var/log/myapp/*.log` | Daily, 14-day retention |
| NGINX access | `/var/log/nginx/myapp_access.log` | Managed by NGINX |
| NGINX error | `/var/log/nginx/myapp_error.log` | Managed by NGINX |
| PostgreSQL | `/var/log/postgresql/*.log` | Daily, 100MB max |
| Backup | `/var/log/backup.log` | Weekly, 4-week retention |
| Systemd services | journald | System default |

---

## 7. Performance Design

### 7.1 NGINX Tuning

| Parameter | Staging | Production |
|-----------|---------|------------|
| `worker_processes` | auto | auto |
| `worker_connections` | 1024 | 4096 |
| `use` directive | epoll | epoll |
| `multi_accept` | on | on |
| `gzip` | on | on |
| Rate limiting | 10r/s (general), 30r/s (api) | Same |

### 7.2 PostgreSQL Tuning

| Parameter | Staging | Production | Rationale |
|-----------|---------|------------|-----------|
| `shared_buffers` | 256MB | 2GB | ~25% of RAM |
| `effective_cache_size` | 512MB | 6GB | ~75% of RAM |
| `work_mem` | 4MB | 16MB | Per-sort/per-connection |
| `max_connections` | 100 | 300 | Based on app pool size |
| `checkpoint_completion_target` | 0.9 | 0.9 | Spread checkpoint I/O |
| `random_page_cost` | 1.1 | 1.1 | SSD-optimized |
| Slow query log | 500ms | 500ms | Capture slow queries |

### 7.3 Ansible Performance Tuning

| Setting | Value | Benefit |
|---------|-------|---------|
| `forks` | 20 | Parallel host execution |
| `pipelining` | True | Reduces SSH round-trips by ~60% |
| `ControlPersist` | 60s | Reuses SSH connections |
| `fact_caching` | jsonfile (1hr) | Avoids re-gathering facts |

---

## 8. Design Decisions & Trade-offs

### Decision 1: Agentless (SSH) vs Agent-based

| Aspect | Agentless (Ansible) ✅ | Agent-based (Chef/Puppet) |
|--------|----------------------|--------------------------|
| Setup complexity | Low | High |
| Runtime overhead | None on targets | Agent process running |
| Network requirements | SSH only | Agent port + server |
| Adoption barrier | Low (YAML) | Higher (Ruby DSL) |
| Pull vs Push | Push | Pull |

**Decision:** Ansible's agentless model reduces operational overhead and is ideal for environments where installing agents is restricted.

### Decision 2: Roles vs Monolithic Playbooks

**Chosen:** Modular roles with include_tasks for sub-concerns.

**Rationale:**
- Roles are reusable across projects
- `include_tasks` allows tagging sub-sections (`--tags security`)
- `defaults/main.yml` provides safe overridable defaults
- Each role has a single responsibility

### Decision 3: Capistrano-style Release Directories vs In-place Updates

**Chosen:** Capistrano-style (`releases/` + `current` symlink).

**Rationale:**
- Atomic deployment: symlink switch is instantaneous
- Instant rollback without re-deploying artifacts
- No downtime between "copy files" and "restart service" phases
- Last N releases preserved automatically

### Decision 4: Serial Deployment vs Parallel

**Chosen:** `serial: 1` for app tier.

**Rationale:**
- Ensures at least one app server is healthy at all times
- Health check gate prevents cascading failures
- Slightly slower but significantly safer for production traffic

### Decision 5: Per-environment Vault Files vs Single Vault File

**Chosen:** Per-environment vault files (`staging-secrets.yml`, `production-secrets.yml`).

**Rationale:**
- Different vault passwords possible per environment
- Staging developers don't need production secrets
- Reduced blast radius if a vault password is compromised

---

## 9. Dependency Map

```
playbooks/site.yml
    │
    ├── roles/common (ALL hosts)
    │       └── depends on: apt, systemd, ufw, fail2ban
    │
    ├── roles/nginx (web hosts)
    │       └── depends on: common, apt, openssl
    │
    ├── roles/postgresql (db hosts)
    │       ├── depends on: common, python3-psycopg2
    │       └── community.postgresql collection
    │
    ├── roles/backup (db hosts)
    │       └── depends on: postgresql, awscli, cron
    │
    └── roles/myapp (app hosts)
            ├── depends on: common, systemd
            └── reads: vault_postgresql_password, vault_app_secret_key
```

### Required Ansible Collections

```yaml
# requirements.yml (install with: ansible-galaxy collection install -r requirements.yml)
collections:
  - name: community.general      # UFW, timezone modules
    version: ">=7.0.0"
  - name: community.postgresql   # PostgreSQL modules
    version: ">=3.0.0"
  - name: ansible.posix          # sysctl, synchronize
    version: ">=1.5.0"
```

---

## 10. Idempotency Guarantee

All tasks are designed to be idempotent:

| Pattern | Example |
|---------|---------|
| `state: present/absent` | Package, user, file tasks |
| `creates:` arg | One-time file generation (SSL cert) |
| `args.creates` | openssl cert generation |
| Checksums | `get_url` compares checksums before re-downloading |
| `lineinfile` | Ensures exactly one matching line |
| `template` with validate | Config deployed only if valid |
| `notify` handlers | Services restarted only when config actually changes |

Running `ansible-playbook site.yml` ten times produces **identical state** each time.
