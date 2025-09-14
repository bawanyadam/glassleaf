import os
import shutil
import tempfile
import threading
import time
import uuid
import subprocess
from datetime import datetime, timedelta

from fastapi import FastAPI, UploadFile, File, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse

# Configuration
MAX_BYTES = 100 * 1024 * 1024  # 100MB
DOWNLOAD_TTL_SECONDS = 60 * 30  # 30 minutes
POLL_MESSAGE = "Converting…"
EBOOK_CONVERT_BIN = shutil.which("ebook-convert") or "/usr/bin/ebook-convert"

app = FastAPI(title="ePub to PDF Converter", version="1.0.0")

# Allow same-origin or dev usage. Adjust origins for production as desired.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

TASKS = {}  # task_id -> dict(progress, status, message, in_path, out_path, expires_at, filename)
TASKS_LOCK = threading.Lock()

BASE_TMP = os.path.join(tempfile.gettempdir(), "epub2pdf")
os.makedirs(BASE_TMP, exist_ok=True)

ERRORS = {
    "UNSUPPORTED_TYPE": {"error": "Unsupported file type. Only .epub is allowed.", "code": 415},
    "TOO_LARGE": {"error": "File too large. Max 100 MB.", "code": 413},
    "CONVERSION_FAILED": {"error": "Conversion failed.", "code": 500},
    "NOT_FOUND": {"error": "Task not found.", "code": 404},
    "EXPIRED": {"error": "File has expired.", "code": 410},
    "CALIBRE_MISSING": {"error": "Calibre 'ebook-convert' not found on server.", "code": 500},
}

def json_error(key: str, details: str | None = None):
    payload = ERRORS.get(key, {"error": "Unknown error.", "code": 500}).copy()
    if details:
        payload["error"] = f"{payload['error']} {details}".strip()
    return JSONResponse(status_code=payload["code"], content=payload)

def _init_task(filename: str) -> str:
    task_id = uuid.uuid4().hex
    task_dir = os.path.join(BASE_TMP, task_id)
    os.makedirs(task_dir, exist_ok=True)
    with TASKS_LOCK:
        TASKS[task_id] = {
            "progress": 0,
            "status": "processing",
            "message": "Starting…",
            "in_path": None,
            "out_path": None,
            "expires_at": None,
            "filename": filename,
            "created_at": time.time(),
        }
    return task_id

def _set_task(task_id: str, **kwargs):
    with TASKS_LOCK:
        if task_id in TASKS:
            TASKS[task_id].update(kwargs)

def _get_task(task_id: str):
    with TASKS_LOCK:
        return TASKS.get(task_id)

def _cleanup_loop():
    while True:
        now = time.time()
        rm_ids = []
        with TASKS_LOCK:
            for tid, t in list(TASKS.items()):
                exp = t.get("expires_at")
                if exp and exp < now:
                    rm_ids.append(tid)
        for tid in rm_ids:
            t = _get_task(tid)
            try:
                d = os.path.dirname(t.get("in_path") or os.path.join(BASE_TMP, tid))
                if os.path.isdir(d):
                    shutil.rmtree(d, ignore_errors=True)
            except Exception:
                pass
            with TASKS_LOCK:
                TASKS.pop(tid, None)
        time.sleep(60)

threading.Thread(target=_cleanup_loop, daemon=True).start()

def _convert_thread(task_id: str, in_path: str, out_path: str):
    if not os.path.exists(EBOOK_CONVERT_BIN):
        _set_task(task_id, status="error", message="Calibre not installed.", progress=0)
        return

    # Simulate phased progress while running conversion
    _set_task(task_id, progress=15, message=POLL_MESSAGE)
    try:
        # Call Calibre
        proc = subprocess.Popen(
            [EBOOK_CONVERT_BIN, in_path, out_path, "--pdf-page-numbers"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        # While running, tick progress up to ~90%
        p = 15
        while True:
            line = proc.stdout.readline()
            if not line and proc.poll() is not None:
                break
            # Increment progress slowly
            p = min(90, p + 1)
            _set_task(task_id, progress=p, message=POLL_MESSAGE)
        code = proc.wait()
        if code != 0 or not os.path.exists(out_path):
            _set_task(task_id, status="error", message="Conversion failed (ebook-convert).", progress=p)
            return
    except Exception as e:
        _set_task(task_id, status="error", message=f"Exception: {e}", progress=0)
        return

    # Done
    _set_task(task_id, progress=100, status="complete", message="Complete", expires_at=time.time() + DOWNLOAD_TTL_SECONDS)

@app.post("/api/convert")
async def convert(file: UploadFile = File(...)):
    # Validate type by extension and mime
    filename = file.filename or "upload.epub"
    lower = filename.lower()
    if not (lower.endswith(".epub")):
        return json_error("UNSUPPORTED_TYPE")

    # Initialize task
    task_id = _init_task(filename=filename)
    task_dir = os.path.join(BASE_TMP, task_id)
    in_path = os.path.join(task_dir, "input.epub")
    out_path = os.path.join(task_dir, os.path.splitext(os.path.basename(filename))[0] + ".pdf")

    # Stream to disk with size check
    size = 0
    try:
        with open(in_path, "wb") as f:
            while True:
                chunk = await file.read(1024 * 1024)  # 1MB
                if not chunk:
                    break
                size += len(chunk)
                if size > MAX_BYTES:
                    f.close()
                    os.remove(in_path)
                    _set_task(task_id, status="error", message="File exceeds 100 MB.", progress=0)
                    return json_error("TOO_LARGE")
                f.write(chunk)
    finally:
        await file.close()

    if not os.path.exists(EBOOK_CONVERT_BIN):
        _set_task(task_id, status="error", message="Calibre not found.", progress=0)
        return json_error("CALIBRE_MISSING", "Install calibre to provide 'ebook-convert'.")

    # Start conversion in background
    _set_task(task_id, in_path=in_path, out_path=out_path, message="Queued…", progress=10)
    threading.Thread(target=_convert_thread, args=(task_id, in_path, out_path), daemon=True).start()

    return JSONResponse({"task_id": task_id})

@app.get("/api/progress/{task_id}")
def progress(task_id: str):
    t = _get_task(task_id)
    if not t:
        return json_error("NOT_FOUND")
    resp = {
        "progress": int(t.get("progress", 0)),
        "status": t.get("status", "processing"),
        "message": t.get("message", ""),
    }
    if t.get("status") == "complete":
        resp["download_url"] = f"/api/download/{task_id}"
        ttl = int((t.get("expires_at", time.time()) - time.time()))
        resp["expires_in"] = max(0, ttl)
    return JSONResponse(resp)

@app.get("/api/download/{task_id}")
def download(task_id: str):
    t = _get_task(task_id)
    if not t:
        return json_error("NOT_FOUND")
    if t.get("status") != "complete":
        return JSONResponse({"error":"Not ready", "code": 425}, status_code=425)
    if t.get("expires_at", 0) < time.time():
        return json_error("EXPIRED")

    out_path = t.get("out_path")
    if not out_path or not os.path.exists(out_path):
        return json_error("CONVERSION_FAILED", "Output not found.")
    fname = os.path.basename(out_path)
    return FileResponse(out_path, media_type="application/pdf", filename=fname)

@app.get("/api/health")
def health():
    ok = os.path.exists(EBOOK_CONVERT_BIN)
    return {"ok": ok, "ebook_convert": EBOOK_CONVERT_BIN, "tmp": BASE_TMP}
