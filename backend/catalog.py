#!/usr/bin/env python3
"""Local delivery catalog API and archive verifier."""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import shutil
import sqlite3
import tempfile
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

SCHEMA = """
CREATE TABLE IF NOT EXISTS deliveries (
 id TEXT PRIMARY KEY,
 file_name TEXT NOT NULL,
 size INTEGER NOT NULL,
 sha256 TEXT NOT NULL,
 captured_at TEXT NOT NULL,
 mime_type TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('uploaded','delivered')),
 archive_path TEXT NOT NULL,
 verified_at TEXT
)
"""


def connect(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(db)
    conn.row_factory = sqlite3.Row
    conn.execute(SCHEMA)
    conn.commit()
    return conn


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def iso_mtime(path: Path) -> str:
    return datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat().replace("+00:00", "Z")


def archive_file(source: Path, archive: Path, db: Path) -> dict:
    source = source.resolve(strict=True)
    archive.mkdir(parents=True, exist_ok=True)
    target = archive / source.name
    if target.exists() and sha256_file(target) != sha256_file(source):
        target = archive / f"{source.stem}-{sha256_file(source)[:12]}{source.suffix}"
    fd, temporary_name = tempfile.mkstemp(prefix=".archive-", dir=archive)
    try:
        with os.fdopen(fd, "wb") as out, source.open("rb") as incoming:
            shutil.copyfileobj(incoming, out, 1024 * 1024)
            out.flush()
            os.fsync(out.fileno())
        temporary = Path(temporary_name)
        source_size, target_size = source.stat().st_size, temporary.stat().st_size
        source_hash, target_hash = sha256_file(source), sha256_file(temporary)
        if source_size != target_size or source_hash != target_hash:
            raise RuntimeError(f"verification failed for {source}")
        os.replace(temporary, target)
        directory_fd = os.open(archive, os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        Path(temporary_name).unlink(missing_ok=True)
    record = {
        "id": source_hash,
        "file_name": source.name,
        "size": source_size,
        "sha256": source_hash,
        "captured_at": iso_mtime(source),
        "mime_type": mimetypes.guess_type(source.name)[0] or "application/octet-stream",
        "status": "delivered",
        "archive_path": str(target),
        "verified_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    }
    with connect(db) as conn:
        conn.execute(
            """INSERT INTO deliveries VALUES (:id,:file_name,:size,:sha256,:captured_at,
               :mime_type,:status,:archive_path,:verified_at)
               ON CONFLICT(id) DO UPDATE SET file_name=excluded.file_name,size=excluded.size,
               sha256=excluded.sha256,captured_at=excluded.captured_at,mime_type=excluded.mime_type,
               status=excluded.status,archive_path=excluded.archive_path,verified_at=excluded.verified_at""",
            record,
        )
    return record


def scan(source: Path, archive: Path, db: Path) -> list[dict]:
    allowed = {"image", "video"}
    records = []
    for path in sorted(source.rglob("*")):
        mime = mimetypes.guess_type(path.name)[0] if path.is_file() else None
        if path.is_file() and mime and mime.split("/", 1)[0] in allowed:
            records.append(archive_file(path, archive, db))
    return records


def make_handler(db: Path, token: str):
    class Handler(BaseHTTPRequestHandler):
        def _json(self, status: int, payload: dict):
            body = json.dumps(payload, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            path = urlparse(self.path).path
            if path == "/health":
                return self._json(200, {"status": "ok"})
            if path != "/v1/deliveries":
                return self._json(404, {"error": "not_found"})
            if self.headers.get("Authorization") != f"Bearer {token}":
                return self._json(401, {"error": "unauthorized"})
            with connect(db) as conn:
                rows = conn.execute(
                    "SELECT id,file_name,size,sha256,captured_at,mime_type,status "
                    "FROM deliveries WHERE status='delivered' ORDER BY captured_at DESC"
                ).fetchall()
            self._json(200, {"deliveries": [dict(row) for row in rows]})

        def log_message(self, fmt, *args):
            print(f"catalog: {fmt % args}")

    return Handler


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=Path("catalog.sqlite3"))
    sub = parser.add_subparsers(dest="command", required=True)
    scan_cmd = sub.add_parser("scan")
    scan_cmd.add_argument("source", type=Path)
    scan_cmd.add_argument("archive", type=Path)
    serve = sub.add_parser("serve")
    serve.add_argument("--host", default="127.0.0.1")
    serve.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    if args.command == "scan":
        print(json.dumps({"delivered": scan(args.source, args.archive, args.db)}, indent=2))
    else:
        token = os.environ.get("ARCHIVE_CATALOG_TOKEN", "")
        if len(token) < 24:
            raise SystemExit("ARCHIVE_CATALOG_TOKEN must contain at least 24 characters")
        server = ThreadingHTTPServer((args.host, args.port), make_handler(args.db, token))
        print(f"Listening on http://{args.host}:{args.port}")
        server.serve_forever()


if __name__ == "__main__":
    main()
