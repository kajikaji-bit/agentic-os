#!/usr/bin/env python3
"""Cursor ACP セッション (~/.cursor/acp-sessions/*/store.db) を library/conversations/*.jsonl に同期する。

Zed などの ACP クライアントから Cursor agent を駆動した会話はここに保存され、
agent-transcripts にはミラーされないため、専用の読み取りが要る。

store.db の構造:
- meta テーブルの key '0' に hex エンコードされた JSON
  {agentId, latestRootBlobId, name, createdAt(ms), ...}
- blobs テーブルは content-addressed ストア。root blob は protobuf で、
  0x0a 0x20 に続く 32 byte の子 blob id (sha256) がメッセージ順に並ぶ
- 子 blob は JSON {"role": system|user|assistant|tool, "content": str | [{type, text}]}
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import conversation_store as store

ACP_SESSIONS_DIR = Path.home() / ".cursor" / "acp-sessions"

_CHILD_ID_RE = re.compile(rb"\x0a\x20(.{32})", re.DOTALL)

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
    "timestamp",
)
_DROP_RE = [re.compile(rf"<{t}\b[^>]*>[\s\S]*?</{t}>", re.IGNORECASE) for t in _DROP_TAGS]
_USER_QUERY_RE = re.compile(r"<user_query>([\s\S]*?)</user_query>", re.IGNORECASE)


def main() -> int:
    root = store.repo_root()
    parser = argparse.ArgumentParser(description="Sync Cursor ACP conversations to library/conversations/")
    parser.add_argument("--sessions-dir", type=Path, default=ACP_SESSIONS_DIR)
    parser.add_argument("--state-file", type=Path, default=store.default_state_file("cursor_acp_conversation_sync.json"))
    parser.add_argument("--conversations-dir", type=Path, default=root / "library" / "conversations")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    result = sync(
        sessions_dir=args.sessions_dir,
        state_file=args.state_file,
        conversations_dir=args.conversations_dir,
        dry_run=args.dry_run,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def sync(
    sessions_dir: Path,
    state_file: Path,
    conversations_dir: Path,
    dry_run: bool = False,
) -> dict[str, Any]:
    records = []
    errors: list[str] = []
    if sessions_dir.exists():
        for db_path in sorted(sessions_dir.glob("*/store.db")):
            try:
                record = _read_acp_session(db_path)
            except (sqlite3.Error, OSError, ValueError) as exc:
                errors.append(f"{db_path.parent.name}: {exc}")
                continue
            if record is not None:
                records.append(record)

    result = store.sync_records(records, state_file, conversations_dir, provider="cursor", dry_run=dry_run)
    result["errors"] = errors
    return result


def _read_acp_session(db_path: Path) -> store.SessionRecord | None:
    session_dir = db_path.parent
    session_id = session_dir.name

    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        meta_rows = dict(con.execute("select key, value from meta"))
        if "0" not in meta_rows:
            return None
        head = json.loads(bytes.fromhex(meta_rows["0"]).decode("utf-8"))
        root_blob_id = head.get("latestRootBlobId")
        if not root_blob_id:
            return None
        blobs = dict(con.execute("select id, data from blobs"))
    finally:
        con.close()

    root_blob = blobs.get(root_blob_id)
    if root_blob is None:
        return None

    started_at = _epoch_ms(head.get("createdAt")) or datetime.fromtimestamp(
        db_path.stat().st_mtime, timezone.utc)

    messages: list[store.Message] = []
    # root blob は履歴の書き換え (圧縮など) で並びが変わりうるため、
    # キーは位置でなく子 blob id (内容の sha256) + 出現回数で安定させる
    occurrences: dict[str, int] = {}
    for idx, child_id in enumerate(_child_ids(root_blob)):
        data = blobs.get(child_id)
        if data is None:
            continue
        try:
            entry = json.loads(data)
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        role = entry.get("role")
        if role not in {"user", "assistant"}:
            continue
        raw_text = _content_text(entry.get("content"))
        text = _user_text(raw_text) if role == "user" else _strip_tags(raw_text)
        if not text:
            continue
        occurrence = occurrences.get(child_id, 0)
        occurrences[child_id] = occurrence + 1
        messages.append(store.Message(
            f"{child_id[:12]}.{occurrence}:{role}",
            role,
            text,
            store.iso(started_at + timedelta(microseconds=idx)),
        ))

    if not messages:
        return None

    session_meta = store.read_json(session_dir / "meta.json")
    return store.SessionRecord(
        session_id=session_id,
        started_at=started_at,
        messages=messages,
        source_path=db_path,
        meta={
            "cwd": session_meta.get("cwd"),
            "originator": "acp",
            "title": head.get("name") or session_meta.get("title"),
        },
        updated_at=store.iso(datetime.fromtimestamp(db_path.stat().st_mtime, timezone.utc)),
    )


def _child_ids(root_blob: bytes) -> list[str]:
    return [m.hex() for m in _CHILD_ID_RE.findall(root_blob)]


def _content_text(content: Any) -> str:
    if isinstance(content, str):
        return content.strip()
    if not isinstance(content, list):
        return ""
    parts = [
        (block.get("text") or "").strip()
        for block in content
        if isinstance(block, dict) and block.get("type") == "text" and (block.get("text") or "").strip()
    ]
    return "\n\n".join(parts).strip()


def _user_text(text: str) -> str:
    """user メッセージは <user_query> の中身だけを採る。

    包みが無い user メッセージは、会話冒頭に流し込まれる環境コンテキスト
    (<user_info> や <git_status> など) なので捨てる。
    """
    queries = [q.strip() for q in _USER_QUERY_RE.findall(text) if q.strip()]
    return _strip_tags("\n\n".join(queries))


def _strip_tags(text: str) -> str:
    for pattern in _DROP_RE:
        text = pattern.sub("", text)
    return text.strip()


def _epoch_ms(value: Any) -> datetime | None:
    if not isinstance(value, (int, float)) or value <= 0:
        return None
    return datetime.fromtimestamp(value / 1000, timezone.utc)


if __name__ == "__main__":
    raise SystemExit(main())
