#!/usr/bin/env python3
"""Session & project data cleanup for OpenCode.

Commands:
  stats                          Show total sessions/projects
  list_projects                  List all projects with session counts
  list_sessions <project_id>     List sessions for a project
  preview_delete_sessions <ids>  Preview deleting comma-separated session IDs
  preview_delete_project <id>    Preview deleting a project
  delete_sessions <ids>          Delete comma-separated session IDs
  delete_project <id>            Delete project and all sessions
"""
import json
import os
import sqlite3
import shutil
import sys
from datetime import datetime, timezone

OPCODE_DIR = os.path.expanduser("~/.local/share/opencode")
DB_PATH = os.path.join(OPCODE_DIR, "opencode.db")
DCP_DIR = os.path.join(OPCODE_DIR, "storage", "plugin", "dcp")
DIFF_DIR = os.path.join(OPCODE_DIR, "storage", "session_diff")
SNAPSHOT_DIR = os.path.join(OPCODE_DIR, "snapshot")


def _epoch_to_str(ms):
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d %H:%M")


def _get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    return conn


def _del_storage_for_session(sid):
    removed = {"dcp": 0, "diff": 0}
    dcp_path = os.path.join(DCP_DIR, f"{sid}.json")
    if os.path.isfile(dcp_path):
        os.remove(dcp_path)
        removed["dcp"] = 1
    if os.path.isdir(DIFF_DIR):
        for fname in os.listdir(DIFF_DIR):
            if fname.startswith(sid + "."):
                fpath = os.path.join(DIFF_DIR, fname)
                os.remove(fpath)
                removed["diff"] += 1
    return removed


def _del_snapshot_for_project(pid):
    snap = os.path.join(SNAPSHOT_DIR, pid)
    if os.path.isdir(snap):
        shutil.rmtree(snap)
        return True
    return False


def _preview_storage_for_session(sid):
    result = {"dcp": [], "diff": []}
    dcp_path = os.path.join(DCP_DIR, f"{sid}.json")
    if os.path.isfile(dcp_path):
        result["dcp"].append(dcp_path)
    if os.path.isdir(DIFF_DIR):
        for fname in os.listdir(DIFF_DIR):
            if fname.startswith(sid + "."):
                result["diff"].append(os.path.join(DIFF_DIR, fname))
    return result


def _validate_id(value, label="ID"):
    if not value or not isinstance(value, str):
        print(json.dumps({"error": f"Invalid {label}: {value}"}))
        sys.exit(1)

# --- Public commands ---

def cmd_stats():
    conn = _get_db()
    total_sessions = conn.execute("SELECT COUNT(*) FROM session").fetchone()[0]
    total_projects = conn.execute("SELECT COUNT(*) FROM project").fetchone()[0]
    conn.close()
    print(json.dumps({"total_sessions": total_sessions, "total_projects": total_projects}))


def cmd_list_projects():
    conn = _get_db()
    rows = conn.execute("""
        SELECT p.id, p.name, p.worktree, COUNT(s.id) AS session_count
        FROM project p LEFT JOIN session s ON s.project_id = p.id
        GROUP BY p.id ORDER BY p.time_updated DESC
    """).fetchall()
    conn.close()
    out = []
    for r in rows:
        d = dict(r)
        d["session_count"] = r["session_count"]
        out.append(d)
    print(json.dumps(out))


def cmd_list_sessions():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing project_id"}))
        sys.exit(1)
    pid = sys.argv[2]
    _validate_id(pid, "project_id")
    conn = _get_db()
    rows = conn.execute("""
        SELECT s.id, s.slug, s.title, s.time_created, s.time_updated,
          (SELECT json_extract(data, '$.text') FROM part WHERE session_id = s.id
           ORDER BY time_created ASC LIMIT 1) AS first_message
        FROM session s WHERE s.project_id = ?
        ORDER BY s.time_updated DESC
    """, (pid,)).fetchall()
    conn.close()
    out = []
    for r in rows:
        d = dict(r)
        d["time_created_str"] = _epoch_to_str(r["time_created"])
        d["time_updated_str"] = _epoch_to_str(r["time_updated"])
        if d.get("first_message"):
            d["preview"] = d["first_message"][:120].replace("\n", " ")
        else:
            d["preview"] = ""
        del d["first_message"]
        out.append(d)
    print(json.dumps(out))


def cmd_current_session():
    pid_file = os.path.join(OPCODE_DIR, "current_session.pid")
    if os.path.isfile(pid_file):
        with open(pid_file) as f:
            sid = f.read().strip()
        if sid:
            print(json.dumps({"id": sid}))
            return
    conn = _get_db()
    row = conn.execute("""
        SELECT s.id FROM session s
        ORDER BY s.time_updated DESC LIMIT 1
    """).fetchone()
    conn.close()
    if row:
        print(json.dumps({"id": row["id"]}))
    else:
        print(json.dumps({"id": None}))


def cmd_preview_delete_sessions():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing session_ids"}))
        sys.exit(1)
    ids = sys.argv[2].split(",")
    for sid in ids:
        _validate_id(sid, "session_id")
    conn = _get_db()
    placeholders = ",".join("?" * len(ids))
    db_sessions = conn.execute(
        f"SELECT id, slug, title, project_id FROM session WHERE id IN ({placeholders})", ids
    ).fetchall()
    conn.close()
    storage = {}
    for sid in ids:
        storage[sid] = _preview_storage_for_session(sid)
    print(json.dumps({
        "db_sessions": [dict(r) for r in db_sessions],
        "storage": storage,
    }))


def cmd_preview_delete_project():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing project_id"}))
        sys.exit(1)
    pid = sys.argv[2]
    _validate_id(pid, "project_id")
    conn = _get_db()
    proj = conn.execute("SELECT id, name, worktree FROM project WHERE id = ?", (pid,)).fetchone()
    sessions = conn.execute(
        "SELECT id, slug, title FROM session WHERE project_id = ?", (pid,)
    ).fetchall()
    conn.close()
    storage = {}
    for s in sessions:
        storage[s["id"]] = _preview_storage_for_session(s["id"])
    snap_path = os.path.join(SNAPSHOT_DIR, pid)
    print(json.dumps({
        "project": dict(proj) if proj else None,
        "sessions": [dict(r) for r in sessions],
        "storage": storage,
        "snapshot_dir": snap_path if os.path.isdir(snap_path) else None,
    }))


def cmd_delete_sessions():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing session_ids"}))
        sys.exit(1)
    ids = sys.argv[2].split(",")
    for sid in ids:
        _validate_id(sid, "session_id")
    conn = _get_db()
    placeholders = ",".join("?" * len(ids))
    cursor = conn.execute(f"DELETE FROM session WHERE id IN ({placeholders})", ids)
    conn.commit()
    deleted_db = cursor.rowcount
    conn.close()
    storage_count = {"dcp": 0, "diff": 0}
    for sid in ids:
        r = _del_storage_for_session(sid)
        storage_count["dcp"] += r["dcp"]
        storage_count["diff"] += r["diff"]
    print(json.dumps({
        "deleted_db_sessions": deleted_db,
        "deleted_dcp_files": storage_count["dcp"],
        "deleted_diff_files": storage_count["diff"],
    }))


def cmd_delete_project():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing project_id"}))
        sys.exit(1)
    pid = sys.argv[2]
    _validate_id(pid, "project_id")
    conn = _get_db()
    session_ids = [r["id"] for r in conn.execute(
        "SELECT id FROM session WHERE project_id = ?", (pid,)
    ).fetchall()]
    conn.execute("DELETE FROM project WHERE id = ?", (pid,))
    conn.commit()
    conn.close()
    storage_count = {"dcp": 0, "diff": 0}
    for sid in session_ids:
        r = _del_storage_for_session(sid)
        storage_count["dcp"] += r["dcp"]
        storage_count["diff"] += r["diff"]
    snap_deleted = _del_snapshot_for_project(pid)
    print(json.dumps({
        "deleted_sessions": len(session_ids),
        "deleted_dcp_files": storage_count["dcp"],
        "deleted_diff_files": storage_count["diff"],
        "deleted_snapshot": snap_deleted,
    }))


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command"}))
        sys.exit(1)
    command = sys.argv[1]
    commands = {
        "stats": cmd_stats,
        "list_projects": cmd_list_projects,
        "list_sessions": cmd_list_sessions,
        "current_session": cmd_current_session,
        "preview_delete_sessions": cmd_preview_delete_sessions,
        "preview_delete_project": cmd_preview_delete_project,
        "delete_sessions": cmd_delete_sessions,
        "delete_project": cmd_delete_project,
    }
    fn = commands.get(command)
    if not fn:
        print(json.dumps({"error": f"Unknown command: {command}"}))
        sys.exit(1)
    try:
        fn()
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
