# Homelab Infrastructure — julestristan.fr

[![ansible-lint](https://github.com/julestristan/homelab-infra/actions/workflows/ansible-lint.yml/badge.svg)](https://github.com/julestristan/homelab-infra/actions/workflows/ansible-lint.yml)

Configuration of my homelab server: SSH hardening and provisioning with Ansible,
reverse proxy with automatic TLS via Traefik, and a self-hosted blog.

```
.
├── Makefile              # shortcuts (make help)
├── ansible/              # server config: SSH, UFW, fail2ban, Docker
├── traefik/              # reverse proxy, Let's Encrypt, security headers
│   ├── compose.yaml
│   ├── dynamic.yml       # middlewares + TLS
│   ├── .env              # ACME_EMAIL, ACME_CASERVER
│   └── letsencrypt/      # acme.json
└── blog/                 # optional, separate repo: Blog based on Hugo
```

The blog can be found in its own repository: **[julestristan/blog](https://github.com/julestristan/blog)**.
It is cloned into `blog/` (git-ignored here) and picked up automatically by the Makefile when present.

## Requirements

- Docker + Compose v2 plugin
- `make` (`sudo apt install make`), or plain `docker compose`
- DNS: `julestristan.fr` → Server running on a docker container
- Ports 80 and 443 open on the router/firewall

## Getting started

```bash
cp traefik/.env.example traefik/.env   # then edit

# Optional: blog stack
git clone https://github.com/julestristan/blog.git blog
cp blog/.env.example blog/.env         # then edit

make up        # create the shared "web" Docker network, then start the containers
make ps
```

Stacks are started in order (`traefik`, then `blog`); any stack whose `compose.yaml` is missing is skipped.

## Traefik dashboard

Bound to `127.0.0.1:8080` only (never exposed publicly). Access it through an SSH tunnel:

```bash
ssh -L 8080:localhost:8080 <homelab>
# then open http://localhost:8080/dashboard/
```

## Operations

| Command | Effect |
|---|---|
| `make up` / `make down` | Start / stop the stacks |
| `make restart` | Restart all stacks |
| `make pull` | Pull updated Docker images |
| `make logs S=blog` | Follow logs of a stack (default: `traefik`) |
| `make ps` | Container status |

## Network notes

- Investigate why internal routing (NAT loopback) is blocked
- Add an IPv6 firewall rule on the ISP router to forward HTTP/HTTPS
- Allow port 22 on the ISP router for external SSH access (done)

![Router rule: allow HTTP and HTTPS](./img/allow-http&https.png)
![Router rule: allow SSH](./img/allow-ssh.png)

## Security

Configured in `ansible/`:

- **SSH**: key-based authentication only, password login disabled, root login and X11 forwarding disabled
- **fail2ban**: `sshd` jail with `maxretry = 3`, `bantime = 1d`, local network whitelisted
- **UFW**: only `22/tcp` (SSH), `80/tcp` (HTTP) and `443/tcp` (HTTPS) allowed inbound

**IMPORTANT**: Docker-published ports bypass UFW rules. Be careful when binding containers to `0.0.0.0`.

## Ansible

The playbook describes the server configuration. It is idempotent: running it against a compliant
server changes nothing.

| Role | Effect |
|---|---|
| `common` | Base packages, unattended security upgrades, admin user in `sudo` |
| `ssh_hardening` | Key-only authentication, config validated with `sshd -t` before reload |
| `firewall` | UFW: allow SSH first, then 80 and 443, deny all other inbound traffic |
| `fail2ban` | `sshd` jail |
| `docker` | Official Docker repository, Docker Engine and Compose plugin, no forced upgrades |

### Running the playbook

```bash
brew install ansible
ansible-galaxy collection install -r ansible/requirements.yml

make ansible-check    # dry run: show changes without applying them
make ansible-apply    # apply, after reviewing the output from the previous check
```

Run a single role with its tag (`sudo` password required):

```bash
cd ansible && ansible-playbook site.yml --check --diff --ask-become-pass --tags firewall
```

To add a node (host), declare it in `ansible/inventory/hosts.yml`.