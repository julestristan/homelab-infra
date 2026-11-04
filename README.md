# Infra VPS — julestristan.fr

Server config:
reverse-proxy + TLS via Traefik, blog and Ansible setup.

```
.
├── Makefile              # shortcuts (make help)
├── ansible/              # server config : SSH, UFW, fail2ban, Docker
├── traefik/              # reverse-proxy, Let's Encrypt, headers de sécurité
│   ├── compose.yaml
│   ├── dynamic.yml       # middlewares + options TLS (rechargé à chaud)
│   ├── .env              # ACME_EMAIL, ACME_CASERVER   (non versionné)
│   └── letsencrypt/      # acme.json                    (non versionné)
└── blog/                 # Ghost 5 (SQLite)
    ├── compose.yaml
    ├── .env              # GHOST_URL, BLOG_HOST         (non versionné)
    └── content/          # données + thèmes + images    (non versionné)
```

## To Install

- Docker + plugin Compose v2
- `make` (`sudo apt install make`) — or `docker compose`
- DNS : `julestristan.fr` → IP VPS
- Ports 80 and 443 open on FW

## Init

```bash
cp traefik/.env.example traefik/.env   # puis éditer
cp blog/.env.example   blog/.env       # puis éditer

make up        # Create "web" internal docker network + run docker services
make ps
```

## Dashboard Traefik

Expose on `127.0.0.1:8080` (jamais public). From local:

```bash
ssh -L 8080:localhost:8080 <vps>
# and http://localhost:8080/dashboard/
```

## Operations available

| Commande | Effet |
|---|---|
| `make up` / `make down` | start / stop a service |
| `make restart` | restart all |
| `make pull` | update docker images |
| `make logs S=blog` | follow logs |
| `make ps` | container status |

## Notes

- Voir pourquoi le routing en interne est bloqué
- Ajouter règle firewall IPv6 sur la box pour router les demandes HTTP / HTTPS (voir pour NAT loopback)
- Whitelist le port 22 de la box internet pour connexion SSH externe (done)

![](./img/allow-http&https.png)
![](./img/allow-ssh.png)

## Security

Configuration in `ansible/` :

- **SSH** connexion par clé uniquement, mot de passe désactivé
- **fail2ban** jail `sshd` : `maxretry = 3`, `bantime = 1d`, réseau local exempté
- **UFW** seuls les ports `22/tcp` (SSH), `80/tcp` (HTTP) et `443/tcp` (HTTPS) sont ouverts en entrée

> Les ports publiés par Docker contournent UFW : ne publier sur `0.0.0.0` que ce qui doit
> être public, et lier le reste à `127.0.0.1` (comme le dashboard Traefik).

## Ansible

Le playbook décrit la configuration du serveur. Il est idempotent : relancé sur un serveur
conforme, il ne change rien. Il se lance depuis le poste de travail, en SSH par clé.

| Rôle | Effet |
|---|---|
| `common` | Paquets de base, mises à jour de sécurité automatiques, utilisateur dans `sudo` |
| `ssh_hardening` | Connexion par clé uniquement, validation avec `sshd -t` avant rechargement |
| `firewall` | UFW : autorise SSH en premier, puis 80 et 443, refuse le reste en entrée |
| `fail2ban` | Jail `sshd` |
| `docker` | Dépôt officiel, Docker et plugin Compose, sans mise à niveau forcée |

### Lancer le playbook

```bash
brew install ansible                                         # sur macOS
ansible-galaxy collection install -r ansible/requirements.yml

make ansible-check    # dry-run : affiche les changements sans rien appliquer
make ansible-apply    # applique, après relecture du check
```

Le mot de passe `sudo` est demandé au lancement. Pour un seul rôle :
`cd ansible && ansible-playbook site.yml --check --diff --ask-become-pass --tags firewall`.

Pour ajouter un nœud, le déclarer dans `ansible/inventory/hosts.yml`, sous le groupe `homelab`.

### Secrets

Aucun secret n'est versionné, et le playbook n'en a pas besoin pour l'instant. Si cela change :
`ansible-vault encrypt_string`, avec le mot de passe du vault dans `ansible/.vault_pass` (ignoré par Git).
