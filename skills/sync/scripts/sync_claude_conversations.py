#!/usr/bin/env python3
"""Claude Code transcript JSONL を library/conversations/*.jsonl に同期する。"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import conversation_store as store

CLAUDE_HOME = Path.home() / ".claude"
PROJECTS_DIR = CLAUDE_HOME / "projects"


def main() -> int:
    root = store.repo_root()
    parser = argparse.ArgumentParser(description="Sync Claude Code conversations to library/conversations/")
    parser.add_argument("--projects-dir", type=Path, default=PROJECTS_DIR)
    parser.add_argument("--state-file", type=Path, default=store.default_state_file("claude_conversation_sync.json"))
    parser.add_argument("--conversations-dir", type=Path, default=root / "library" / "conversations")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    result = sync(
        projects_dir=args.projects_dir,
        state_file=args.state_file,
        conversations_dir=args.conversations_dir,
        dry_run=args.dry_run,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def sync(
    projects_dir: Path,
    state_file: Path,
    conversations_dir: Path,
    dry_run: bool = False,
) -> dict[str, Any]:
    records = []
    for path in _transcript_files(projects_dir):
        record = _read_claude_transcript(path)
        if record is not None:
            records.append(record)
    return store.sync_records(records, state_file, conversations_dir, provider="claude-code", dry_run=dry_run)


def _transcript_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return sorted(
        path
        for path in root.glob("**/*.jsonl")
        if "subagents" not in path.parts
    )


def _read_claude_transcript(path: Path) -> store.SessionRecord | None:
    session_id: str | None = None
    session_started_at: datetime | None = None
    cwd: str | None = None
    updated_at: str | None = None
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
            parsed_ts = store.parse_dt(timestamp)
            if parsed_ts and session_started_at is None:
                session_started_at = parsed_ts
            if timestamp:
                updated_at = timestamp

            if session_id is None:
                session_id = entry.get("sessionId")
            if cwd is None and isinstance(entry.get("cwd"), str):
                cwd = entry["cwd"]

            entry_type = entry.get("type")
            if entry_type == "user":
                if entry.get("userType") != "external":
                    continue
                text = _user_content((entry.get("message") or {}).get("content"))
                if not text or text.splitlines()[0].lower().startswith("hook feedback:"):
                    continue
                messages.append(store.Message(
                    store.message_key(line_no, "user", text, entry.get("uuid")),
                    "user",
                    text,
                    _message_time(timestamp, path),
                ))
            elif entry_type == "assistant":
                text = _assistant_content((entry.get("message") or {}).get("content"))
                if not text:
                    continue
                messages.append(store.Message(
                    store.message_key(line_no, "assistant", text, entry.get("uuid")),
                    "assistant",
                    text,
                    _message_time(timestamp, path),
                ))

    if session_id is None:
        return None

    return store.SessionRecord(
        session_id=session_id,
        started_at=session_started_at or datetime.fromtimestamp(path.stat().st_mtime, timezone.utc),
        messages=messages,
        source_path=path,
        meta={"cwd": cwd},
        updated_at=updated_at,
    )


def _user_content(raw: Any) -> str | None:
    if isinstance(raw, str):
        text = raw.strip()
        return text or None
    if not isinstance(raw, list):
        return None
    parts = [
        (block.get("text") or "").strip()
        for block in raw
        if isinstance(block, dict) and block.get("type") == "text" and (block.get("text") or "").strip()
    ]
    text = "\n".join(parts).strip()
    return text or None


def _assistant_content(raw: Any) -> str | None:
    if not isinstance(raw, list):
        return None
    text_parts: list[str] = []
    thinking_parts: list[str] = []
    for block in raw:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "text":
            text = (block.get("text") or "").strip()
            if text:
                text_parts.append(text)
        elif block.get("type") == "thinking":
            thinking = (block.get("thinking") or "").strip()
            if thinking:
                thinking_parts.append(thinking)

    if not text_parts:
        return None
    body = "\n\n".join(text_parts)
    if thinking_parts:
        thinking = "\n\n".join(thinking_parts)
        body = f"<thinking>\n{thinking}\n</thinking>\n\n{body}"
    return body


def _message_time(value: str | None, path: Path) -> str:
    parsed = store.parse_dt(value)
    if parsed:
        return store.iso(parsed)
    return store.iso(datetime.fromtimestamp(path.stat().st_mtime, timezone.utc))


if __name__ == "__main__":
    raise SystemExit(main())
