# TLS Setup (Let's Encrypt via Certbot + Nginx)

These steps add HTTPS to the Glassleaf deployment on Ubuntu 18+.

## 0) Prereqs
- A/AAAA DNS records for your domain pointing to the server IP (e.g., `yourdomain.com`, optionally `www`).
- Nginx site already working in HTTP (from `DEPLOY_UBUNTU18.md`).

## 1) Open firewall
```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'   # opens 80 and 443
sudo ufw status
```

## 2) Install Certbot (snap)
```bash
sudo apt update
sudo apt install -y snapd
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

## 3) Update Nginx `server_name`
Edit your Nginx config to match your domain (no TLS yet):
```
/etc/nginx/sites-available/glassleaf
    server_name yourdomain.com www.yourdomain.com;
```
Reload Nginx:
```bash
sudo nginx -t && sudo systemctl reload nginx
```

## 4) Obtain & install certificate
Let Certbot modify Nginx and install certificates automatically:
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```
Follow the prompts and choose the redirect option when asked.

> If you prefer a manual template, see `ops/nginx.glassleaf.tls.template.conf` and adjust the
> `ssl_certificate` paths that Certbot creates under `/etc/letsencrypt/live/<yourdomain>/`.

## 5) Verify
Visit: `https://yourdomain.com` — padlock should be valid.
Check auto-renew timer:
```bash
systemctl status snap.certbot.renew.service
sudo certbot renew --dry-run
```

## 6) (Optional) Add HSTS
After confirming HTTPS works and you won't need HTTP, enable HSTS in your 443 server block:
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## 7) Renewal & Reload
Certbot installs a systemd timer that renews certificates and reloads Nginx automatically.
You can also add a deploy hook:
```bash
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
echo '#!/bin/sh' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh >/dev/null
echo 'systemctl reload nginx' | sudo tee -a /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh >/dev/null
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

## Troubleshooting
- **Challenge fails**: Ensure ports 80/443 are open and `server_name` matches the requested domain.
- **Mixed content**: Make sure all assets load over `https://` (update hardcoded links if any).
- **Renewal issues**: `sudo certbot renew --dry-run` shows detailed logs at `/var/log/letsencrypt/`.
