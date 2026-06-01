#!/usr/bin/env python3
"""OpenCode session cleanup tool.

Default: list all sessions grouped by project as JSON for interactive selection.
With --list: list all sessions in a simple readable format.
With --delete: delete selected sessions and auto-clean orphaned diff files.

Usage:
    python3 session-clean.py                        # List sessions as JSON
    python3 session-clean.py --list                 # List sessions in readable format
    python3 session-clean.py --delete SID1 SID2...  # Delete sessions + clean orphans
    python3 session-clean.py --orphans              # Clean orphaned diff files only
    python3 session-clean.py --dry-run --delete SID1 SID2...  # Dry run
"""

import json
import os
import sqlite3
import sys

DB_PATH = os.path.expanduser("~/.local/share/opencode/opencode.db")
DIFF_DIR = os.path.expanduser("~/.local/share/opencode/storage/session_diff")

SESSION_TABLES = [
    "message",
    "part",
    "todo",
    "session_message",
    "session_share",
]


def get_db_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = OFF")
    return conn


def _fetch_sessions(conn):
    cursor = conn.cursor()
    cursor.execute("""
        SELECT
            s.id AS session_id,
            s.title,
            s.project_id,
            s.time_created,
            s.time_updated,
            COALESCE(p.name, 'global') AS project_name,
            COALESCE(p.worktree, '/') AS worktree
        FROM session s
        LEFT JOIN project p ON s.project_id = p.id
        ORDER BY s.time_created DESC
    """)
    sessions = cursor.fetchall()

    message_counts = {}
    part_counts = {}
    cursor.execute("SELECT session_id, COUNT(*) AS cnt FROM message GROUP BY session_id")
    for row in cursor.fetchall():
        message_counts[row["session_id"]] = row["cnt"]
    cursor.execute("SELECT session_id, COUNT(*) AS cnt FROM part GROUP BY session_id")
    for row in cursor.fetchall():
        part_counts[row["session_id"]] = row["cnt"]

    result = []
    for s in sessions:
        result.append({
            "session_id": s["session_id"],
            "title": s["title"],
            "project_id": s["project_id"] or "global",
            "project_name": s["project_name"],
            "worktree": s["worktree"],
            "time_created": s["time_created"],
            "time_updated": s["time_updated"],
            "message_count": message_counts.get(s["session_id"], 0),
            "part_count": part_counts.get(s["session_id"], 0),
        })
    return result


def list_sessions(conn):
    rows = _fetch_sessions(conn)
    projects = {}
    for s in rows:
        pid = s["project_id"]
        if pid not in projects:
            projects[pid] = {
                "name": s["project_name"],
                "worktree": s["worktree"],
                "sessions": [],
            }
        projects[pid]["sessions"].append({
            "session_id": s["session_id"],
            "title": s["title"],
            "time_created": s["time_created"],
            "time_updated": s["time_updated"],
            "message_count": s["message_count"],
            "part_count": s["part_count"],
        })

    return {
        "projects": projects,
        "total_sessions": len(rows),
    }


def list_sessions_readable(conn):
    import datetime
    rows = _fetch_sessions(conn)
    current_project = None
    for s in rows:
        pid = s["project_id"]
        if pid != current_project:
            current_project = pid
            print(f"\n## {s['project_name']} ({s['worktree']})")
        created = datetime.datetime.fromtimestamp(s["time_created"] / 1000).strftime("%Y-%m-%d %H:%M")
        sid_short = s["session_id"][:16]
        print(f"  {sid_short}  {created}  {s['message_count']:>4} msgs  {s['title']}")
    print(f"\nTotal: {len(rows)} sessions")


def delete_sessions(conn, session_ids, dry_run=False):
    if not session_ids:
        print("No sessions to delete.")
        return

    for sid in session_ids:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM session WHERE id = ?", (sid,))
        if not cursor.fetchone():
            print(f"Session {sid} not found in database, skipping.")
            continue

        if dry_run:
            for table in SESSION_TABLES:
                cursor.execute(f"SELECT COUNT(*) FROM {table} WHERE session_id = ?", (sid,))
                cnt = cursor.fetchone()[0]
                if cnt > 0:
                    print(f"  [DRY-RUN] Would delete {cnt} rows from {table} for session {sid}")
            print(f"  [DRY-RUN] Would delete session {sid}")
        else:
            for table in SESSION_TABLES:
                cursor.execute(f"DELETE FROM {table} WHERE session_id = ?", (sid,))
                deleted = cursor.rowcount
                if deleted > 0:
                    print(f"  Deleted {deleted} rows from {table} for session {sid}")
            cursor.execute("DELETE FROM session WHERE id = ?", (sid,))
            print(f"  Deleted session {sid}")

    if not dry_run:
        conn.commit()
        print("Database changes committed.")


def clean_orphans(conn, dry_run=False):
    if not os.path.isdir(DIFF_DIR):
        print(f"Session diff directory not found: {DIFF_DIR}")
        return []

    cursor = conn.cursor()
    cursor.execute("SELECT id FROM session")
    db_session_ids = {row["id"] for row in cursor.fetchall()}

    diff_files = os.listdir(DIFF_DIR)
    orphaned = []
    for f in diff_files:
        sid = f.replace(".json", "")
        if sid not in db_session_ids:
            orphaned.append(os.path.join(DIFF_DIR, f))

    if not orphaned:
        print("No orphaned session diff files found.")
        return orphaned

    for fp in orphaned:
        if dry_run:
            print(f"  [DRY-RUN] Would remove orphaned file: {fp}")
        else:
            os.remove(fp)
            print(f"  Removed orphaned file: {fp}")

    if not dry_run:
        print(f"Cleaned {len(orphaned)} orphaned file(s).")
    else:
        print(f"[DRY-RUN] Would clean {len(orphaned)} orphaned file(s).")

    return orphaned


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    orphans_only = "--orphans" in args
    list_mode = "--list" in args

    delete_idx = args.index("--delete") if "--delete" in args else -1
    session_ids = []
    if delete_idx >= 0:
        session_ids = args[delete_idx + 1:]
        if session_ids and session_ids[0].startswith("--"):
            session_ids = []

    if orphans_only:
        conn = get_db_conn()
        try:
            clean_orphans(conn, dry_run=dry_run)
        finally:
            conn.close()
        return

    if list_mode:
        conn = get_db_conn()
        try:
            list_sessions_readable(conn)
        finally:
            conn.close()
        return

    if not session_ids:
        conn = get_db_conn()
        try:
            data = list_sessions(conn)
        finally:
            conn.close()
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return

    conn = get_db_conn()
    try:
        delete_sessions(conn, session_ids, dry_run=dry_run)
        clean_orphans(conn, dry_run=dry_run)
    finally:
        conn.close()


if __name__ == "__main__":
    main()