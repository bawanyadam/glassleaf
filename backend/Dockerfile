# Backend: FastAPI + Calibre (ebook-convert), multi-arch
# - On amd64: use Calibre official installer
# - On arm64: use distro package (calibre)
FROM python:3.11-slim-bookworm

ARG TARGETARCH
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/calibre:${PATH}"

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget xz-utils ca-certificates curl gnupg \
    libglib2.0-0 libgl1 libnss3 libxkbcommon0 \
    && rm -rf /var/lib/apt/lists/*

# Install Calibre depending on architecture
# amd64 -> official installer; arm64 -> distro package
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | bash /dev/stdin; \
    else \
        apt-get update && apt-get install -y --no-install-recommends calibre && rm -rf /var/lib/apt/lists/*; \
    fi

# Copy backend code
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=5 \
  CMD wget -qO- http://127.0.0.1:8000/api/health | grep -q '"ok": true' || exit 1

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
