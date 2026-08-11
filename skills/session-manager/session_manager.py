#!/usr/bin/env python3
"""Session & project data cleanup for OpenCode.

Commands:
  stats                          Show total sessions/projects
  list_projects                  List all projects with session counts
  list_sessions <project_id>     List top-level sessions for a project (subagents excluded)
  export_sessions <ids>          Export comma-separated session IDs to markdown
                                  (auto-includes subagent sessions in same project)
  current_session                Show current session ID
  preview_delete_sessions <ids>  Preview deleting comma-separated session IDs
                                  (auto-includes subagent sessions in same project)
  preview_delete_project <id>    Preview deleting a project
  delete_sessions <ids>          Delete comma-separated session IDs
                                  (auto-includes subagent sessions in same project)
  delete_project <id>            Delete project and all sessions

Subagent handling:
  - A subagent session is identified by `session.parent_id IS NOT NULL`.
  - `list_sessions` excludes subagent sessions and annotates each top-level
    session's preview with "(N subagents)" when N > 0.
  - `export_sessions`, `preview_delete_sessions`, and `delete_sessions` resolve
    the input IDs to include their same-project subagent sessions before acting.
"""
import json
import os
import re
import sqlite3
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

OPCODE_DATA_DIR = os.path.join(
    os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
    "opencode"
)
DB_PATH = os.path.join(OPCODE_DATA_DIR, "opencode.db")
DCP_DIR = os.path.join(OPCODE_DATA_DIR, "storage", "plugin", "dcp")
DIFF_DIR = os.path.join(OPCODE_DATA_DIR, "storage", "session_diff")
SNAPSHOT_DIR = os.path.join(OPCODE_DATA_DIR, "snapshot")
EXPORT_DIR = os.path.join(OPCODE_DATA_DIR, "export")


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


def _fetch_subagent_map(conn, parent_ids, project_filter=True):
    """Return {parent_id: [{id, slug, title}, ...]} for same-project subagents.

    When project_filter is True, only subagents whose project_id matches any of
    their parent's project_id are included.
    """
    if not parent_ids:
        return {}
    placeholders = ",".join("?" * len(parent_ids))
    rows = conn.execute(
        f"""SELECT id, parent_id, slug, title, project_id
            FROM session
            WHERE parent_id IN ({placeholders})""",
        parent_ids,
    ).fetchall()
    parent_projects = {}
    if project_filter:
        proj_placeholders = ",".join("?" * len(parent_ids))
        proj_rows = conn.execute(
            f"SELECT id, project_id FROM session WHERE id IN ({proj_placeholders})",
            parent_ids,
        ).fetchall()
        for pr in proj_rows:
            parent_projects[pr["id"]] = pr["project_id"]
    result = {pid: [] for pid in parent_ids}
    for r in rows:
        if project_filter:
            if parent_projects.get(r["parent_id"]) != r["project_id"]:
                continue
        result[r["parent_id"]].append({
            "id": r["id"],
            "slug": r["slug"],
            "title": r["title"],
        })
    return result


def _expand_with_subagents(conn, ids, project_filter=True):
    """Return (expanded_ids, parent_to_subagents) for the given parent ids."""
    if not ids:
        return [], {}
    sub_map = _fetch_subagent_map(conn, ids, project_filter=project_filter)
    expanded = list(ids)
    for sub_list in sub_map.values():
        for sub in sub_list:
            if sub["id"] not in expanded:
                expanded.append(sub["id"])
    return expanded, sub_map

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
        SELECT p.id, p.name, p.worktree,
               COUNT(s.id) AS session_count,
               SUM(CASE WHEN s.parent_id IS NOT NULL THEN 1 ELSE 0 END) AS subagent_count
        FROM project p LEFT JOIN session s ON s.project_id = p.id
        GROUP BY p.id ORDER BY p.time_updated DESC
    """).fetchall()
    conn.close()
    out = []
    for r in rows:
        d = dict(r)
        d["session_count"] = r["session_count"]
        d["subagent_count"] = r["subagent_count"] or 0
        d["top_level_count"] = r["session_count"] - d["subagent_count"]
        out.append(d)
    print(json.dumps(out))


def cmd_list_sessions(pid=None):
    if pid is None:
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
        FROM session s WHERE s.project_id = ? AND s.parent_id IS NULL
        ORDER BY s.time_updated DESC
    """, (pid,)).fetchall()

    ids = [r["id"] for r in rows]
    sub_counts = {}
    if ids:
        placeholders = ",".join("?" * len(ids))
        count_rows = conn.execute(
            f"""SELECT parent_id, COUNT(*) AS n FROM session
                WHERE parent_id IN ({placeholders}) AND project_id = ?
                GROUP BY parent_id""",
            (*ids, pid),
        ).fetchall()
        for cr in count_rows:
            sub_counts[cr["parent_id"]] = cr["n"]

    conn.close()
    out = []
    for r in rows:
        d = dict(r)
        d["time_created_str"] = _epoch_to_str(r["time_created"])
        d["time_updated_str"] = _epoch_to_str(r["time_updated"])
        if d.get("first_message"):
            preview = d["first_message"][:120].replace("\n", " ")
        else:
            preview = ""
        d["preview"] = preview
        d["subagent_count"] = sub_counts.get(r["id"], 0)
        del d["first_message"]
        out.append(d)
    print(json.dumps(out))


def cmd_current_session():
    pid_file = os.path.join(OPCODE_DATA_DIR, "current_session.pid")
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


def cmd_export_sessions():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing session_ids"}))
        sys.exit(1)
    ids = sys.argv[2].split(",")
    for sid in ids:
        _validate_id(sid, "session_id")

    conn = _get_db()
    expanded_ids, sub_map = _expand_with_subagents(conn, ids, project_filter=True)
    conn.close()

    results = []

    for sid in expanded_ids:
        row = _export_fetch_session(sid)
        if not row:
            results.append({"id": sid, "error": "Session not found"})
            continue

        md = _export_render_markdown(sid, row)
        if isinstance(md, dict) and "error" in md:
            results.append(md)
            continue

        title = (row["title"] or row["slug"]).replace("/", "-").strip() or row["slug"]
        os.makedirs(EXPORT_DIR, exist_ok=True)
        filepath = os.path.join(EXPORT_DIR, f"{title}.md")
        counter = 1
        while os.path.exists(filepath):
            filepath = os.path.join(EXPORT_DIR, f"{title}_{counter}.md")
            counter += 1
        try:
            with open(filepath, "w", encoding="utf-8") as f:
                f.write(md)
            results.append({"id": sid, "slug": row["slug"], "file": filepath, "text_chars": len(md)})
        except Exception as e:
            results.append({"id": sid, "error": f"Write failed: {e}"})

    if sub_map:
        results.append({"subagent_map": sub_map})
    print(json.dumps(results))


def _export_fetch_session(sid):
    conn = _get_db()
    row = conn.execute(
        """SELECT s.id, s.slug, s.title, p.worktree
           FROM session s JOIN project p ON s.project_id = p.id
           WHERE s.id = ?""", (sid,)
    ).fetchone()
    conn.close()
    return dict(row) if row else None


def _export_render_markdown(sid, row):
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".json")
    try:
        proc = subprocess.run(["opencode", "export", sid],
                              stdout=tmp, stderr=subprocess.PIPE, timeout=300)
        tmp.close()
        if proc.returncode != 0:
            err_msg = proc.stderr.decode().strip() if proc.stderr else "Export command failed"
            return {"id": sid, "error": err_msg}
        with open(tmp.name) as f:
            data = json.load(f)
    except Exception as e:
        return {"id": sid, "error": str(e)}
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass

    md = [
        f"# {row['title'] or row['slug']}\n",
        f"> Exported from OpenCode session `{row['slug']}`\n\n",
    ]
    for msg in data.get("messages", []):
        role = msg.get("info", {}).get("role", "unknown")
        text_parts = []
        for part in msg.get("parts", []):
            if part.get("type") == "text":
                text = re.sub(r"^#", r"\#", part.get("text", ""), flags=re.MULTILINE)
                text_parts.append(text + "\n")
        if role == "assistant" and not text_parts:
            continue
        prefix = "##" if role == "user" else "###"
        md.append(f"{prefix} {role.capitalize()}\n")
        md.extend(text_parts)
        md.append("---\n")
    return "".join(md)


def cmd_preview_delete_sessions():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Missing session_ids"}))
        sys.exit(1)
    ids = sys.argv[2].split(",")
    for sid in ids:
        _validate_id(sid, "session_id")
    conn = _get_db()
    expanded_ids, sub_map = _expand_with_subagents(conn, ids, project_filter=True)
    placeholders = ",".join("?" * len(expanded_ids))
    db_sessions = conn.execute(
        f"SELECT id, slug, title, project_id FROM session WHERE id IN ({placeholders})", expanded_ids
    ).fetchall()
    conn.close()
    storage = {}
    for sid in expanded_ids:
        storage[sid] = _preview_storage_for_session(sid)
    print(json.dumps({
        "requested_ids": ids,
        "expanded_ids": expanded_ids,
        "db_sessions": [dict(r) for r in db_sessions],
        "subagent_map": sub_map,
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
        "SELECT id, slug, title, parent_id FROM session WHERE project_id = ?", (pid,)
    ).fetchall()
    conn.close()
    storage = {}
    for s in sessions:
        storage[s["id"]] = _preview_storage_for_session(s["id"])
    snap_path = os.path.join(SNAPSHOT_DIR, pid)
    sub_count = sum(1 for s in sessions if s["parent_id"])
    print(json.dumps({
        "project": dict(proj) if proj else None,
        "sessions": [dict(r) for r in sessions],
        "subagent_count": sub_count,
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
    expanded_ids, sub_map = _expand_with_subagents(conn, ids, project_filter=True)
    conn.close()
    return _do_delete_sessions(expanded_ids, sub_map)


def _do_delete_sessions(expanded_ids, sub_map=None):
    conn = _get_db()
    placeholders = ",".join("?" * len(expanded_ids))
    cursor = conn.execute(f"DELETE FROM session WHERE id IN ({placeholders})", expanded_ids)
    conn.commit()
    deleted_db = cursor.rowcount
    conn.close()
    storage_count = {"dcp": 0, "diff": 0}
    for sid in expanded_ids:
        r = _del_storage_for_session(sid)
        storage_count["dcp"] += r["dcp"]
        storage_count["diff"] += r["diff"]
    print(json.dumps({
        "deleted_db_sessions": deleted_db,
        "deleted_dcp_files": storage_count["dcp"],
        "deleted_diff_files": storage_count["diff"],
        "subagent_map": sub_map or {},
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
        "export_sessions": cmd_export_sessions,
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
        if command == "list_sessions":
            fn(sys.argv[2] if len(sys.argv) > 2 else None)
        else:
            fn()
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
