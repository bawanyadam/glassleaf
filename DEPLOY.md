# Deploy on Ubuntu (FastAPI + Calibre + Nginx)

## 1) System Packages
```bash
sudo apt update
# Install Python and Calibre (provides 'ebook-convert')
sudo apt install -y python3 python3-venv python3-pip calibre nginx
```

> If your Ubuntu doesn't have a recent Calibre, use the official installer:
```bash
sudo -v
wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin
```

## 2) App Files
Upload the project folder to e.g. `/opt/epub2pdf`:
```
/opt/epub2pdf/
  backend/
    app.py
    requirements.txt
  frontend/
    index.html
  API.md
```
Create a virtualenv and install deps:
```bash
cd /opt/epub2pdf/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 3) Run Backend (Uvicorn) with systemd
Create `/etc/systemd/system/epub2pdf.service`:
```ini
[Unit]
Description=EPUB to PDF API (FastAPI)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/opt/epub2pdf/backend
Environment="PATH=/opt/epub2pdf/backend/.venv/bin"
ExecStart=/opt/epub2pdf/backend/.venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now epub2pdf
sudo systemctl status epub2pdf
```

## 4) Nginx (serve SPA + reverse proxy /api)
Create `/etc/nginx/sites-available/epub2pdf`:
```nginx
server {
    listen 80;
    server_name yourdomain.com;

    root /opt/epub2pdf/frontend;
    index index.html;

    location / {
        try_files $uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 600s;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/epub2pdf /etc/nginx/sites-enabled/epub2pdf
sudo nginx -t
sudo systemctl reload nginx
```

## 5) Test
- Visit `http://yourdomain.com/` and upload a `.epub` file.
- Check health: `curl http://yourdomain.com/api/health`

## 6) Notes & Ops
- Temp files live under `/tmp/epub2pdf/{task_id}` and expire after 30 min.
- Adjust CORS in `app.py` if frontend is on a different origin.
- Increase workers in systemd `ExecStart` if needed.
