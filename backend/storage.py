"""File storage helper.

Uploads are written to **Supabase Storage** (durable object storage) when it is
configured via the SUPABASE_URL / SUPABASE_SERVICE_KEY / SUPABASE_BUCKET env
vars; otherwise they fall back to the local ``uploads/`` directory.

WARNING: the local-disk fallback is NOT durable on Render's free tier — the
container filesystem is wiped on every redeploy / idle spin-down, so files
written there are lost. Configure Supabase Storage in production. See
docs/HOSTING_AND_DATA_SAFETY_RECOMMENDATION.md.

This module is the canonical upload path for new features. The legacy
``_validate_and_save_file`` in routers/pets.py predates it and still trusts the
client Content-Type; migrating that to ``save_upload`` here is a small follow-up
that also fixes pet photo / vax-card uploads.
"""
import os
import uuid

import httpx
from fastapi import UploadFile, HTTPException

import config

UPLOAD_DIR = config.env("UPLOAD_DIR", "uploads")
BASE_URL = config.env("BASE_URL", "http://localhost:8000")
# 8 MB default — comfortably fits phone photos and multi-page receipt PDFs.
MAX_FILE_BYTES = config.env_int("MAX_FILE_BYTES", 8 * 1024 * 1024)

SUPABASE_URL = config.env("SUPABASE_URL")
SUPABASE_SERVICE_KEY = config.env("SUPABASE_SERVICE_KEY")
SUPABASE_BUCKET = config.env("SUPABASE_BUCKET", "uploads")

# Extension -> MIME. Flutter's http.MultipartFile.fromBytes sends
# "application/octet-stream" (it does not sniff the bytes), so we resolve the
# real content type from the file extension rather than trusting the client
# header. This also ensures the stored object gets a correct Content-Type so it
# renders inline in the admin preview.
_EXT_TO_MIME = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".pdf": "application/pdf",
}


def storage_is_durable() -> bool:
    """True when uploads go to Supabase Storage rather than the ephemeral disk."""
    return bool(SUPABASE_URL and SUPABASE_SERVICE_KEY)


def _default_ext_for(mime: str) -> str:
    for ext, m in _EXT_TO_MIME.items():
        if m == mime:
            return ext
    return ".bin"


def _resolve_type(upload: UploadFile, allowed_types: set) -> tuple[str, str]:
    """Return (extension, mime_type) validated against ``allowed_types``.

    Trusts a declared Content-Type only when it is already allowed; otherwise
    derives the type from the filename extension. Raises 422 when neither yields
    an allowed type. The client filename is never trusted beyond its extension.
    """
    raw_ext = os.path.splitext(upload.filename or "")[-1].lower()
    declared = (upload.content_type or "").lower()

    if declared in allowed_types:
        mime = declared
        ext = raw_ext if raw_ext in _EXT_TO_MIME else _default_ext_for(mime)
        return ext, mime

    mime = _EXT_TO_MIME.get(raw_ext)
    if mime not in allowed_types:
        raise HTTPException(
            status_code=422,
            detail=(
                f"Invalid file type '{upload.content_type}'. "
                f"Allowed: {', '.join(sorted(allowed_types))}"
            ),
        )
    return raw_ext, mime


def save_upload(upload: UploadFile, subdir: str, allowed_types: set) -> str:
    """Validate type + size, store the file under a UUID key, return its URL.

    Args:
        upload: the multipart file.
        subdir: logical folder, e.g. "receipts", "photos".
        allowed_types: allowed MIME types.
    """
    ext, content_type = _resolve_type(upload, allowed_types)

    data = upload.file.read()
    if len(data) > MAX_FILE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Maximum allowed size is {MAX_FILE_BYTES // (1024 * 1024)} MB.",
        )

    filename = f"{uuid.uuid4()}{ext}"
    key = f"{subdir}/{filename}"

    if storage_is_durable():
        return _upload_to_supabase(key, data, content_type)

    # Local-disk fallback (dev / not-yet-migrated). Not durable in production.
    os.makedirs(os.path.join(UPLOAD_DIR, subdir), exist_ok=True)
    with open(os.path.join(UPLOAD_DIR, subdir, filename), "wb") as f:
        f.write(data)
    return f"{BASE_URL}/uploads/{subdir}/{filename}"


def _upload_to_supabase(key: str, data: bytes, content_type: str) -> str:
    url = f"{SUPABASE_URL}/storage/v1/object/{SUPABASE_BUCKET}/{key}"
    headers = {
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "apikey": SUPABASE_SERVICE_KEY,
        "Content-Type": content_type or "application/octet-stream",
        "x-upsert": "true",
    }
    try:
        resp = httpx.post(url, content=data, headers=headers, timeout=30.0)
    except httpx.HTTPError as e:
        # Full reason to server logs; generic message to the user.
        print(f"[storage] Supabase upload network error: {e}")
        raise HTTPException(status_code=502, detail="Could not store the file. Please try again.")
    if resp.status_code not in (200, 201):
        print(f"[storage] Supabase upload {resp.status_code} for {url} -> {(resp.text or '').strip()[:300]}")
        raise HTTPException(status_code=502, detail="Could not store the file. Please try again.")
    # Public bucket: object is served from the public path with its unguessable UUID key.
    return f"{SUPABASE_URL}/storage/v1/object/public/{SUPABASE_BUCKET}/{key}"
