#!/usr/bin/env python3
"""library/conversations/*.jsonl の書き込み・状態管理を各 sync スクリプトで共有する。

ファイル形式:
- 1 行目 (新規作成時): {"type": "meta", "provider": ..., "sessionId": ..., "cwd": ..., ...}
- 2 行目以降: {"role": ..., "text": ..., "at": ...}

メタ行はどのプロバイダのどの作業ディレクトリの会話かを後から特定するために置く。
メタ行が無い既存ファイルへの追記はそのまま許し、backfill_conversation_meta.py が補完する。
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

META_TYPE = "meta"
ROTATE_THRESHOLD_BYTES = 90 * 1024 * 1024

_PART_RE = re.compile(r"\.part(\d+)$")


@dataclass
class Message:
    key: str
    role: str
    text: str
    at: str


@dataclass
class SessionRecord:
    """1 セッション分の同期入力。meta はメタ行に載せる provider 固有フィールド。"""

    session_id: str
    started_at: datetime
    messages: list[Message]
    source_path: Path
    meta: dict[str, Any] = field(default_factory=dict)
    state_extra: dict[str, Any] = field(default_factory=dict)
    updated_at: str | None = None


def repo_root() -> Path:
    out = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True)
    return Path(out.strip())


def state_dir() -> Path:
    cache_root = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(cache_root) / "clone-sync"


def default_state_file(name: str) -> Path:
    return state_dir() / name


def sync_records(
    records: Iterable[SessionRecord],
    state_file: Path,
    conversations_dir: Path,
    provider: str,
    dry_run: bool = False,
) -> dict[str, Any]:
    state = read_json(state_file)
    sessions_state = state.setdefault("sessions", {})

    files_seen = 0
    sessions_synced = 0
    messages_created = 0
    conversation_files: list[str] = []

    for record in records:
        files_seen += 1
        if not record.messages:
            continue

        session_state = sessions_state.setdefault(record.session_id, {})
        seen = set(session_state.get("seenMessageKeys", []))
        new_messages = [m for m in record.messages if m.key not in seen]
        if not new_messages:
            continue

        filename = session_state.get("conversationFile")
        if not filename:
            filename = conversation_filename(record.started_at, record.session_id)
            session_state["conversationFile"] = filename
        filename = rotate_if_needed(filename, conversations_dir)
        session_state["conversationFile"] = filename

        existing = existing_message_signatures(conversations_dir / filename)
        deduped_messages = [
            m for m in new_messages
            if (m.role, m.at, m.text) not in existing
        ]

        if not dry_run and deduped_messages:
            append_messages(
                conversations_dir / filename,
                deduped_messages,
                meta_line(provider, record, filename),
            )

        seen.update(m.key for m in new_messages)
        session_state["seenMessageKeys"] = sorted(seen)
        session_state["sourcePath"] = str(record.source_path)
        session_state["updatedAt"] = record.updated_at
        session_state.update(record.state_extra)
        conversation_files.append(filename)
        sessions_synced += 1
        messages_created += len(deduped_messages)

    if not dry_run:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text(json.dumps(state, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    return {
        "filesSeen": files_seen,
        "sessionsSynced": sessions_synced,
        "messagesCreated": messages_created,
        "conversationFiles": sorted(set(conversation_files)),
        "dryRun": dry_run,
    }


def meta_line(provider: str, record: SessionRecord, filename: str) -> dict[str, Any]:
    meta: dict[str, Any] = {
        "type": META_TYPE,
        "provider": provider,
        "sessionId": record.session_id,
        "startedAt": iso(record.started_at),
        "sourcePath": str(record.source_path),
    }
    meta.update({k: v for k, v in record.meta.items() if v is not None})
    part = part_number(filename)
    if part is not None:
        meta["part"] = part
    return meta


def append_messages(path: Path, messages: list[Message], meta: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    is_new = not path.exists()
    with path.open("a", encoding="utf-8") as f:
        if is_new:
            f.write(json.dumps(meta, ensure_ascii=False) + "\n")
        for message in messages:
            f.write(json.dumps({
                "role": message.role,
                "text": message.text,
                "at": message.at,
            }, ensure_ascii=False) + "\n")


def is_meta_entry(entry: dict[str, Any]) -> bool:
    return entry.get("type") == META_TYPE


def existing_message_signatures(path: Path) -> set[tuple[str, str, str]]:
    if not path.exists():
        return set()
    out: set[tuple[str, str, str]] = set()
    with path.open(encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                entry = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if is_meta_entry(entry):
                continue
            out.add((entry.get("role") or "", entry.get("at") or "", entry.get("text") or ""))
    return out


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


def conversation_filename(started_at: datetime, session_id: str) -> str:
    digest = hashlib.sha1(session_id.encode("utf-8")).hexdigest()[:4]
    return f"{started_at.strftime('%Y%m%d%H%M')}_{digest}.jsonl"


def rotate_if_needed(filename: str, conversations_dir: Path) -> str:
    path = conversations_dir / filename
    if not path.exists() or path.stat().st_size < ROTATE_THRESHOLD_BYTES:
        return filename
    return next_part_filename(filename)


def next_part_filename(filename: str) -> str:
    stem = filename.removesuffix(".jsonl")
    part = part_number(filename)
    if part is not None:
        return f"{_PART_RE.sub('', stem)}.part{part + 1:02d}.jsonl"
    return f"{stem}.part02.jsonl"


def part_number(filename: str) -> int | None:
    match = _PART_RE.search(filename.removesuffix(".jsonl"))
    return int(match.group(1)) if match else None


def base_filename(filename: str) -> str:
    """part ローテーション名から元のファイル名を返す (X.part02.jsonl → X.jsonl)。"""
    return _PART_RE.sub("", filename.removesuffix(".jsonl")) + ".jsonl"


def message_key(line_no: int, role: str, text: str, uuid: Any = None) -> str:
    source = uuid if isinstance(uuid, str) and uuid else text
    digest = hashlib.sha1(source.encode("utf-8")).hexdigest()[:12]
    return f"{line_no}:{role}:{digest}"


def parse_dt(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def iso(dt: datetime) -> str:
    return dt.isoformat(timespec="microseconds").replace("+00:00", "Z")
