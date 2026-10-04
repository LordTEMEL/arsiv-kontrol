import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

from catalog import connect, make_handler, scan, sha256_file


class CatalogTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.db = self.root / "catalog.sqlite3"

    def tearDown(self):
        self.temp.cleanup()

    def test_scan_copies_and_marks_delivered_without_deleting_source(self):
        source = self.root / "source"
        source.mkdir()
        media = source / "photo.jpg"
        media.write_bytes(b"safe-media")
        records = scan(source, self.root / "archive", self.db)
        self.assertTrue(media.exists())
        self.assertEqual(records[0]["status"], "delivered")
        copied = Path(records[0]["archive_path"])
        self.assertEqual(sha256_file(media), sha256_file(copied))

    def test_api_requires_token_and_only_returns_delivered(self):
        with connect(self.db) as conn:
            base = ("id", "x.jpg", 1, "hash", "2026-01-01T00:00:00Z", "image/jpeg")
            conn.execute("INSERT INTO deliveries VALUES (?,?,?,?,?,?,'uploaded','/x',NULL)", base)
            conn.execute("INSERT INTO deliveries VALUES (?,?,?,?,?,?,'delivered','/y','now')", ("ok", *base[1:]))
        server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(self.db, "a" * 24))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{server.server_port}/v1/deliveries"
        try:
            with self.assertRaises(urllib.error.HTTPError) as denied:
                urllib.request.urlopen(url)
            self.assertEqual(denied.exception.code, 401)
            request = urllib.request.Request(url, headers={"Authorization": f"Bearer {'a' * 24}"})
            with urllib.request.urlopen(request) as response:
                data = json.load(response)
            self.assertEqual([item["id"] for item in data["deliveries"]], ["ok"])
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    unittest.main()
