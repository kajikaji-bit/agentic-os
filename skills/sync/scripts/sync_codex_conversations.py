#!/usr/bin/env python3
"""Codex rollout JSONL を library/conversations/*.jsonl に同期する。"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import conversation_store as store

CODEX_HOME = Path.home() / ".codex"
SESSIONS_DIR = CODEX_HOME / "sessions"
ARCHIVED_SESSIONS_DIR = CODEX_HOME / "archived_sessions"
SESSION_INDEX = CODEX_HOME / "session_index.jsonl"


def main() -> int:
    root = store.repo_root()
    parser = argparse.ArgumentParser(description="Sync Codex conversations to library/conversations/")
    parser.add_argument("--sessions-dir", type=Path, default=SESSIONS_DIR)
    parser.add_argument("--archived-sessions-dir", type=Path, default=ARCHIVED_SESSIONS_DIR)
    parser.add_argument("--session-index", type=Path, default=SESSION_INDEX)
    parser.add_argument("--state-file", type=Path, default=store.default_state_file("codex_conversation_sync.json"))
    parser.add_argument("--conversations-dir", type=Path, default=root / "library" / "conversations")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    result = sync(
        sessions_dir=args.sessions_dir,
        archived_sessions_dir=args.archived_sessions_dir,
        session_index=args.session_index,
        state_file=args.state_file,
        conversations_dir=args.conversations_dir,
        dry_run=args.dry_run,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def sync(
    sessions_dir: Path,
    archived_sessions_dir: Path,
    session_index: Path,
    state_file: Path,
    conversations_dir: Path,
    dry_run: bool = False,
) -> dict[str, Any]:
    index = _read_session_index(session_index)
    records = []
    for path in _rollout_files(sessions_dir, archived_sessions_dir):
        record = _read_codex_rollout(path, index)
        if record is not None:
            records.append(record)
    return store.sync_records(records, state_file, conversations_dir, provider="codex", dry_run=dry_run)


def _rollout_files(*roots: Path) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        if root.exists():
            files.extend(root.glob("**/rollout-*.jsonl"))
    return sorted(files)


def _read_codex_rollout(path: Path, index: dict[str, dict[str, Any]]) -> store.SessionRecord | None:
    session_id: str | None = None
    session_started_at: datetime | None = None
    cwd: str | None = None
    originator: str | None = None
    is_fork = False
    collecting = True
    messages: list[store.Message] = []

    with path.open(encoding="utf-8") as f:
        for line_no, raw in enumerate(f, start=1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                entry = json.loads(raw)
            except json.JSONDecodeError:
                continue

            timestamp = entry.get("timestamp")
            entry_type = entry.get("type")
            payload = entry.get("payload") if isinstance(entry.get("payload"), dict) else {}

            if entry_type == "session_meta":
                if session_id is None:
                    session_id = payload.get("id")
                    session_started_at = store.parse_dt(payload.get("timestamp") or timestamp)
                    cwd = payload.get("cwd")
                    originator = payload.get("originator")
                    source = payload.get("source")
                    if isinstance(source, dict) and "subagent" in source:
                        return None
                    is_fork = bool(payload.get("forked_from_id"))
                    collecting = not is_fork
                continue

            if is_fork and _is_environment_context(entry):
                collecting = True
                continue

            if not collecting:
                continue

            if entry_type != "event_msg":
                continue

            kind = payload.get("type")
            if kind == "user_message":
                text = _clean_text(payload.get("message"))
                if text:
                    messages.append(store.Message(store.message_key(line_no, "user", text), "user", text, timestamp))
            elif kind == "agent_message":
                text = _clean_text(payload.get("message"))
                if text:
                    messages.append(store.Message(store.message_key(line_no, "assistant", text), "assistant", text, timestamp))

    if session_id is None:
        return None

    index_entry = index.get(session_id, {})
    return store.SessionRecord(
        session_id=session_id,
        started_at=session_started_at or datetime.fromtimestamp(path.stat().st_mtime, timezone.utc),
        messages=messages,
        source_path=path,
        meta={"cwd": cwd, "originator": originator},
        state_extra={"threadName": index_entry.get("thread_name")},
        updated_at=index_entry.get("updated_at"),
    )


def _read_session_index(path: Path) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    if not path.exists():
        return out
    with path.open(encoding="utf-8") as f:
        for raw in f:
            try:
                entry = json.loads(raw)
            except json.JSONDecodeError:
                continue
            session_id = entry.get("id")
            if session_id:
                out[session_id] = entry
    return out


def _is_environment_context(entry: dict[str, Any]) -> bool:
    if entry.get("type") != "response_item":
        return False
    payload = entry.get("payload")
    if not isinstance(payload, dict):
        return False
    if payload.get("type") != "message" or payload.get("role") != "user":
        return False
    for block in payload.get("content") or []:
        if isinstance(block, dict) and "<environment_context>" in str(block.get("text", "")):
            return True
    return False


def _clean_text(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    text = value.strip()
    return text or None


if __name__ == "__main__":
    raise SystemExit(main())
