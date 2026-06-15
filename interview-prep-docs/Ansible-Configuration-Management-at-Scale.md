# Building Configuration Management at Scale with Ansible

> **Source:** [Medium — Arvind Verma](https://medium.com/@arvindverma021/building-configuration-management-at-scale-with-ansible-6aebc381414b) | **Date:** May 28, 2026
>
> A Real-World DevOps Automation Project Walkthrough for Production Server Management

---

## 📌 Why This Matters

The biggest problem in infrastructure engineering isn't deployment — it's **consistency**.

Whether you have 3 servers or 3,000, every one needs: security hardening, software installation, application configuration, patching, secrets management, backups, and logging.

**Without automation → configuration drift:**

| Server | Problem |
|--------|---------|
| Server A | NGINX version 1.22 |
| Server B | NGINX version 1.18 |
| Server C | Missing firewall rules |

Result: apps behave differently across environments, debugging becomes painful, outages and security risks multiply.

---

## 🧠 Key Concepts

### What is Configuration Management?
Automatically configuring infrastructure consistently — defining server configuration **as code** instead of manual setup.

**Benefits:** Repeatability · Consistency · Reliability · Scalability

### What is Ansible?
An agentless automation tool for server configuration, app deployment, infrastructure automation, and orchestration.

**Why companies love it:**
- ✅ **Agentless** — no agents needed on servers
- ✅ **Simple YAML syntax** — easy to read and write
- ✅ **SSH-based** — lightweight, easy to adopt, operationally simple

### What is Idempotency?
Running automation multiple times produces the **same result safely**. Ansible changes only what is necessary — repeated runs won't break infrastructure, duplicate configs, or create instability.

---

## 🏗️ Architecture Overview

```
            Ansible Control Node
                     ↓
     ┌───────────────┼───────────────┐
     ↓               ↓               ↓
  Web VM          App VM          DB VM
     ↓               ↓               ↓
   NGINX           MyApp         PostgreSQL
```

**Additional automation layers:** Firewall hardening · S3 backups · Logging · Secrets management · Patch automation

---

## 🛠️ Technologies Used

| Tool | Purpose |
|------|---------|
| **Ansible** | Core automation engine — config mgmt, orchestration, deployments, patching |
| **NGINX** | Reverse proxy, load balancer, frontend web server |
| **PostgreSQL** | Application database — persistent, reliable storage |
| **Ansible Vault** | Encrypts passwords, secrets, API keys, credentials |
| **AWS S3** | Stores backups, logs, and artifacts |

---

## 📁 Project Structure

```text
ansible-lab/
├── inventories/
│   ├── staging/
│   │   ├── hosts.ini
│   │   └── group_vars/
│   │       └── all.yml
│   └── production/
│       ├── hosts.ini
│       └── group_vars/
│           └── all.yml
├── roles/
│   ├── common/          # Security hardening, base packages
│   ├── nginx/           # Web server configuration
│   ├── postgresql/      # Database setup
│   └── myapp/           # Application deployment
├── playbooks/
│   ├── site.yml         # Full infrastructure setup
│   ├── deploy.yml       # App-only deployment
│   └── patch.yml        # Patching playbook
└── vault/
    └── secrets.yml      # Encrypted secrets
```

**Why this structure matters:** Reusable automation · Production organization · Environment separation · Modular infrastructure

---

## 🚀 Step-by-Step Implementation

### Step 1: Create Virtual Machines

Use AWS EC2, VirtualBox, Vagrant, or Azure VMs. For learning, **Vagrant is excellent**.

> 💡 Real systems contain web servers, app servers, and databases. Multiple VMs simulate production architecture.

---

### Step 2: Install Ansible

On the control node (the machine that runs Ansible and sends commands to target servers):

```bash
sudo apt update
sudo apt install ansible -y
ansible --version
```

---

### Step 3: Configure SSH Access

```bash
# Generate SSH key
ssh-keygen

# Copy key to each server
ssh-copy-id user@server-ip
```

> 💡 Automation should not stop waiting for manual passwords. SSH keys enable secure automated access.

---

### Step 4: Create Inventory File

Create `inventories/staging/hosts.ini`:

```ini
[web]
192.168.56.10

[db]
192.168.56.11

[app]
192.168.56.12
```

> 💡 **Inventory** defines which servers Ansible manages — a fundamental Ansible concept.

---

### Step 5: Test Connectivity

```bash
ansible all -i inventories/staging/hosts.ini -m ping
```

Expected output: `pong`

This verifies SSH connectivity, remote access, and server reachability.

---

### Step 6: Create Common Role

```bash
ansible-galaxy init roles/common
```

> 💡 **Roles** organize automation logically into reusable components instead of giant monolithic playbooks.

---

### Step 7: Configure Server Hardening (UFW Firewall)

In `roles/common/tasks/main.yml`:

```yaml
- name: Install UFW
  apt:
    name: ufw
    state: present
```

> 💡 Firewalls restrict unauthorized traffic — a fundamental security practice.

---

### Step 8: Configure fail2ban

```yaml
- name: Install fail2ban
  apt:
    name: fail2ban
    state: present
```

> 💡 **fail2ban** protects against brute-force attacks, especially important for SSH security.

---

### Step 9: Configure Unattended Upgrades

```yaml
- name: Install unattended-upgrades
  apt:
    name: unattended-upgrades
    state: present
```

> 💡 Outdated servers become vulnerable. Automatic security patching ensures updates happen consistently.

---

### Step 10: Configure NGINX Role

```bash
ansible-galaxy init roles/nginx
```

```yaml
- name: Install nginx
  apt:
    name: nginx
    state: present
```

> 💡 NGINX handles routing, TLS termination, load balancing, and frontend traffic — critical in production.

---

### Step 11: Configure PostgreSQL Role

```bash
ansible-galaxy init roles/postgresql
```

```yaml
- name: Install PostgreSQL
  apt:
    name: postgresql
    state: present
```

> ⚠️ Applications should **never** use root database access. Always use least-privilege accounts.

---

### Step 12: Configure Application Deployment

```bash
ansible-galaxy init roles/myapp
```

```yaml
- name: Copy application
  copy:
    src: app/
    dest: /opt/myapp/
```

---

### Step 13: Configure systemd Service

```yaml
- name: Start application
  systemd:
    name: myapp
    state: started
    enabled: yes
```

> 💡 **systemd** is the Linux service manager — controls starting, restarting, and auto-start on boot.

---

### Step 14: Configure Log Rotation

```yaml
- name: Install logrotate
  apt:
    name: logrotate
    state: present
```

> 💡 Without rotation, logs grow endlessly until disks become full. Production systems always rotate logs.

---

### Step 15: Configure Backups to S3

Install AWS CLI, create backup script, and upload:

```bash
aws s3 cp backup.sql s3://my-backups/
```

> ⚠️ Infrastructure eventually fails. Without backups, data loss becomes catastrophic. Backups are **mandatory** in production.

---

### Step 16: Encrypt Secrets with Ansible Vault

Create `vault/secrets.yml`, then encrypt:

```bash
ansible-vault encrypt vault/secrets.yml
```

> 🔐 **Never** store passwords in plaintext. Vault encrypts secrets securely — a core DevSecOps concept.

---

### Step 17: Create Main Playbook

Create `playbooks/site.yml`:

```yaml
- hosts: all
  roles:
    - common
    - nginx
    - postgresql
    - myapp
```

> 💡 A **playbook** defines the automation workflow — it orchestrates roles, tasks, and deployments.

---

### Step 18: Run Full Automation

```bash
ansible-playbook \
  -i inventories/staging/hosts.ini \
  playbooks/site.yml \
  --vault-password-file .vault-pass
```

This single command: configures servers, installs packages, deploys applications, and secures infrastructure — **automatically**.

---

### Step 19: Run App-Only Deployment

```bash
ansible-playbook \
  -i inventories/production/hosts.ini \
  playbooks/deploy.yml \
  --tags "deploy" \
  --vault-password-file .vault-pass
```

> 💡 **Tags** allow partial automation execution without rerunning the entire infrastructure setup — very useful in production.

---

### Step 20: Understand Idempotency

Running the same playbook multiple times:
- ✅ Produces the same result safely
- ✅ Changes only what is necessary
- ❌ Won't break infrastructure
- ❌ Won't duplicate configurations

This is a **foundational automation principle**.

---

## 📋 Quick Reference — Essential Commands

| Action | Command |
|--------|---------|
| Install Ansible | `sudo apt install ansible -y` |
| Check version | `ansible --version` |
| Generate SSH key | `ssh-keygen` |
| Copy SSH key | `ssh-copy-id user@server-ip` |
| Test connectivity | `ansible all -i inventories/staging/hosts.ini -m ping` |
| Create a role | `ansible-galaxy init roles/<role-name>` |
| Encrypt secrets | `ansible-vault encrypt vault/secrets.yml` |
| Decrypt secrets | `ansible-vault decrypt vault/secrets.yml` |
| Edit encrypted file | `ansible-vault edit vault/secrets.yml` |
| Run full playbook | `ansible-playbook -i <inventory> playbooks/site.yml --vault-password-file .vault-pass` |
| Run with tags | `ansible-playbook -i <inventory> playbooks/deploy.yml --tags "deploy"` |
| Dry run (check mode) | `ansible-playbook -i <inventory> playbooks/site.yml --check` |

---

## 🎯 What You Built

| Component | Status |
|-----------|--------|
| Production configuration management platform | ✅ |
| Infrastructure automation workflow | ✅ |
| Secrets management system (Vault) | ✅ |
| Scalable server provisioning architecture | ✅ |
| Security hardening (UFW, fail2ban, auto-patching) | ✅ |
| Web server (NGINX) | ✅ |
| Database (PostgreSQL) | ✅ |
| Application deployment (systemd) | ✅ |
| Log rotation | ✅ |
| S3 backups | ✅ |

---

> **This is real DevOps engineering — not just deploying apps, but automating the entire server lifecycle.** 🚀
