"""A local, single-user web UI served entirely from the standard library.

Access control, in layers, because this process can move a developer's files:

* the socket is bound to 127.0.0.1, so nothing off-box can reach it
* a random per-run token must be presented once, in the URL we open ourselves
* the token is then held in a ``SameSite=Strict``, ``HttpOnly`` cookie, so a
  malicious page in another tab cannot ride along
* mutating calls additionally require a custom header, which a cross-origin form
  post cannot set
* the ``Host`` header must be a loopback name, which blocks DNS rebinding

The server holds one lock across mutating requests: a second Clean cannot start
while the first is still running.
"""

from __future__ import annotations

import http.cookies
import json
import secrets
import threading
import webbrowser
from functools import partial
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from importlib import resources
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

from .. import application, engine
from ..application import (
    OPTION_SPEC,
    build_state,
    run_apply,
    run_restore,
    settings_with,
)
from ..env import CodexHome
from ..model import Settings

COOKIE_NAME = "amnesia_token"
GUARD_HEADER = "X-Amnesia"
ALLOWED_HOSTS = {"127.0.0.1", "localhost", "[::1]"}
MAX_BODY_BYTES = 256 * 1024

def _options_from_query(query: dict[str, list[str]]) -> dict[str, Any]:
    """Query strings arrive as text, so booleans need explicit handling.

    bool("0") is True, which would silently turn every checkbox on.
    """
    options: dict[str, Any] = {}
    for name, (kind, _low, _high) in OPTION_SPEC.items():
        if name not in query:
            continue
        raw = query[name][0]
        options[name] = raw.lower() in ("1", "true", "yes") if kind is bool else raw
    return options


class Handler(BaseHTTPRequestHandler):
    server_version = "amnesia"
    sys_version = ""

    def __init__(self, *args, context: "UiContext", **kwargs):
        self.context = context
        super().__init__(*args, **kwargs)

    # -- plumbing ---------------------------------------------------------

    def log_message(self, *_args) -> None:
        pass  # The console belongs to the user, not to request logging.

    def _host_ok(self) -> bool:
        host = (self.headers.get("Host") or "").rsplit(":", 1)[0]
        return host in ALLOWED_HOSTS

    def _cookie_token(self) -> str | None:
        raw = self.headers.get("Cookie")
        if not raw:
            return None
        jar = http.cookies.SimpleCookie()
        try:
            jar.load(raw)
        except http.cookies.CookieError:
            return None
        morsel = jar.get(COOKIE_NAME)
        return morsel.value if morsel else None

    def _authorised(self) -> bool:
        supplied = self._cookie_token()
        return bool(supplied) and secrets.compare_digest(supplied, self.context.token)

    def _send(self, code: int, body: bytes, content_type: str, extra: dict | None = None) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        # Everything is inlined, so nothing may be fetched from anywhere.
        self.send_header(
            "Content-Security-Policy",
            "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
            "connect-src 'self'; form-action 'none'; base-uri 'none'",
        )
        for name, value in (extra or {}).items():
            self.send_header(name, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _json(self, code: int, payload: dict) -> None:
        self._send(code, json.dumps(payload, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")

    def _read_body(self) -> dict:
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return {}
        if length <= 0 or length > MAX_BODY_BYTES:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8")) or {}
        except (ValueError, UnicodeDecodeError):
            return {}

    # -- routes -----------------------------------------------------------

    def do_GET(self) -> None:  # noqa: N802
        if not self._host_ok():
            self._json(403, {"error": "bad host"})
            return
        parsed = urlparse(self.path)

        if parsed.path == "/":
            supplied = parse_qs(parsed.query).get("t", [""])[0]
            if supplied and secrets.compare_digest(supplied, self.context.token):
                # Move the token out of the address bar and into a strict cookie.
                self._send(
                    303,
                    b"",
                    "text/plain",
                    {
                        "Location": "/",
                        "Set-Cookie": (
                            f"{COOKIE_NAME}={self.context.token}; Path=/; HttpOnly; "
                            "SameSite=Strict"
                        ),
                    },
                )
                return
            if not self._authorised():
                self._send(403, b"amnesia: open the URL printed in the terminal.", "text/plain; charset=utf-8")
                return
            self._send(200, self.context.page, "text/html; charset=utf-8")
            return

        if parsed.path == "/api/state":
            if not self._authorised():
                self._json(403, {"error": "unauthorised"})
                return
            options = _options_from_query(parse_qs(parsed.query))
            try:
                state = build_state(
                    self.context.home, settings_with(self.context.settings, options)
                )
            except engine.EnvironmentError_ as exc:
                self._json(200, {"error": str(exc)})
                return
            self._json(200, state)
            return

        self._json(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        if not self._host_ok():
            self._json(403, {"error": "bad host"})
            return
        if not self._authorised() or self.headers.get(GUARD_HEADER) != "1":
            self._json(403, {"error": "unauthorised"})
            return

        parsed = urlparse(self.path)
        body = self._read_body()

        if parsed.path == "/api/shutdown":
            self._json(200, {"ok": True})
            threading.Thread(target=self.context.stop, daemon=True).start()
            return

        if parsed.path not in ("/api/apply", "/api/restore", "/api/handoffs", "/api/purge"):
            self._json(404, {"error": "not found"})
            return

        if not self.context.busy.acquire(blocking=False):
            self._json(409, {"ok": False, "blocked": ["another run is already in progress"]})
            return
        try:
            settings = settings_with(self.context.settings, body.get("options") or {})
            if parsed.path == "/api/handoffs":
                result = application.generate_handoffs(
                    self.context.home,
                    settings,
                    body.get("session_keys") or [],
                )
            elif parsed.path == "/api/apply":
                excluded = {str(k) for k in (body.get("excluded") or [])}
                required = (
                    {str(k) for k in (body.get("handoff_required") or [])}
                    if "handoff_required" in body
                    else None
                )
                result = run_apply(
                    self.context.home,
                    settings,
                    excluded,
                    handoff_required=required,
                    allow_without_handoff=body.get("allow_without_handoff") is True,
                )
            elif parsed.path == "/api/purge":
                result = application.purge_archives(
                    self.context.home,
                    body.get("archive_keys") or [],
                    str(body.get("confirmation") or ""),
                )
            else:
                result = run_restore(self.context.home, settings, body.get("journal"))
        except engine.EnvironmentError_ as exc:
            result = {"ok": False, "blocked": [str(exc)]}
        finally:
            self.context.busy.release()
        self._json(200, result)


class UiContext:
    def __init__(self, home: CodexHome, settings: Settings, page: bytes):
        self.home = home
        self.settings = settings
        self.page = page
        self.token = secrets.token_urlsafe(24)
        self.busy = threading.Semaphore(1)
        self.httpd: ThreadingHTTPServer | None = None

    def stop(self) -> None:
        if self.httpd is not None:
            self.httpd.shutdown()


def load_page() -> bytes:
    return resources.files(__package__).joinpath("index.html").read_bytes()


def _emit(message: str) -> None:
    # Flush explicitly: stdout is block-buffered when redirected to a file or a
    # pipe, and a long-running server that prints its URL only on exit is useless.
    print(message, flush=True)


def serve(
    home: CodexHome,
    settings: Settings,
    *,
    port: int = 0,
    open_browser: bool = True,
    printer=_emit,
) -> int:
    context = UiContext(home, settings, load_page())
    handler = partial(Handler, context=context)
    try:
        httpd = ThreadingHTTPServer(("127.0.0.1", port), handler)
    except OSError as exc:
        printer(
            f"amnesia gui: could not listen on 127.0.0.1:{port} ({exc}).\n"
            "Something else is using that port. Omit --port to let one be chosen, "
            "or pass a different one."
        )
        return 3
    context.httpd = httpd
    bound_port = httpd.server_address[1]
    url = f"http://127.0.0.1:{bound_port}/?t={context.token}"

    printer(f"amnesia gui\n  codex home   {home.root}\n  url          {url}")
    printer("  stop         Ctrl-C, or the button in the page")
    if open_browser:
        webbrowser.open(url)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        printer("\nstopped")
    finally:
        httpd.server_close()
    return 0
