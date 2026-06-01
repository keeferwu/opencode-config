#!/usr/bin/env python3
"""OpenCode session cleanup tool.

Modes:
    Default:    JSON grouped by project (for interactive Question tool flow)
    --list:     Human-readable session summary, then STOP
    --delete:   Delete sessions + auto-clean orphaned diff files
    --orphans:  Clean orphaned diff files only
    --dry-run:  Preview without changes (combine with --delete or --orphans)
"""

from __future__ import annotations

import argparse
import json
import sqlite3
from datetime import datetime
from pathlib import Path

DB_PATH = Path("~/.local/share/opencode/opencode.db").expanduser()
DIFF_DIR = Path("~/.local/share/opencode/storage/session_diff").expanduser()
SESSION_TABLES = ["message", "part", "todo", "session_message", "session_share"]


def get_connection() -> sqlite3.Connection:
    if not DB_PATH.exists():
        print(f"Database not found: {DB_PATH}")
        raise SystemExit(1)
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def fetch_sessions(conn: sqlite3.Connection) -> list[dict]:
    cursor = conn.execute("""
        SELECT s.id AS session_id, s.title, s.project_id,
               s.time_created, s.time_updated,
               COALESCE(p.name, 'global') AS project_name,
               COALESCE(p.worktree, '/') AS worktree
        FROM session s
        LEFT JOIN project p ON s.project_id = p.id
        ORDER BY s.time_created DESC
    """)
    sessions = cursor.fetchall()

    msg_counts: dict[str, int] = dict(
        conn.execute("SELECT session_id, COUNT(*) AS cnt FROM message GROUP BY session_id").fetchall()
    )
    part_counts: dict[str, int] = dict(
        conn.execute("SELECT session_id, COUNT(*) AS cnt FROM part GROUP BY session_id").fetchall()
    )

    return [{
        "session_id": s["session_id"],
        "title": s["title"],
        "project_id": s["project_id"] or "global",
        "project_name": s["project_name"],
        "worktree": s["worktree"],
        "time_created": s["time_created"],
        "time_updated": s["time_updated"],
        "message_count": msg_counts.get(s["session_id"], 0),
        "part_count": part_counts.get(s["session_id"], 0),
    } for s in sessions]


def list_sessions(conn: sqlite3.Connection) -> dict:
    rows = fetch_sessions(conn)
    projects: dict[str, dict] = {}
    for s in rows:
        pid = s["project_id"]
        if pid not in projects:
            projects[pid] = {"name": s["project_name"], "worktree": s["worktree"], "sessions": []}
        projects[pid]["sessions"].append({
            k: s[k] for k in ("session_id", "title", "time_created", "time_updated", "message_count", "part_count")
        })
    return {"projects": projects, "total_sessions": len(rows)}


def list_sessions_readable(conn: sqlite3.Connection) -> None:
    rows = fetch_sessions(conn)
    current_project: str | None = None
    for s in rows:
        pid = s["project_id"]
        if pid != current_project:
            current_project = pid
            print(f"\n## {s['project_name']} ({s['worktree']})")
        created = datetime.fromtimestamp(s["time_created"] / 1000).strftime("%Y-%m-%d %H:%M")
        print(f"  {s['session_id'][:16]}  {created}  {s['message_count']:>4} msgs  {s['title']}")
    print(f"\nTotal: {len(rows)} sessions")


def delete_sessions(conn: sqlite3.Connection, session_ids: list[str], dry_run: bool = False) -> None:
    if not session_ids:
        print("No sessions to delete.")
        return

    for sid in session_ids:
        if not conn.execute("SELECT 1 FROM session WHERE id = ?", (sid,)).fetchone():
            print(f"Session {sid} not found in database, skipping.")
            continue

        if dry_run:
            for table in SESSION_TABLES:
                cnt = conn.execute(f"SELECT COUNT(*) FROM {table} WHERE session_id = ?", (sid,)).fetchone()[0]
                if cnt > 0:
                    print(f"  [DRY-RUN] Would delete {cnt} rows from {table} for session {sid}")
            print(f"  [DRY-RUN] Would delete session {sid}")
        else:
            for table in SESSION_TABLES:
                deleted = conn.execute(f"DELETE FROM {table} WHERE session_id = ?", (sid,)).rowcount
                if deleted > 0:
                    print(f"  Deleted {deleted} rows from {table} for session {sid}")
            conn.execute("DELETE FROM session WHERE id = ?", (sid,))
            print(f"  Deleted session {sid}")

    if not dry_run:
        conn.commit()
        print("Database changes committed.")


def clean_orphans(conn: sqlite3.Connection, dry_run: bool = False) -> None:
    if not DIFF_DIR.is_dir():
        print(f"Session diff directory not found: {DIFF_DIR}")
        return

    db_ids = {row["id"] for row in conn.execute("SELECT id FROM session").fetchall()}
    orphaned = [f for f in DIFF_DIR.iterdir() if f.suffix == ".json" and f.stem not in db_ids]

    if not orphaned:
        print("No orphaned session diff files found.")
        return

    for fp in orphaned:
        if dry_run:
            print(f"  [DRY-RUN] Would remove orphaned file: {fp}")
        else:
            fp.unlink()
            print(f"  Removed orphaned file: {fp}")

    label = "[DRY-RUN] Would clean" if dry_run else "Cleaned"
    print(f"{label} {len(orphaned)} orphaned file(s).")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="OpenCode session cleanup tool")
    parser.add_argument("--list", action="store_true", help="List sessions in readable format")
    parser.add_argument("--delete", nargs="+", default=None, metavar="SID",
                        help="Delete specified session(s)")
    parser.add_argument("--orphans", action="store_true", help="Clean orphaned diff files only")
    parser.add_argument("--dry-run", action="store_true", help="Preview without making changes")
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()

    conn = get_connection()
    try:
        if args.orphans:
            clean_orphans(conn, dry_run=args.dry_run)
        elif args.list:
            list_sessions_readable(conn)
        elif args.delete is not None:
            delete_sessions(conn, args.delete, dry_run=args.dry_run)
            clean_orphans(conn, dry_run=args.dry_run)
        else:
            print(json.dumps(list_sessions(conn), indent=2, ensure_ascii=False))
    finally:
        conn.close()


if __name__ == "__main__":
    main()