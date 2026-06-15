# Runbook — Ansible Configuration Management

> **Version:** 1.0  
> **Last Updated:** June 2026  
> **Owner:** DevOps / Platform Engineering Team  
> **Audience:** On-call Engineers, DevOps Engineers

---

## ⚠️ Before You Begin

- Always run `--check --diff` (dry-run) **before** applying to production
- Always source vault: append `--vault-password-file .vault-pass` to every command
- Working directory for all commands: `ansible-config-mgmt/`
- For production changes, get approval via your change management process

---

## 📋 Table of Contents

1. [Environment Setup](#1-environment-setup)
2. [Day-to-Day Operations](#2-day-to-day-operations)
3. [Full Infrastructure Deployment](#3-full-infrastructure-deployment)
4. [Application Deployment](#4-application-deployment)
5. [Rolling Back a Deployment](#5-rolling-back-a-deployment)
6. [OS Patching](#6-os-patching)
7. [Database Backup & Restore](#7-database-backup--restore)
8. [Secrets Management](#8-secrets-management)
9. [Scaling — Adding New Servers](#9-scaling--adding-new-servers)
10. [Incident Response Procedures](#10-incident-response-procedures)
11. [Health Checks & Verification](#11-health-checks--verification)
12. [Troubleshooting Guide](#12-troubleshooting-guide)

---

## 1. Environment Setup

### 1.1 Prerequisites

```bash
# Install Ansible (>= 2.15)
pip install ansible ansible-lint

# Install required collections
ansible-galaxy collection install -r requirements.yml

# Verify
ansible --version
```

### 1.2 SSH Key Setup

```bash
# Generate dedicated Ansible SSH key
ssh-keygen -t ed25519 -C "ansible-control-$(date +%Y%m%d)" \
  -f ~/.ssh/ansible_ed25519 -N ""

# Copy to all target servers
for IP in 192.168.56.10 192.168.56.11 192.168.56.12; do
  ssh-copy-id -i ~/.ssh/ansible_ed25519.pub vagrant@${IP}
done

# Verify connectivity
ansible all -i inventories/staging/hosts.ini -m ping
```

Expected output:
```
web01 | SUCCESS => { "ping": "pong" }
app01 | SUCCESS => { "ping": "pong" }
db01  | SUCCESS => { "ping": "pong" }
```

### 1.3 Vault Password Setup

```bash
# Create vault password file
echo "your-strong-vault-password" > .vault-pass
chmod 600 .vault-pass

# Verify .vault-pass is in .gitignore (critical!)
grep ".vault-pass" .gitignore
```

### 1.4 Local Vagrant Lab (Testing Only)

```bash
# Start all 3 VMs
vagrant up

# Check VM status
vagrant status

# SSH into a specific VM
vagrant ssh web       # web server
vagrant ssh app       # app server
vagrant ssh db        # database server

# Stop without destroying
vagrant halt

# Destroy and recreate
vagrant destroy -f && vagrant up
```

---

## 2. Day-to-Day Operations

### 2.1 Quick Reference — Common Commands

```bash
# --- CONNECTIVITY ---
# Ping all hosts
ansible all -i inventories/staging/hosts.ini -m ping

# Ping only web servers
ansible web -i inventories/staging/hosts.ini -m ping

# --- FACTS ---
# Gather facts from a host
ansible web01 -i inventories/staging/hosts.ini -m setup

# Get specific fact
ansible all -i inventories/staging/hosts.ini \
  -m setup -a "filter=ansible_distribution*"

# --- AD-HOC COMMANDS ---
# Check disk space on all servers
ansible all -i inventories/staging/hosts.ini \
  -m command -a "df -h /"

# Check service status
ansible app -i inventories/staging/hosts.ini \
  -m systemd -a "name=myapp"

# Check NGINX status
ansible web -i inventories/staging/hosts.ini \
  -m command -a "systemctl status nginx"

# --- DRY-RUN ---
# Dry-run any playbook
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --check --diff
```

### 2.2 Useful Aliases

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias ansible-staging='ansible-playbook -i inventories/staging/hosts.ini --vault-password-file .vault-pass'
alias ansible-prod='ansible-playbook -i inventories/production/hosts.ini --vault-password-file .vault-pass'
alias ansible-ping-stg='ansible all -i inventories/staging/hosts.ini -m ping'
alias ansible-ping-prod='ansible all -i inventories/production/hosts.ini -m ping'
```

---

## 3. Full Infrastructure Deployment

**When to use:** First-time server provisioning, or re-converging drift.

### Staging

```bash
# Step 1: Dry-run
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --check --diff

# Step 2: Apply (review output above first)
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass

# Step 3: Verify
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --tags healthcheck
```

### Production

```bash
# Step 1: Notify team / open change ticket

# Step 2: MANDATORY dry-run
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --check --diff 2>&1 | tee /tmp/prod-dryrun.log

# Step 3: Review dry-run output
less /tmp/prod-dryrun.log

# Step 4: Apply (only after review + approval)
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass

# Step 5: Verify services
ansible all -i inventories/production/hosts.ini \
  -m command -a "systemctl is-active nginx myapp postgresql" \
  --vault-password-file .vault-pass
```

### Run Only Specific Roles (Tags)

```bash
# Only security hardening
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --tags security

# Only NGINX config update
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --tags nginx

# Only database tasks
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --tags postgresql

# Skip patching during site run
ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --skip-tags patch
```

---

## 4. Application Deployment

**When to use:** Deploying a new application version without touching infrastructure.

### Standard Deployment

```bash
# Deploy version 1.3.0 to staging
ansible-playbook -i inventories/staging/hosts.ini playbooks/deploy.yml \
  --vault-password-file .vault-pass \
  -e "app_version=1.3.0"

# Deploy to production (rolling — one host at a time)
ansible-playbook -i inventories/production/hosts.ini playbooks/deploy.yml \
  --vault-password-file .vault-pass \
  -e "app_version=1.3.0"
```

### Deploy to a Single Host (Canary)

```bash
# Deploy to one host first to validate
ansible-playbook -i inventories/production/hosts.ini playbooks/deploy.yml \
  --vault-password-file .vault-pass \
  -e "app_version=1.3.0" \
  --limit app-prod-01

# If healthy, deploy remaining hosts
ansible-playbook -i inventories/production/hosts.ini playbooks/deploy.yml \
  --vault-password-file .vault-pass \
  -e "app_version=1.3.0" \
  --limit app-prod-02
```

### Deployment Verification

```bash
# Check which release is active on each host
ansible app -i inventories/production/hosts.ini \
  -m command -a "readlink -f /opt/myapp/current"

# List available releases
ansible app -i inventories/production/hosts.ini \
  -m command -a "ls -lt /opt/myapp/releases/"

# Check application health directly
ansible app -i inventories/production/hosts.ini \
  -m uri -a "url=http://localhost:8080/health method=GET"

# Check systemd service status
ansible app -i inventories/production/hosts.ini \
  -m command -a "systemctl status myapp --no-pager"
```

---

## 5. Rolling Back a Deployment

**When to use:** After a bad deployment causes errors, degraded performance, or failed health checks.

### Step 1 — Identify Available Releases

```bash
# List releases on each app server
ansible app -i inventories/production/hosts.ini \
  -m command -a "ls -lt /opt/myapp/releases/"
```

Sample output:
```
app-prod-01 | CHANGED | rc=0 >>
20260614T140000   ← current (bad)
20260614T120000   ← previous (rollback target)
20260613T090000
```

### Step 2 — Execute Rollback

```bash
ansible-playbook -i inventories/production/hosts.ini playbooks/rollback.yml \
  --vault-password-file .vault-pass \
  -e "rollback_release=20260614T120000"
```

### Step 3 — Verify

```bash
# Confirm current symlink points to target release
ansible app -i inventories/production/hosts.ini \
  -m command -a "readlink /opt/myapp/current"

# Health check
ansible app -i inventories/production/hosts.ini \
  -m uri -a "url=http://localhost:8080/health"
```

### Emergency Manual Rollback (if Ansible is unreachable)

```bash
# SSH directly to each app server
ssh deploy@app-prod-01 -p 2222

# List releases and switch symlink
ls -lt /opt/myapp/releases/
sudo ln -sfn /opt/myapp/releases/20260614T120000 /opt/myapp/current
sudo systemctl restart myapp
curl -f http://localhost:8080/health
```

---

## 6. OS Patching

**Schedule:** Monthly for staging, quarterly for production (or immediately for critical CVEs).

### Patch All Servers

```bash
# Staging — patch all
ansible-playbook -i inventories/staging/hosts.ini playbooks/patch.yml \
  --vault-password-file .vault-pass

# Production — patch one group at a time (web first, then app, then db)
ansible-playbook -i inventories/production/hosts.ini playbooks/patch.yml \
  --vault-password-file .vault-pass --limit web

# After verifying web is healthy:
ansible-playbook -i inventories/production/hosts.ini playbooks/patch.yml \
  --vault-password-file .vault-pass --limit app

# After verifying app is healthy:
ansible-playbook -i inventories/production/hosts.ini playbooks/patch.yml \
  --vault-password-file .vault-pass --limit db
```

### Patch Without Rebooting

```bash
ansible-playbook -i inventories/production/hosts.ini playbooks/patch.yml \
  --vault-password-file .vault-pass --skip-tags reboot
```

### Check for Pending Updates (Read-only)

```bash
ansible all -i inventories/production/hosts.ini \
  -m command -a "apt list --upgradable 2>/dev/null" \
  --vault-password-file .vault-pass
```

### Check if Reboot is Required

```bash
ansible all -i inventories/production/hosts.ini \
  -m stat -a "path=/var/run/reboot-required"
```

---

## 7. Database Backup & Restore

### 7.1 Trigger On-Demand Backup

```bash
# Backup staging database now
ansible-playbook -i inventories/staging/hosts.ini playbooks/backup.yml \
  --vault-password-file .vault-pass

# Backup production database now
ansible-playbook -i inventories/production/hosts.ini playbooks/backup.yml \
  --vault-password-file .vault-pass
```

### 7.2 Verify Backup in S3

```bash
# List backups in S3
aws s3 ls s3://myapp-backups-production/production/db/ --recursive --human-readable

# Check last backup size and date
aws s3 ls s3://myapp-backups-production/production/db/ | tail -5
```

### 7.3 Restore from S3 Backup

```bash
# 1. SSH to the database server
ssh deploy@db-prod-01 -p 2222

# 2. Download the backup
aws s3 cp s3://myapp-backups-production/production/db/myapp_db-prod-01_20260614T010000.sql.gz \
  /tmp/restore.sql.gz

# 3. Decompress
gunzip /tmp/restore.sql.gz

# 4. Drop existing database (WARNING: DESTRUCTIVE!)
sudo -u postgres psql -c "DROP DATABASE myapp_production;"
sudo -u postgres psql -c "CREATE DATABASE myapp_production OWNER myapp;"

# 5. Restore
sudo -u postgres psql myapp_production < /tmp/restore.sql

# 6. Verify
sudo -u postgres psql -c "\l" | grep myapp
sudo -u postgres psql myapp_production -c "SELECT COUNT(*) FROM information_schema.tables;"

# 7. Clean up
rm -f /tmp/restore.sql
```

### 7.4 Verify Backup Cron

```bash
# Check cron is configured on DB servers
ansible db -i inventories/production/hosts.ini \
  -m command -a "crontab -l -u root"

# Check last backup log
ansible db -i inventories/production/hosts.ini \
  -m command -a "tail -20 /var/log/backup.log"
```

---

## 8. Secrets Management

### 8.1 View Encrypted Secrets

```bash
# View (decrypts in terminal — be aware of shoulder surfing!)
ansible-vault view vault/staging-secrets.yml \
  --vault-password-file .vault-pass

ansible-vault view vault/production-secrets.yml \
  --vault-password-file .vault-pass
```

### 8.2 Edit Encrypted Secrets

```bash
# Opens decrypted file in $EDITOR, re-encrypts on save
ansible-vault edit vault/production-secrets.yml \
  --vault-password-file .vault-pass
```

### 8.3 Rotate Secrets

```bash
# Step 1: Decrypt the file
ansible-vault decrypt vault/production-secrets.yml \
  --vault-password-file .vault-pass

# Step 2: Edit the file and update values
vim vault/production-secrets.yml

# Step 3: Re-encrypt
ansible-vault encrypt vault/production-secrets.yml \
  --vault-password-file .vault-pass

# Step 4: Re-deploy to push new secrets to servers
ansible-playbook -i inventories/production/hosts.ini playbooks/deploy.yml \
  --vault-password-file .vault-pass --tags config
```

### 8.4 Rotate the Vault Password

```bash
# Re-key with new password
ansible-vault rekey vault/production-secrets.yml \
  --vault-password-file .vault-pass \
  --new-vault-password-file .vault-pass-new

# Test the new password works
ansible-vault view vault/production-secrets.yml \
  --vault-password-file .vault-pass-new

# Replace old password file
mv .vault-pass-new .vault-pass
```

---

## 9. Scaling — Adding New Servers

### 9.1 Add a New Web Server

```bash
# Step 1: Add to inventory
vim inventories/production/hosts.ini
# Add under [web]:
# web-prod-03  ansible_host=10.0.1.12  ansible_user=deploy

# Step 2: Setup SSH access to the new server
ssh-copy-id -i ~/.ssh/ansible_ed25519.pub deploy@10.0.1.12

# Step 3: Test connectivity
ansible web-prod-03 -i inventories/production/hosts.ini -m ping

# Step 4: Apply only to the new host
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass \
  --limit web-prod-03

# Step 5: Verify NGINX is serving correctly
curl -k https://10.0.1.12/nginx-health
```

### 9.2 Add a New App Server

```bash
# Same pattern as web server, but:
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass \
  --limit app-prod-03 \
  --tags "common,myapp"
```

### 9.3 Add a New Database Replica

```bash
# Apply common + postgresql to new DB server
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass \
  --limit db-prod-03 \
  --tags "common,postgresql,backup"

# Note: PostgreSQL streaming replication setup requires
# additional configuration in postgresql.conf (pg_basebackup)
# Refer to PostgreSQL streaming replication docs for that step.
```

---

## 10. Incident Response Procedures

### 10.1 NGINX Down

**Symptoms:** 502/504 errors from load balancer, health check failures.

```bash
# 1. Check NGINX status
ansible web -i inventories/production/hosts.ini \
  -m command -a "systemctl status nginx --no-pager"

# 2. Check NGINX error log (last 50 lines)
ansible web -i inventories/production/hosts.ini \
  -m command -a "tail -50 /var/log/nginx/myapp_error.log"

# 3. Test NGINX config validity
ansible web -i inventories/production/hosts.ini \
  -m command -a "nginx -t"

# 4. Restart NGINX
ansible web -i inventories/production/hosts.ini \
  -m systemd -a "name=nginx state=restarted"

# 5. If config is corrupt — re-deploy NGINX config from Ansible
ansible-playbook -i inventories/production/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass --tags nginx --limit web
```

### 10.2 Application Down

**Symptoms:** NGINX returning 502, health check endpoint unreachable.

```bash
# 1. Check service status
ansible app -i inventories/production/hosts.ini \
  -m command -a "systemctl status myapp --no-pager"

# 2. Check application logs (journal)
ansible app -i inventories/production/hosts.ini \
  -m command -a "journalctl -u myapp -n 100 --no-pager"

# 3. Check application log files
ansible app -i inventories/production/hosts.ini \
  -m command -a "tail -100 /var/log/myapp/app.log"

# 4. Try restarting the service
ansible app -i inventories/production/hosts.ini \
  -m systemd -a "name=myapp state=restarted"

# 5. If still failing — rollback to last known good release
ansible app -i inventories/production/hosts.ini \
  -m command -a "ls -lt /opt/myapp/releases/"

ansible-playbook -i inventories/production/hosts.ini playbooks/rollback.yml \
  --vault-password-file .vault-pass \
  -e "rollback_release=<PREVIOUS_RELEASE_ID>"
```

### 10.3 Database Down

**Symptoms:** App servers logging DB connection errors, app returning 500s.

```bash
# 1. Check PostgreSQL status
ansible db -i inventories/production/hosts.ini \
  -m command -a "systemctl status postgresql --no-pager"

# 2. Check PostgreSQL logs
ansible db -i inventories/production/hosts.ini \
  -m command -a "tail -100 /var/log/postgresql/postgresql-$(date +%Y-%m-%d).log"

# 3. Check disk space (common cause!)
ansible db -i inventories/production/hosts.ini \
  -m command -a "df -h /"

# 4. Try restarting PostgreSQL
ansible db -i inventories/production/hosts.ini \
  -m systemd -a "name=postgresql state=restarted"

# 5. Check connections
ansible db -i inventories/production/hosts.ini \
  -m command -a "sudo -u postgres psql -c 'SELECT count(*) FROM pg_stat_activity;'"
```

### 10.4 Server Compromised / fail2ban Blocking Legitimate Traffic

```bash
# Check fail2ban status
ansible all -i inventories/production/hosts.ini \
  -m command -a "fail2ban-client status sshd"

# List banned IPs
ansible all -i inventories/production/hosts.ini \
  -m command -a "fail2ban-client status sshd | grep 'Banned IP'"

# Unban a specific IP
ansible web -i inventories/production/hosts.ini \
  -m command -a "fail2ban-client set sshd unbanip 1.2.3.4"
```

### 10.5 Disk Space Alert

```bash
# Check disk on all servers
ansible all -i inventories/production/hosts.ini \
  -m command -a "df -h /"

# Check largest directories
ansible all -i inventories/production/hosts.ini \
  -m command -a "du -sh /var/log/* /opt/myapp/releases/* 2>/dev/null | sort -rh | head -10"

# Force log rotation immediately
ansible all -i inventories/production/hosts.ini \
  -m command -a "logrotate -f /etc/logrotate.d/myapp"

# Remove old releases if disk is critical
ansible app -i inventories/production/hosts.ini \
  -m command -a "ls /opt/myapp/releases/ | head -n -3 | xargs -I{} rm -rf /opt/myapp/releases/{}"
```

---

## 11. Health Checks & Verification

### 11.1 Full System Health Check

```bash
#!/usr/bin/env bash
# Run this after any major change
ENV=${1:-staging}

echo "=== Ansible Config Mgmt Health Check === [${ENV}]"
echo ""

echo "--- Connectivity ---"
ansible all -i inventories/${ENV}/hosts.ini -m ping

echo ""
echo "--- Service Status ---"
ansible web -i inventories/${ENV}/hosts.ini \
  -m command -a "systemctl is-active nginx"
ansible app -i inventories/${ENV}/hosts.ini \
  -m command -a "systemctl is-active myapp"
ansible db -i inventories/${ENV}/hosts.ini \
  -m command -a "systemctl is-active postgresql"

echo ""
echo "--- App Health Endpoints ---"
ansible app -i inventories/${ENV}/hosts.ini \
  -m uri -a "url=http://localhost:8080/health method=GET"

echo ""
echo "--- Disk Space ---"
ansible all -i inventories/${ENV}/hosts.ini \
  -m command -a "df -h /"

echo ""
echo "--- Last Backup ---"
ansible db -i inventories/${ENV}/hosts.ini \
  -m command -a "tail -5 /var/log/backup.log"

echo ""
echo "=== Done ==="
```

Save as `scripts/health-check.sh` and run:
```bash
bash scripts/health-check.sh staging
bash scripts/health-check.sh production
```

### 11.2 Security Compliance Check

```bash
# Verify SSH hardening is active
ansible all -i inventories/production/hosts.ini \
  -m command -a "sshd -T | grep -E 'permitrootlogin|passwordauthentication|port'"

# Verify UFW is enabled
ansible all -i inventories/production/hosts.ini \
  -m command -a "ufw status verbose"

# Verify fail2ban is running
ansible all -i inventories/production/hosts.ini \
  -m command -a "systemctl is-active fail2ban"

# Verify unattended-upgrades
ansible all -i inventories/production/hosts.ini \
  -m command -a "systemctl is-active unattended-upgrades"
```

---

## 12. Troubleshooting Guide

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| `UNREACHABLE` error | SSH key not deployed / wrong user | `ssh-copy-id` to target; verify `ansible_user` in hosts.ini |
| `sudo: a password is required` | `become: true` but no sudo config | Run `users.yml` tasks first; verify `deploy` user sudoers |
| `Permission denied (publickey)` | Wrong SSH key | Verify `ssh_args` in `ansible.cfg` points to correct key |
| Vault decryption error | Wrong vault password | Verify `.vault-pass` contents; try `ansible-vault view` |
| `apt lock` error | Another apt process running | Wait and retry; check `pgrep apt` on target |
| NGINX config fails validation | Jinja2 template error | Check variable values; run `nginx -t` manually |
| PostgreSQL won't start | Config error or disk full | Check PG logs; check disk; validate `postgresql.conf` |
| Health check times out | App not started / wrong port | Check `journalctl -u myapp`; verify `app_port` variable |
| `community.general` not found | Collections not installed | `ansible-galaxy collection install community.general` |
| Fact cache stale | Old facts cached | `rm -rf /tmp/ansible_facts_cache/*` or add `--flush-cache` |
| `serial: 1` very slow | Expected behaviour | Add `--forks 1` won't help; serial is by design |
| S3 upload fails | AWS credentials not set | Check `vault_backup_aws_*` secrets; verify IAM permissions |

### Enable Verbose Debugging

```bash
# -v    = show task results
# -vv   = show file/connection details
# -vvv  = show SSH commands
# -vvvv = show connection plugins (most verbose)

ansible-playbook -i inventories/staging/hosts.ini playbooks/site.yml \
  --vault-password-file .vault-pass -vvv 2>&1 | tee /tmp/ansible-debug.log
```

### Check Ansible Version Compatibility

```bash
ansible --version
ansible-galaxy collection list
python3 --version
```

---

## 📞 Escalation Path

| Level | Who | When |
|-------|-----|------|
| L1 | On-call Engineer | Any service down; use playbooks in this runbook |
| L2 | Senior DevOps | Infrastructure-level failures; Ansible control node issues |
| L3 | Platform Architect | Data loss risk; security incident; architecture change needed |

---

> **Remember:** Every change to production should be traceable.  
> Log your actions in your incident/change management system.  
> When in doubt — dry-run first, apply second. 🛡️
