# API Documentation

Base URL: `/` (frontend) and `/api` (backend proxy).

## POST `/api/convert` — File Upload & Start Conversion
Accepts an ePub via `multipart/form-data` (field: `file`).
- **Validations:** only `.epub`, size ≤ 100 MB.
- **Response 200:** `{ "task_id": string }`
- **Errors:** JSON `{ "error": string, "code": int }`
  - 415 unsupported type
  - 413 too large
  - 500 conversion unavailable

### Example (curl)
```bash
curl -F "file=@/path/book.epub" https://yourdomain/api/convert
```

## GET `/api/progress/{task_id}` — Progress Polling
Poll every 2 seconds.
- **Response 200 (processing):**
```json
{ "progress": 0-100, "status": "processing", "message": "string" }
```
- **Response 200 (complete):**
```json
{
  "progress": 100,
  "status": "complete",
  "message": "Complete",
  "download_url": "/api/download/{task_id}",
  "expires_in": seconds
}
```
- **Response 200 (error):**
```json
{ "progress": N, "status": "error", "message": "reason" }
```

## GET `/api/download/{task_id}` — Retrieve PDF
Returns the PDF file for completed tasks (until expiry).
- **Success:** `200 OK`, `Content-Type: application/pdf`
- **Errors:** JSON `{ "error": string, "code": int }`
  - 425 not ready
  - 410 expired
  - 404 not found

## Error Shape
All errors follow:
```json
{ "error": "message", "code": int }
```

## Notes
- Converted files and task state are **in-memory + temp-dir** only and expire after 30 minutes.
- Conversion uses Calibre’s `ebook-convert`.
