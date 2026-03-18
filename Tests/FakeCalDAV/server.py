#!/usr/bin/env python3
"""Fake CalDAV server for acceptance testing Tasks.mac.

Runs Radicale as a CalDAV subprocess and exposes an admin HTTP API
so that acceptance tests can inject test data and inspect server state.

Usage:
    python3 server.py [--port PORT] [--admin-port PORT] [--storage-dir DIR]

Admin API (default port 5233):
    GET  /health      — Health check, returns {"status": "ok"}
    POST /calendars   — Create a named calendar, body: {"name": "...", "uid": "..."}
    POST /tasks       — Add a VTODO, body: {"uid": "...", "summary": "...", "calendar": "<uid>"}
    GET  /tasks       — List all task UIDs across all calendars
    POST /reset       — Delete all calendars and tasks, restore initial state
"""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


CALENDAR_USER = ""  # Radicale with auth=none uses an empty username; collections sit at the root

VTODO_TEMPLATE = """\
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//FakeCalDAV//Tasks.mac Testing//EN
BEGIN:VTODO
DTSTAMP:{dtstamp}
UID:{uid}
SUMMARY:{summary}
STATUS:NEEDS-ACTION
END:VTODO
END:VCALENDAR
"""


class Storage:
    """Direct manipulation of the Radicale filesystem storage.

    Radicale's filesystem backend stores each calendar object as a plain .ics
    file inside a directory hierarchy:

        <base>/collection-root/<user>/<calendar-uid>/<task-uid>.ics

    Collection metadata lives in .Radicale.props JSON files alongside
    the items. Writing files while Radicale is running is safe because
    Radicale re-reads each item on every request.
    """

    def __init__(self, base: Path) -> None:
        self.base = base
        self._init_collections()

    @property
    def user_dir(self) -> Path:
        # With an empty username, Python's pathlib drops the empty component,
        # so collections sit directly under collection-root/ and Radicale
        # serves them at /<uid>/ with no user-prefix in the URL.
        return self.base / "collection-root"

    def _init_collections(self) -> None:
        self.user_dir.mkdir(parents=True, exist_ok=True)

    def add_calendar(self, name: str, uid: str) -> None:
        cal_dir = self.user_dir / uid
        cal_dir.mkdir(parents=True, exist_ok=True)
        _write_props(cal_dir, {
            "D:resourcetype": (
                "{urn:ietf:params:xml:ns:caldav}calendar {DAV:}collection"
            ),
            "D:displayname": name,
            "tag": "VCALENDAR",
        })

    def add_task(self, uid: str, summary: str, calendar_uid: str) -> None:
        cal_dir = self.user_dir / calendar_uid
        if not cal_dir.exists():
            raise ValueError(f"Calendar '{calendar_uid}' does not exist")
        dtstamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        ics = VTODO_TEMPLATE.format(uid=uid, summary=summary, dtstamp=dtstamp)
        (cal_dir / f"{uid}.ics").write_text(ics)

    def list_tasks(self) -> list:
        tasks = []
        for cal_dir in self.user_dir.iterdir():
            if cal_dir.is_dir():
                tasks.extend(f.stem for f in cal_dir.glob("*.ics"))
        return tasks

    def reset(self) -> None:
        """Wipe all calendars and tasks, then restore the bare user collection."""
        collection_root = self.base / "collection-root"
        if collection_root.exists():
            shutil.rmtree(collection_root)
        self._init_collections()


def _write_props(directory: Path, props: dict) -> None:
    (directory / ".Radicale.props").write_text(json.dumps(props))


def make_radicale_config(storage_dir: Path, caldav_port: int) -> Path:
    config_path = storage_dir / "radicale.conf"
    rights_path = storage_dir / "rights"
    # Grant all rights to every path for any (or no) user.
    # The default "owner_only" and "authenticated" modules key calendar access
    # on path depth (requires exactly one "/" in the sanitised path), which
    # means flat single-level calendar paths — e.g. /calendar-uid/ — are
    # treated as top-level principal collections and only receive uppercase
    # RW rights, not the lowercase rw rights that Radicale requires before it
    # will expose tagged calendar collections.  A permissive "from_file" rule
    # sidesteps that logic entirely.
    rights_path.write_text(
        "[allow-all]\n"
        "user = .*\n"
        "collection = .*\n"
        "permissions = RrWw\n"
    )
    config_path.write_text(
        f"[server]\n"
        f"hosts = localhost:{caldav_port}\n\n"
        f"[auth]\n"
        f"type = none\n\n"
        f"[rights]\n"
        f"type = from_file\n"
        f"file = {rights_path}\n\n"
        f"[storage]\n"
        f"filesystem_folder = {storage_dir}\n\n"
        f"[logging]\n"
        f"level = warning\n"
    )
    return config_path


class AdminHandler(BaseHTTPRequestHandler):
    storage: "Storage"  # Set on the class before the server starts

    def log_message(self, fmt, *args):  # noqa: ANN
        pass  # Suppress per-request output

    def do_GET(self):  # noqa: N802
        if self.path == "/health":
            self._json(200, {"status": "ok"})
        elif self.path == "/tasks":
            self._json(200, self.storage.list_tasks())
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        if self.path == "/calendars":
            body = self._read_body()
            name = body.get("name", "Unnamed")
            uid  = body.get("uid", str(uuid.uuid4()))
            self.storage.add_calendar(name, uid)
            self._json(201, {"uid": uid, "name": name})
        elif self.path == "/tasks":
            body     = self._read_body()
            uid      = body.get("uid", str(uuid.uuid4()))
            summary  = body.get("summary", "Test Task")
            calendar = body.get("calendar")
            if not calendar:
                self._json(400, {"error": "calendar uid required"})
                return
            try:
                self.storage.add_task(uid, summary, calendar)
            except ValueError as exc:
                self._json(404, {"error": str(exc)})
                return
            self._json(201, {"uid": uid})
        elif self.path == "/reset":
            self.storage.reset()
            self._json(200, {"status": "ok"})
        else:
            self._json(404, {"error": "not found"})

    def _read_body(self) -> dict:
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length)) if length else {}

    def _json(self, status: int, body) -> None:
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=5232, help="CalDAV server port")
    parser.add_argument("--admin-port", type=int, default=5233, help="Admin API port")
    parser.add_argument("--storage-dir", help="Storage directory (default: temp dir)")
    args = parser.parse_args()

    storage_dir = (
        Path(args.storage_dir)
        if args.storage_dir
        else Path(tempfile.mkdtemp(prefix="fake-caldav-"))
    )
    storage_dir.mkdir(parents=True, exist_ok=True)

    storage = Storage(storage_dir)
    config_path = make_radicale_config(storage_dir, args.port)

    radicale_proc = subprocess.Popen(
        [sys.executable, "-m", "radicale", "--config", str(config_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    print(f"CalDAV: http://localhost:{args.port}/", file=sys.stderr, flush=True)
    print(f"Admin:  http://localhost:{args.admin_port}/", file=sys.stderr, flush=True)
    print("Ready.", file=sys.stderr, flush=True)

    class Handler(AdminHandler):
        pass

    Handler.storage = storage
    admin_server = HTTPServer(("localhost", args.admin_port), Handler)

    try:
        admin_server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        radicale_proc.terminate()
        radicale_proc.wait()


if __name__ == "__main__":
    main()
