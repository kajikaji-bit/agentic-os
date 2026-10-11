#!/usr/bin/env python3
"""Cursor agent-transcripts JSONL を library/conversations/*.jsonl に同期する。"""
from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import conversation_store as store

CURSOR_HOME = Path.home() / ".cursor"
PROJECTS_DIR = CURSOR_HOME / "projects"

_DROP_TAGS = (
    "system_reminder",
    "open_and_recently_viewed_files",
    "attached_files",
    "system_notification",
    "manually_attached_skills",
    "agent_transcripts",
    "rules",
    "agent_skills",
    "user_info",
)
_KEEP_TAGS = ("user_query",)
_DROP_RE = [re.compile(rf"<{t}\b[^>]*>[\s\S]*?</{t}>", re.IGNORECASE) for t in _DROP_TAGS]
_KEEP_RE = [re.compile(rf"</?{t}\b[^>]*>", re.IGNORECASE) for t in _KEEP_TAGS]


def main() -> int:
    root = store.repo_root()
    parser = argparse.ArgumentParser(description="Sync Cursor conversations to library/conversations/")
    parser.add_argument("--projects-dir", type=Path, default=PROJECTS_DIR)
    parser.add_argument("--state-file", type=Path, default=store.default_state_file("cursor_conversation_sync.json"))
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
        record = _read_cursor_transcript(path)
        if record is not None:
            records.append(record)
    return store.sync_records(records, state_file, conversations_dir, provider="cursor", dry_run=dry_run)


def _transcript_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    files: list[Path] = []
    for path in root.glob("**/agent-transcripts/*/*.jsonl"):
        if "subagents" in path.parts:
            continue
        if path.stem != path.parent.name:
            continue
        files.append(path)
    return sorted(files)


def _read_cursor_transcript(path: Path) -> store.SessionRecord | None:
    session_id = path.stem
    if session_id != path.parent.name:
        return None

    messages: list[store.Message] = []
    turn_no = 0
    current_user: str | None = None
    user_line_no = 0
    assistant_parts: list[str] = []
    base_time = _file_base_time(path)

    def flush_turn() -> None:
        nonlocal turn_no, current_user, user_line_no, assistant_parts
        if current_user is None:
            assistant_parts = []
            return

        turn_no += 1
        messages.append(store.Message(
            store.message_key(user_line_no, "user", current_user),
            "user",
            current_user,
            _turn_time(base_time, turn_no, 0),
        ))
        if assistant_parts:
            assistant_text = "\n\n".join(assistant_parts)
            messages.append(store.Message(
                store.message_key(user_line_no, "assistant", assistant_text),
                "assistant",
                assistant_text,
                _turn_time(base_time, turn_no, 1),
            ))
        current_user = None
        assistant_parts = []

    with path.open(encoding="utf-8") as f:
        for line_no, raw in enumerate(f, start=1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                entry = json.loads(raw)
            except json.JSONDecodeError:
                continue

            role = entry.get("role")
            blocks = (entry.get("message") or {}).get("content")
            if role not in {"user", "assistant"} or not isinstance(blocks, list):
                continue

            if role == "user":
                flush_turn()
                cleaned = _user_text(blocks)
                if not cleaned:
                    continue
                current_user = cleaned
                user_line_no = line_no
            elif role == "assistant":
                cleaned = _assistant_text(blocks)
                if cleaned:
                    assistant_parts.append(cleaned)

    flush_turn()
    if not messages:
        return None

    return store.SessionRecord(
        session_id=session_id,
        started_at=base_time,
        messages=messages,
        source_path=path,
        meta={"cwd": _guess_cwd(path)},
        updated_at=store.iso(base_time),
    )


def _guess_cwd(path: Path) -> str | None:
    """projects/<Users-kaji-Workspace-foo>/ のディレクトリ名から cwd を復元する。

    区切りの `-` とディレクトリ名中の `-` が区別できないため、
    実在するディレクトリを辿れた組み合わせだけを返す。
    """
    for part in path.parts:
        if part.startswith("Users-"):
            found = _walk_encoded(Path("/"), part.split("-"), 0)
            if found is not None:
                return str(found)
    return None


def _walk_encoded(prefix: Path, parts: list[str], i: int) -> Path | None:
    if i == len(parts):
        return prefix
    segment = ""
    for j in range(i, len(parts)):
        segment = parts[j] if not segment else f"{segment}-{parts[j]}"
        candidate = prefix / segment
        if candidate.is_dir():
            found = _walk_encoded(candidate, parts, j + 1)
            if found is not None:
                return found
    return None


def _user_text(blocks: list[Any]) -> str | None:
    texts = [
        b.get("text") or ""
        for b in blocks
        if isinstance(b, dict) and b.get("type") == "text" and (b.get("text") or "").strip()
    ]
    if not texts:
        return None
    cleaned = _strip_tags("\n\n".join(texts))
    return cleaned or None


def _assistant_text(blocks: list[Any]) -> str | None:
    texts = [
        b.get("text") or ""
        for b in blocks
        if isinstance(b, dict) and b.get("type") == "text" and (b.get("text") or "").strip()
    ]
    if not texts:
        return None
    cleaned = _drop_thinking("\n\n".join(texts))
    return cleaned or None


def _strip_tags(text: str) -> str:
    for pattern in _DROP_RE:
        text = pattern.sub("", text)
    for pattern in _KEEP_RE:
        text = pattern.sub("", text)
    return text.strip()


def _drop_thinking(text: str) -> str:
    segments = re.split(r"\n{2,}", text)
    kept: list[str] = []
    for segment in segments:
        if segment.startswith(" "):
            break
        kept.append(segment)
    return "\n\n".join(kept).strip()


def _file_base_time(path: Path) -> datetime:
    stat = path.stat()
    birth = getattr(stat, "st_birthtime", None)
    if isinstance(birth, (int, float)) and birth > 0:
        return datetime.fromtimestamp(birth, timezone.utc)
    return datetime.fromtimestamp(stat.st_mtime, timezone.utc)


def _turn_time(base: datetime, turn_no: int, sub: int) -> str:
    return store.iso(base + timedelta(microseconds=turn_no * 2 + sub))


if __name__ == "__main__":
    raise SystemExit(main())
