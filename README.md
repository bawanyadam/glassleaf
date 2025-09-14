# Glassleaf

**Glassleaf** — a minimalist, private single-page app for converting ePub → PDF with drag-and-drop upload, live progress polling, and expiring downloads. Built with a FastAPI backend (Calibre `ebook-convert`) and a liquid-glass inspired frontend.

---

## Table of contents
- [Quick highlights](#quick-highlights)  
- [Quick start — Docker (recommended for dev/test)](#quick-start--docker-recommended-for-devtest)  
- [Quick start — Native Ubuntu 18+ (no Docker)](#quick-start--native-ubuntu-18-no-docker)  
- [How it works / Usage](#how-it-works--usage)  
- [API](#api)  
- [Configuration & tuning](#configuration--tuning)  
- [Security & privacy](#security--privacy)  
- [Troubleshooting](#troubleshooting)  
- [Contributing](#contributing)  
- [License & acknowledgements](#license--acknowledgements)

---

# Quick highlights
- Drag-and-drop or file picker upload for `.epub` files.  
- Animated progress bar updated by polling `/api/progress/{task_id}` every 2s.  
- Uses Calibre’s `ebook-convert` for reliable ePub→PDF rendering.  
- Temporary per-task storage; converted files expire (default 30 minutes).  
- Both Docker and native Ubuntu deployment instructions included.

---

# Quick start — Docker (recommended for a fast local dev run)
1. Unpack repo and `cd` into it:
```bash
unzip epub2pdf-dockerized-armfix.zip -d ~/glassleaf
cd ~/glassleaf
```
2. Build & start with Compose:
```bash
docker compose up -d --build
```
3. Open the UI:
```
http://localhost:8080
```
Notes:
- On Apple Silicon (M1/M2/M4) Docker Desktop sets `TARGETARCH=arm64` automatically; the backend Dockerfile installs Calibre via the distro package on arm64. If you want to force architecture builds, see `DEPLOY_DOCKER.md`.

---

# Quick start — Native Ubuntu 18+ (no Docker)
(If you plan to run on a server, follow these steps.)

1. Copy files to the server, e.g. `/opt/glassleaf`.
2. Run the included installer (installs Python 3.10, Calibre, venv, creates systemd service):
```bash
sudo bash scripts/install_ubuntu18.sh /opt/glassleaf
```
3. Place the Nginx site file and enable it:
```bash
sudo cp /opt/glassleaf/ops/nginx.glassleaf.conf /etc/nginx/sites-available/glassleaf
sudo ln -s /etc/nginx/sites-available/glassleaf /etc/nginx/sites-enabled/glassleaf
sudo nginx -t && sudo systemctl reload nginx
```
4. Open in browser:
```
http://your-server-or-domain/
```
For TLS, see `DEPLOY_TLS.md` — it walks through Certbot + Nginx steps.

---

# How it works / Usage
1. Open the SPA in your browser.  
2. Drag a `.epub` file into the panel or use *Choose File*. Max file size: **100 MB** (configurable).  
3. The frontend posts the file to `POST /api/convert` and receives a `task_id`.  
4. The frontend polls `GET /api/progress/{task_id}` every 2 seconds to update the progress bar and status message.  
5. When conversion completes the response includes a `download_url`. Click the download button to retrieve the PDF. The download link expires after the configured TTL.

---

# API

All endpoints return JSON unless serving the PDF file.

### POST `/api/convert`
Start a conversion. Accepts `multipart/form-data` with field `file`.

**Request (curl):**
```bash
curl -F "file=@/path/to/book.epub" https://yourdomain/api/convert
```

**Success (200):**
```json
{ "task_id": "string" }
```

**Errors (example):**
```json
{ "error": "Unsupported file type. Only .epub is allowed.", "code": 415 }
```

---

### GET `/api/progress/{task_id}`
Poll every 2s to get progress and status.

**Success (processing):**
```json
{ "progress": 42, "status": "processing", "message": "Converting…" }
```

**Success (complete):**
```json
{
  "progress": 100,
  "status": "complete",
  "message": "Complete",
  "download_url": "/api/download/{task_id}",
  "expires_in": 1799
}
```

**Error (task not found):**
```json
{ "error": "Task not found.", "code": 404 }
```

---

### GET `/api/download/{task_id}`
When task is `complete`, returns the PDF binary with `Content-Type: application/pdf`.  
If the task is not ready: `{"error":"Not ready","code":425}`. If expired: `{"error":"File has expired.","code":410}`.

---

### GET `/api/health`
Simple health check for service and `ebook-convert` availability:
```json
{ "ok": true, "ebook_convert": "/path/to/ebook-convert", "tmp": "/tmp/epub2pdf" }
```

---

### Error response shape (all endpoints)
```json
{ "error": "message", "code": 413 }
```
Common codes:
- `413` — file too large  
- `415` — unsupported file type  
- `404` — task not found  
- `410` — file expired  
- `425` — not ready (download before completion)  
- `500` — conversion failed or Calibre missing

---

# Configuration & tuning
Primary server-side settings live in `backend/app.py`:
- `MAX_BYTES` — max upload in bytes (default `100 * 1024 * 1024`)  
- `DOWNLOAD_TTL_SECONDS` — how long converted files remain downloadable (default 1800s = 30 min)  
- `BASE_TMP` — tmp directory (default system temp under `/tmp/epub2pdf`)  
- `EBOOK_CONVERT_BIN` — resolved path to `ebook-convert` (auto-detected or can be overridden)

Adjust `uvicorn` workers and service user in the systemd unit / Docker Compose as needed.

---

# Security & privacy
- Files are written to **per-task temporary directories** and deleted after `expires_in`.  
- The app is intended for **single-user / private** usage; if exposing publicly, run behind HTTPS (see `DEPLOY_TLS.md`) and consider:
  - Restricting CORS to your domain in `app.py`
  - Adding authentication (e.g., simple HTTP auth or reverse proxy auth)
  - Rate limiting uploads (proxy or WSGI middleware) if public

---

# Troubleshooting
- **`ebook-convert` not found**: Ensure Calibre is installed and `which ebook-convert` returns a path. On Ubuntu, `wget ...linux-installer.sh | sudo sh /dev/stdin` will install it; Docker builds install Calibre per architecture instructions.  
- **Upload rejected (413)**: File larger than `MAX_BYTES`. Increase value in `app.py` if needed.  
- **Permission errors writing temp files**: Ensure service user (e.g., `www-data`) has write access to system temp (default is writable).  
- **Nginx 502/503**: Confirm backend is running (`systemctl status glassleaf` or `docker compose logs backend`) and that proxy_pass matches backend address/port.  
- **TLS issues**: See `DEPLOY_TLS.md` for Certbot debugging steps (`sudo certbot renew --dry-run`).

---

# Contributing
Thanks for helping make Glassleaf better!

Suggested workflow:
```bash
git checkout -b feat/your-feature
# make changes
git add .
git commit -m "feat: short description"
git push origin feat/your-feature
# open a PR on GitHub and request reviews
```
Please run linters / tests (if added) and document behavior changes. If you want a different license, update `LICENSE` accordingly.

---

# License & acknowledgements
- **License:** MIT (feel free to change to your preferred license).  
- Built with: [FastAPI](https://fastapi.tiangolo.com), [Calibre](https://calibre-ebook.com/), and a tiny Nginx frontend for static hosting.

---

If you’d like, I can:
- Add an explicit `LICENSE` file (MIT) and a short `CONTRIBUTING.md`.  
- Create a GitHub Actions workflow to build the Docker images and run lightweight tests.  
- Generate a compact Markdown snippet for your repo description and topics.
