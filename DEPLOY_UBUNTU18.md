# Deploy on Ubuntu 18+ (No Docker)

These steps are tailored for **Ubuntu 18.04 (bionic)** and later. Ubuntu 18 ships with Python 3.6; this app needs Python **3.10+**. We’ll install Python 3.10 via Deadsnakes, Calibre via the official installer, and run the FastAPI app behind Nginx.

> If you’re on Ubuntu 20.04+ (has Python ≥3.8), you can still follow this guide but you may skip the Deadsnakes step and install Python 3.10/3.11 via `deadsnakes` or use pyenv.

---

## 1) System prep (root or sudo)
```bash
sudo apt update
sudo apt install -y software-properties-common curl wget nginx
# Python 3.10 via deadsnakes (for Ubuntu 18/older releases)
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update
sudo apt install -y python3.10 python3.10-venv python3.10-distutils
# ensure pip for 3.10
curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.10
```

## 2) Install Calibre (provides `ebook-convert`)
Calibre’s official installer works well across Ubuntu versions:
```bash
sudo -v
wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
# Verify:
which ebook-convert && ebook-convert --version
```
> If you prefer apt packages instead: `sudo apt install -y calibre` (version may be older).

## 3) Place app files
Copy the project into `/opt/glassleaf` (or your chosen name).
```
/opt/glassleaf/
  backend/
    app.py
    requirements.txt
  frontend/
    index.html
  API.md
  DEPLOY_UBUNTU18.md
  OUTPUT_FORMAT.md
  ops/nginx.glassleaf.conf
  scripts/install_ubuntu18.sh
```
Create the virtualenv and install deps:
```bash
cd /opt/glassleaf/backend
python3.10 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 4) Systemd service
Create `/etc/systemd/system/glassleaf.service` (adjust user/group if desired):
```ini
[Unit]
Description=Glassleaf EPUB→PDF API (FastAPI)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/glassleaf/backend
Environment="PATH=/opt/glassleaf/backend/.venv/bin"
ExecStart=/opt/glassleaf/backend/.venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now glassleaf
sudo systemctl status glassleaf
```

## 5) Nginx (serve SPA + reverse proxy /api)
Use the provided config (edit `server_name` and path if you changed the install dir):
```bash
sudo cp /opt/glassleaf/ops/nginx.glassleaf.conf /etc/nginx/sites-available/glassleaf
sudo ln -s /etc/nginx/sites-available/glassleaf /etc/nginx/sites-enabled/glassleaf
sudo nginx -t
sudo systemctl reload nginx
```

## 6) Firewall (optional)
```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
sudo ufw status
```

## 7) Test
- Open `http://<your-domain>` to use the UI.
- API health: `curl http://<your-domain>/api/health` (should show `"ok": true`).

## 8) Upgrades & maintenance
```bash
# Pull new code, then:
cd /opt/glassleaf/backend
source .venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart glassleaf
```

### Troubleshooting
- **ebook-convert not found**: Ensure Calibre installed; check `which ebook-convert`. The app exposes `/api/health` which reports the resolved path.
- **Permission issues writing /tmp**: Ensure service user (`www-data`) can write to system temp; default is fine.
- **Large files rejected**: Max upload is 100 MB by design. You can change `MAX_BYTES` in `app.py`.
