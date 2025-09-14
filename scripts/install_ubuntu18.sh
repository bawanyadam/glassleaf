#!/usr/bin/env bash
# Automates non-Docker install on Ubuntu 18+
# Usage: sudo bash scripts/install_ubuntu18.sh /opt/glassleaf

set -euo pipefail

PREFIX="${1:-/opt/glassleaf}"

echo "[1/6] Installing system packages…"
apt update
apt install -y software-properties-common curl wget nginx

echo "[2/6] Installing Python 3.10 (deadsnakes)…"
add-apt-repository -y ppa:deadsnakes/ppa || true
apt update
apt install -y python3.10 python3.10-venv python3.10-distutils
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

echo "[3/6] Installing Calibre (ebook-convert)…"
wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin

echo "[4/6] Placing app at $PREFIX …"
mkdir -p "$PREFIX"
cp -r backend "$PREFIX/"
cp -r frontend "$PREFIX/"
cp API.md OUTPUT_FORMAT.md DEPLOY_UBUNTU18.md "$PREFIX/"
mkdir -p "$PREFIX/ops"
cp ops/nginx.glassleaf.conf "$PREFIX/ops/"

echo "[5/6] Python deps…"
python3.10 -m venv "$PREFIX/backend/.venv"
source "$PREFIX/backend/.venv/bin/activate"
pip install --upgrade pip
pip install -r "$PREFIX/backend/requirements.txt"

echo "[6/6] systemd service…"
cat >/etc/systemd/system/glassleaf.service <<'UNIT'
[Unit]
Description=Glassleaf EPUB→PDF API (FastAPI)
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=__PREFIX__/backend
Environment="PATH=__PREFIX__/backend/.venv/bin"
ExecStart=__PREFIX__/backend/.venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

sed -i "s#__PREFIX__#${PREFIX}#g" /etc/systemd/system/glassleaf.service
systemctl daemon-reload
systemctl enable --now glassleaf

echo "Place Nginx config and reload:"
echo "  cp $PREFIX/ops/nginx.glassleaf.conf /etc/nginx/sites-available/glassleaf"
echo "  ln -s /etc/nginx/sites-available/glassleaf /etc/nginx/sites-enabled/glassleaf"
echo "  nginx -t && systemctl reload nginx"
echo "Done. Open http://<server>/"
