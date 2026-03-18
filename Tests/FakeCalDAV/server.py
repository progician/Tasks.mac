#!/usr/bin/env python3
"""Fake CalDAV server for acceptance testing Tasks.mac.

Runs Radicale as a CalDAV subprocess and exposes an admin HTTP API
so that acceptance tests can inject test data and inspect server state.

Usage:
    python3 server.py [--port PORT] [--admin-port PORT] [--storage-dir DIR]

Admin API (default port 5233):
    GET  /health   — Health check, returns {"status": "ok"}
    POST /tasks    — Add a VTODO task, body: {"uid": "...", "summary": "..."}
    GET  /tasks    — List all task UIDs
    POST /reset    — Delete all tasks
"""
import argparse
import json
import subprocess
import sys
import tempfile
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


CALENDAR_USER = "tasks-test"
CALENDAR_NAME = "tasks"

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

        <base>/collection-root/<user>/<calendar>/<uid>.ics

    Collection metadata lives in .Radicale.props JSON files alongside
    the items. Writing files while Radicale is running is safe because
    Radicale re-reads each item on every request.
    """

    def __init__(self, base: Path) -> None:
        self.base = base
        self._init_collections()

    @property
    def tasks_dir(self) -> Path:
        return self.base / "collection-root" / CALENDAR_USER / CALENDAR_NAME

    def _init_collections(self) -> None:
        user_dir = self.base / "collection-root" / CALENDAR_USER
        user_dir.mkdir(parents=True, exist_ok=True)
        _write_props_if_missing(user_dir, {"D:displayname": CALENDAR_USER})

        self.tasks_dir.mkdir(exist_ok=True)
        _write_props_if_missing(self.tasks_dir, {
            "D:resourcetype": (
                "{urn:ietf:params:xml:ns:caldav}calendar {DAV:}collection"
            ),
            "D:displayname": "Tasks",
            "tag": "VCALENDAR",
        })

    def add(self, uid: str, summary: str) -> None:
        dtstamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        ics = VTODO_TEMPLATE.format(uid=uid, summary=summary, dtstamp=dtstamp)
        (self.tasks_dir / f"{uid}.ics").write_text(ics)

    def list(self) -> list:
        return [f.stem for f in self.tasks_dir.glob("*.ics")]

    def reset(self) -> None:
        for f in self.tasks_dir.glob("*.ics"):
            f.unlink()


def _write_props_if_missing(directory: Path, props: dict) -> None:
    props_file = directory / ".Radicale.props"
    if not props_file.exists():
        props_file.write_text(json.dumps(props))


def make_radicale_config(storage_dir: Path, caldav_port: int) -> Path:
    config_path = storage_dir / "radicale.conf"
    config_path.write_text(
        f"[server]\n"
        f"hosts = localhost:{caldav_port}\n\n"
        f"[auth]\n"
        f"type = none\n\n"
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
            self._json(200, self.storage.list())
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        if self.path == "/tasks":
            body = self._read_body()
            uid = body.get("uid", str(uuid.uuid4()))
            summary = body.get("summary", "Test Task")
            self.storage.add(uid, summary)
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
