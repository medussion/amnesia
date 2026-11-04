"""Application services shared by the CLI, browser UI, and macOS app.

Presentation layers never read Codex databases or mutate files directly.  They
send user intent here; this module rebuilds live plans, enforces the same safety
gates, and delegates durable work to the engine.
"""

from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from typing import Any, Iterable

from . import engine, handoff, purge
from .advice import assess
from .env import (
    CodexHome,
    HomeLock,
    LockHeld,
    codex_processes,
    default_backup_root,
    pinned_thread_ids,
)
from .journal import find_latest_journal
from .model import Settings
from .tasks import ALL_TASKS
from .tasks.sessions import plan_selected as plan_selected_sessions


OPTION_SPEC: dict[str, tuple[type, Any, Any]] = {
    "reveal": (bool, None, None),
    "session_age_days": (int, 0, 3650),
    "session_min_mb": (float, 0.0, 100_000.0),
    "worktree_age_days": (int, 0, 3650),
    "log_rotate_mb": (int, 0, 1_000_000),
    "title_limit": (int, 20, 100_000),
    "preview_limit": (int, 20, 1_000_000),
    "leftover_age_days": (int, 0, 3650),
    "max_archive_gb": (float, 0.001, 10_000.0),
    "repair_thread_metadata": (bool, None, None),
    "archive_orphan_rollouts": (bool, None, None),
    "archive_dirty_worktrees": (bool, None, None),
    "archive_leftovers": (bool, None, None),
}


def _coerce(name: str, raw: Any) -> Any:
    kind, low, high = OPTION_SPEC[name]
    if kind is bool:
        return bool(raw)
    value = kind(raw)
    if low is not None:
        value = max(low, value)
    if high is not None:
        value = min(high, value)
    return value


def settings_with(base: Settings, options: dict[str, Any]) -> Settings:
    changes = {}
    for name, raw in (options or {}).items():
        if name not in OPTION_SPEC:
            continue
        try:
            changes[name] = _coerce(name, raw)
        except (TypeError, ValueError):
            continue
    updated = replace(base, **changes)
    if updated.preview_limit < updated.title_limit:
        updated = replace(updated, preview_limit=updated.title_limit)
    return updated


def current_options(settings: Settings) -> dict[str, Any]:
    return {name: getattr(settings, name) for name in OPTION_SPEC}


def build_state(home: CodexHome, settings: Settings) -> dict[str, Any]:
    """Build a read-only, bounded snapshot for a presentation layer."""
    stamp = engine.fresh_stamp()
    backup_root = engine.resolve_backup_root(home, settings, stamp)
    session = engine.open_session(
        home, settings, writable=False, stamp=stamp, backup_root=backup_root
    )
    try:
        plan = engine.scan(session, with_operations=True)
        redactor = session.ctx.redact
    finally:
        session.close()

    assessment = assess(plan)
    running = codex_processes(home)
    journal = find_latest_journal(settings.backup_root or default_backup_root(home))
    handoff_root = handoff.default_handoff_root(home, settings.backup_root)
    sessions = handoff.list_sessions(home, pinned=pinned_thread_ids(home))

    return {
        "home": str(home.root),
        "backup_root": str(backup_root),
        "reveal": settings.reveal,
        "options": current_options(settings),
        "assessment": assessment.to_dict(),
        "items": [item.to_dict() for item in plan.items()],
        "sessions": [
            item.to_dict(redact=redactor, handoff_root=handoff_root) for item in sessions
        ],
        "archives": [item.to_dict(redactor) for item in purge.list_archives(home)],
        "archive_root": str(home.archived_sessions),
        "handoff_root": str(handoff_root),
        "findings": [finding.to_dict() for finding in plan.findings],
        "skipped": plan.skipped,
        "operation_count": len(plan.operations),
        "reclaimable_bytes": plan.reclaimable_bytes,
        "codex_running": [
            {"pid": process.pid, "name": process.name, "reason": process.reason}
            for process in running
        ],
        "last_journal": str(journal) if journal else None,
        "task_titles": {task.name: task.title for task in ALL_TASKS},
    }


def generate_handoffs(
    home: CodexHome, settings: Settings, session_keys: Iterable[str]
) -> dict[str, Any]:
    return handoff.generate_selected(
        home,
        handoff.default_handoff_root(home, settings.backup_root),
        session_keys,
        pinned=pinned_thread_ids(home),
    )


def run_apply(
    home: CodexHome,
    settings: Settings,
    excluded: set[str],
    *,
    handoff_required: set[str] | None = None,
    allow_without_handoff: bool = False,
) -> dict[str, Any]:
    stamp = engine.fresh_stamp()
    backup_root = engine.resolve_backup_root(home, settings, stamp)
    try:
        with HomeLock(home, active=True):
            session = engine.open_session(
                home, settings, writable=False, stamp=stamp, backup_root=backup_root
            )
            try:
                plan = engine.scan(session, with_operations=True)
                if handoff_required is not None:
                    existing = {op.key for op in plan.operations if op.task == "sessions"}
                    plan.operations.extend(
                        op
                        for op in plan_selected_sessions(session.ctx, handoff_required)
                        if op.key not in existing
                    )
            finally:
                session.close()

            plan = engine.filter_plan(plan, excluded)
            handoff_root = handoff.default_handoff_root(home, settings.backup_root)
            ready = handoff.ready_session_keys(
                home, handoff_root, pinned=pinned_thread_ids(home)
            )
            session_keys = {op.key for op in plan.operations if op.task == "sessions"}
            protected = session_keys if handoff_required is None else session_keys & handoff_required
            missing_handoffs = sorted(protected - ready)
            if missing_handoffs:
                return {
                    "ok": False,
                    "blocked": [
                        f"{len(missing_handoffs)} selected session(s) need a fresh handoff before cleanup"
                    ],
                    "missing_handoffs": missing_handoffs,
                }
            without_handoff = sorted(session_keys - protected)
            if without_handoff and not allow_without_handoff:
                return {
                    "ok": False,
                    "blocked": [
                        f"{len(without_handoff)} session(s) were not marked as continuing projects; explicit archive confirmation is required"
                    ],
                    "without_handoff": without_handoff,
                }
            problems = engine.preflight(home, plan, settings)
            if problems:
                return {"ok": False, "blocked": [problem.message for problem in problems]}
            if not plan.operations:
                return {"ok": True, "completed": 0, "nothing_to_do": True}

            result = engine.apply_plan(home, plan, settings)
    except LockHeld as exc:
        return {"ok": False, "blocked": [str(exc)]}

    return {
        "ok": not result.failed,
        "completed": result.completed,
        "planned": len(plan.operations),
        "failed": result.failed,
        "rolled_back": result.rolled_back,
        "error": result.error,
        "backup_root": str(result.backup_root),
        "journal": str(result.journal_path),
        "notes": result.notes,
    }


def run_restore(home: CodexHome, settings: Settings, journal: str | None) -> dict[str, Any]:
    base = settings.backup_root or default_backup_root(home)
    path = Path(journal).expanduser() if journal else find_latest_journal(base)
    if path is None or not path.is_file():
        return {"ok": False, "blocked": ["no journal found"]}

    running = codex_processes(home)
    if running:
        return {"ok": False, "blocked": [f"Codex is running ({len(running)})"]}

    try:
        with HomeLock(home, active=True):
            result = engine.restore(home, path)
    except LockHeld as exc:
        return {"ok": False, "blocked": [str(exc)]}

    return {
        "ok": not result.failed,
        "undone": result.undone,
        "failed": result.failed,
        "journal": str(result.journal_path),
        "notes": result.notes,
    }


def purge_archives(
    home: CodexHome, archive_keys: Iterable[str], confirmation: str
) -> dict[str, Any]:
    return purge.purge_selected(home, archive_keys, confirmation)
