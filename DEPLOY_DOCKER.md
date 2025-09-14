# Docker Deployment

This stack runs two containers:
- **backend** (FastAPI + Calibre) on port **8000**
- **frontend** (Nginx) on port **8080**, serving the SPA and proxying `/api` to the backend

## Prereqs
- Docker and Docker Compose v2 installed on your Ubuntu host.

## Start
```bash
cd /opt/epub2pdf
docker compose up -d --build
```

Open your browser to: **http://<server>:8080**

## Notes
- The backend image installs Calibre using the official binary installer, which currently targets **x86_64**.
  - If your host is **ARM64 (aarch64)**, consider using the distro package instead:
    - Replace the Calibre install step in `backend/Dockerfile` with:
      ```dockerfile
      RUN apt-get update && apt-get install -y --no-install-recommends calibre && rm -rf /var/lib/apt/lists/*
      ```
    - Ensure the repository provides `ebook-convert` for your architecture.
- Healthcheck hits `/api/health` and requires `ebook-convert` to be present.
- Frontend runs on `:8080`. Adjust port mapping in `docker-compose.yml` if needed.
- To update:
```bash
docker compose build
docker compose up -d
```

## Logs
```bash
docker compose logs -f backend
docker compose logs -f frontend
```

## Stop & Remove
```bash
docker compose down
```

## Custom Domain + TLS
Put your reverse proxy (e.g., Caddy/Traefik/Nginx) in front of `frontend:8080` or run a proxy container for TLS. The internal `/api` path is already proxied to `backend` by Nginx inside the frontend container.


### ARM64 (Apple Silicon) build
This repo's backend `Dockerfile` is **multi-arch** via `ARG TARGETARCH`:
- **amd64** → uses Calibre official installer
- **arm64** (Apple Silicon) → installs distro `calibre` package

Docker Desktop on Apple Silicon sets `TARGETARCH=arm64` automatically. Just run:
```bash
docker compose build
docker compose up -d
```

If you want to force platforms manually:
```bash
docker buildx build --platform linux/arm64 -t epub2pdf-backend:arm64 ./backend
docker buildx build --platform linux/arm64 -t epub2pdf-frontend:arm64 ./frontend
```
