"""Line-oriented JSON bridge used by the native macOS application."""

from __future__ import annotations

import json
import sys
from typing import Any

from . import application, engine
from .env import resolve_codex_home
from .model import Settings

MAX_REQUEST_BYTES = 1024 * 1024
COMMANDS = frozenset({"state", "handoff", "apply", "restore", "purge"})


def _read_request() -> dict[str, Any]:
    raw = sys.stdin.buffer.read(MAX_REQUEST_BYTES + 1)
    if len(raw) > MAX_REQUEST_BYTES:
        raise ValueError("request is too large")
    if not raw.strip():
        return {}
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise ValueError("request must be a JSON object")
    return value


def _settings(payload: dict[str, Any]) -> Settings:
    base = Settings(reveal=True)
    return application.settings_with(base, payload.get("options") or {})


def dispatch(command: str, payload: dict[str, Any]) -> dict[str, Any]:
    if command not in COMMANDS:
        return {"ok": False, "blocked": [f"unknown command: {command}"]}

    home = resolve_codex_home(payload.get("home"))
    if not home.exists():
        return {"ok": False, "blocked": [f"Codex home not found: {home.root}"]}
    settings = _settings(payload)

    if command == "state":
        return {"ok": True, **application.build_state(home, settings)}
    if command == "handoff":
        return application.generate_handoffs(
            home, settings, payload.get("session_keys") or []
        )
    if command == "apply":
        required = (
            {str(key) for key in payload.get("handoff_required") or []}
            if "handoff_required" in payload
            else None
        )
        return application.run_apply(
            home,
            settings,
            {str(key) for key in payload.get("excluded") or []},
            handoff_required=required,
            allow_without_handoff=payload.get("allow_without_handoff") is True,
        )
    if command == "restore":
        return application.run_restore(home, settings, payload.get("journal"))
    return application.purge_archives(
        home,
        payload.get("archive_keys") or [],
        str(payload.get("confirmation") or ""),
    )


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    try:
        command = args[0] if args else ""
        response = dispatch(command, _read_request())
    except (ValueError, json.JSONDecodeError, engine.EnvironmentError_) as exc:
        response = {"ok": False, "blocked": [str(exc)]}
    except KeyboardInterrupt:
        response = {"ok": False, "blocked": ["interrupted"]}
    sys.stdout.write(json.dumps(response, ensure_ascii=False, separators=(",", ":")))
    sys.stdout.write("\n")
    return 0 if response.get("ok") else 3


if __name__ == "__main__":
    raise SystemExit(main())
