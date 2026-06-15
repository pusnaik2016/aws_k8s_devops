# 🤖 Production Configuration Management with Ansible

> **Automated infrastructure provisioning, security hardening, application deployment, and operational tooling for multi-environment server fleets.**
>
> Based on: [Building Configuration Management at Scale with Ansible](https://medium.com/@arvindverma021/building-configuration-management-at-scale-with-ansible-6aebc381414b)

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **README.md** (this file) | Project overview, quick start, command reference |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, security design, component diagrams, design decisions |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | Day-to-day operations, deployment, rollback, incident response, troubleshooting |
| [CHANGELOG.md](CHANGELOG.md) | Version history and feature list |

---

## 🏗️ Architecture

```
                    ┌─────────────────────────┐
                    │   Ansible Control Node   │
                    │   (ansible.cfg + vault)  │
                    └───────────┬─────────────┘
                                │ SSH (Passwordless)
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                  ▼
     ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
     │   Web Servers   │ │  App Servers   │ │   DB Servers   │
     │  (NGINX + TLS)  │ │  (MyApp svc)   │ │ (PostgreSQL)   │
     └────────────────┘ └────────────────┘ └────────────────┘
              │                 │                  │
              └─────────────────┼──────────────────┘
                                ▼
                    ┌─────────────────────────┐
                    │    Common Baseline       │
                    │  UFW · fail2ban · NTP    │
                    │  logrotate · auto-patch  │
                    │  SSH hardening · users   │
                    │  kernel sysctl tuning    │
                    └─────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
           ┌──────────────┐       ┌──────────────┐
           │  S3 Backups   │       │  Journal      │
           │  (encrypted)  │       │  Logging      │
           └──────────────┘       └──────────────┘
```

---

## 📁 Project Structure — 51 Files

```
ansible-config-mgmt/
├── ansible.cfg                          # Global config (SSH pipelining, fact caching)
├── Vagrantfile                          # Local 3-VM lab (web/app/db)
├── .gitignore
│
├── inventories/
│   ├── staging/                         # Vagrant IPs, relaxed security
│   │   ├── hosts.ini
│   │   └── group_vars/
│   │       ├── all.yml                  # SSH port 22, 7-day backups
│   │       ├── web.yml                  # 1024 worker connections
│   │       ├── app.yml                  # 512MB JVM heap
│   │       └── db.yml                   # 100 max connections
│   └── production/                      # Private subnet IPs, strict security
│       ├── hosts.ini                    # 2 hosts per tier (HA)
│       └── group_vars/
│           ├── all.yml                  # SSH port 2222, 30-day backups
│           ├── web.yml                  # 4096 worker connections, 2 upstreams
│           ├── app.yml                  # 2GB JVM heap
│           └── db.yml                   # 300 max connections, 2GB shared_buffers
│
├── roles/
│   ├── common/                          # ★ Baseline security & packages
│   │   ├── defaults/main.yml
│   │   ├── meta/main.yml
│   │   ├── tasks/
│   │   │   ├── main.yml                 # Entrypoint → includes sub-tasks
│   │   │   ├── packages.yml             # apt, unattended-upgrades, logrotate
│   │   │   ├── security.yml             # SSH hardening, UFW, fail2ban, sysctl
│   │   │   ├── users.yml               # Deploy user, SSH keys, sudo
│   │   │   └── ntp.yml                 # Chrony time sync
│   │   ├── handlers/main.yml           # Restart SSH, fail2ban, chrony
│   │   └── templates/
│   │       ├── sshd_config.j2           # Modern ciphers, key-only auth
│   │       ├── fail2ban.local.j2        # SSH + DDoS jails
│   │       ├── logrotate-app.conf.j2    # 14-day rotation
│   │       └── chrony.conf.j2           # NTP servers
│   │
│   ├── nginx/                           # ★ NGINX reverse proxy + TLS
│   │   ├── defaults/main.yml
│   │   ├── tasks/main.yml              # Install, SSL, vhost, firewall
│   │   ├── handlers/main.yml           # Reload / Restart
│   │   └── templates/
│   │       ├── nginx.conf.j2            # epoll, gzip, rate limits, security headers
│   │       └── app-vhost.conf.j2        # HTTPS redirect, HSTS, proxy_pass
│   │
│   ├── postgresql/                      # ★ PostgreSQL database
│   │   ├── defaults/main.yml
│   │   ├── tasks/main.yml              # Repo, install, config, DB/user creation
│   │   ├── handlers/main.yml           # Restart / Reload
│   │   └── templates/
│   │       ├── postgresql.conf.j2       # Memory tuning, WAL, slow query logging
│   │       └── pg_hba.conf.j2           # Subnet-scoped access control
│   │
│   ├── myapp/                           # ★ Application deployment
│   │   ├── defaults/main.yml
│   │   ├── tasks/main.yml              # User, dirs, artifact, symlink, health check
│   │   ├── handlers/main.yml           # systemd reload/restart
│   │   └── templates/
│   │       ├── myapp.service.j2         # Sandboxed systemd unit
│   │       └── myapp.env.j2            # Environment file with vault secrets
│   │
│   └── backup/                          # ★ Automated S3 backups
│       ├── defaults/main.yml
│       ├── tasks/main.yml              # AWS CLI, backup script, cron
│       └── templates/
│           ├── backup-db.sh.j2          # pg_dump → gzip → S3 (STANDARD_IA)
│           └── backup-cron.j2           # Log rotation
│
├── playbooks/
│   ├── site.yml                         # Full convergence (common→web→db→app)
│   ├── deploy.yml                       # App-only rolling deployment
│   ├── patch.yml                        # OS patching with auto-reboot
│   ├── backup.yml                       # On-demand database backup
│   └── rollback.yml                     # Rollback to previous release
│
└── vault/
    ├── staging-secrets.yml              # DB password, app key, AWS creds
    └── production-secrets.yml           # ⚠️ Replace placeholders before use
```

---

## 🚀 Quick Start

```bash
# 1. Setup vault password
echo "your-strong-password" > .vault-pass && chmod 600 .vault-pass

# 2. Encrypt secrets
ansible-vault encrypt vault/staging-secrets.yml --vault-password-file .vault-pass

# 3. (Optional) Spin up local Vagrant lab
vagrant up

# 4. Test connectivity
ansible all -i inventories/staging/hosts.ini -m ping

# 5. Full infrastructure setup
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass

# 6. Deploy app only
ansible-playbook -i inventories/staging/hosts.ini playbooks/deploy.yml \
  --vault-password-file .vault-pass -e "app_version=1.2.0"
```

---

## 🎯 Playbook Commands

| Playbook | Purpose | Command |
|----------|---------|---------|
| `site.yml` | Full infra convergence | `ansible-playbook playbooks/site.yml -i inventories/<env>/hosts.ini` |
| `deploy.yml` | App-only (rolling) | `... playbooks/deploy.yml -e "app_version=1.3.0"` |
| `patch.yml` | OS security patching | `... playbooks/patch.yml --limit web` |
| `backup.yml` | On-demand DB backup | `... playbooks/backup.yml` |
| `rollback.yml` | Rollback to release | `... playbooks/rollback.yml -e "rollback_release=20260614T120000"` |

> Always add `--vault-password-file .vault-pass`. For production, always `--check --diff` first.

---

## 🔐 Production-Grade Features

| Feature | Implementation |
|---------|---------------|
| **SSH Hardening** | Modern ciphers only, key-only auth, non-standard port |
| **Firewall (UFW)** | Deny-all default, explicit per-role rules |
| **fail2ban** | SSH + DDoS jails, 24h bans in production |
| **Kernel Hardening** | 11 sysctl security parameters |
| **Auto-patching** | unattended-upgrades enabled |
| **TLS** | HTTPS redirect, HSTS, TLS 1.2/1.3 only |
| **Secrets Encryption** | Ansible Vault (AES-256), per-environment |
| **Rolling Deployment** | `serial: 1` with health checks |
| **Release Management** | Capistrano-style symlinked releases, cleanup |
| **Health Checks** | HTTP health probe with retries before declaring success |
| **Rollback** | Instant symlink switch + health validation |
| **Automated Backups** | pg_dump → gzip → S3 STANDARD_IA with cron |
| **Log Rotation** | Application + backup logs, compressed |
| **Idempotency** | Safe to run repeatedly without side effects |
| **Systemd Sandboxing** | NoNewPrivileges, ProtectSystem, PrivateTmp |
| **Environment Separation** | Staging vs Production configs, variables, secrets |
