# Output Format (Structured Responses)

All API responses are JSON unless downloading a PDF.

## Success
### POST /api/convert
- **200 OK**
```json
{ "task_id": "string" }
```

### GET /api/progress/{task_id}
- **200 OK (processing)**
```json
{
  "progress": 0,
  "status": "processing",
  "message": "string"
}
```
- **200 OK (complete)**
```json
{
  "progress": 100,
  "status": "complete",
  "message": "Complete",
  "download_url": "/api/download/{task_id}",
  "expires_in": 1800
}
```

## Errors (all endpoints)
- **JSON shape**
```json
{ "error": "message", "code": 415 }
```
- **Codes**
  - 413 — file too large
  - 415 — unsupported file type
  - 404 — task not found
  - 410 — file expired
  - 425 — not ready (download before completion)
  - 500 — conversion failed or Calibre missing
