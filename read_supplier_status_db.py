"""
Read supplier status records from the Open Claw SQLite database.

Supports both:
- Local file access (when running on the same machine as the DB)
- Remote ToyPi access over SSH (queries remotely, returns JSON)

Usage examples:
  python read_supplier_status_db.py --db-path /home/guy/.openclaw/data/supplier_status.db
  python read_supplier_status_db.py --ssh-host toypi.tail009b36.ts.net --limit 20
  python read_supplier_status_db.py --ssh-host toypi.tail009b36.ts.net --job-ref P26010P_Johnson
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import subprocess
import sys
from typing import Any

DEFAULT_REMOTE_DB = "/home/guy/.openclaw/data/supplier_status.db"


def _query_local(db_path: str, job_ref: str | None, limit: int, shoot_no: str = "", last_name: str = "") -> list[dict[str, Any]]:
    if not os.path.exists(db_path):
        raise RuntimeError(f"Database not found: {db_path}")

    sql = """
    SELECT
      job_ref,
      supplier,
      product,
      status,
      ordered_at,
      dispatched_at,
      tracking_ref,
      email_subject,
      email_received_at,
      parse_result,
      updated_at
    FROM supplier_orders
    """

    params: list[Any] = []
    conditions: list[str] = []

    if job_ref:
        conditions.append("job_ref = ?")
        params.append(job_ref)
    # shoot_no LIKE handles: exact shoot_no stored without last_name, and
    # multi-shoot order refs like 'P26024p - P26025p - P26028P'
    if shoot_no and shoot_no.upper() != (job_ref or "").upper():
        conditions.append("UPPER(job_ref) LIKE UPPER(?)")
        params.append(f"%{shoot_no}%")
    if last_name:
        conditions.append("UPPER(job_ref) LIKE UPPER(?)")
        params.append(f"%{last_name}%")

    if conditions:
        sql += " WHERE " + " OR ".join(conditions)

    sql += " ORDER BY COALESCE(updated_at, email_received_at) DESC LIMIT ?"
    params.append(limit)

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        rows = conn.execute(sql, params).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def _ssh_quote(s: str) -> str:
    """Single-quote a string for safe use in a remote shell command."""
    return "'" + s.replace("'", "'\\''") + "'"


def _query_remote(ssh_host: str, remote_db_path: str, job_ref: str | None, limit: int, shoot_no: str = "", last_name: str = "") -> list[dict[str, Any]]:
    remote_script = r'''
import json
import sqlite3
import sys

remote_db_path = sys.argv[1]
limit = int(sys.argv[2])
job_ref   = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None
shoot_no  = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else ""
last_name = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else ""

sql = """
SELECT
  job_ref,
  supplier,
  product,
  status,
  ordered_at,
  dispatched_at,
  tracking_ref,
  email_subject,
  email_received_at,
  parse_result,
  updated_at
FROM supplier_orders
"""
params = []
conditions = []

if job_ref:
    conditions.append("job_ref = ?")
    params.append(job_ref)
if shoot_no and shoot_no.upper() != (job_ref or "").upper():
    conditions.append("UPPER(job_ref) LIKE UPPER(?)")
    params.append("%" + shoot_no + "%")
if last_name:
    conditions.append("UPPER(job_ref) LIKE UPPER(?)")
    params.append("%" + last_name + "%")

if conditions:
    sql += " WHERE " + " OR ".join(conditions)

sql += " ORDER BY COALESCE(updated_at, email_received_at) DESC LIMIT ?"
params.append(limit)

conn = sqlite3.connect(remote_db_path)
conn.row_factory = sqlite3.Row
try:
    rows = conn.execute(sql, params).fetchall()
    print(json.dumps([dict(r) for r in rows]))
finally:
    conn.close()
'''

    # Pass script via stdin to avoid SSH/Windows quoting issues with multi-line -c scripts
    remote_cmd = (
        f"python3 - {_ssh_quote(remote_db_path)} {limit}"
        f" {_ssh_quote(job_ref or '')} {_ssh_quote(shoot_no or '')} {_ssh_quote(last_name or '')}"
    )
    cmd = ["ssh", ssh_host, remote_cmd]

    proc = subprocess.run(cmd, input=remote_script, capture_output=True, text=True, timeout=60)
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout).strip()
        raise RuntimeError(f"Remote query failed ({ssh_host}): {err}")

    output = (proc.stdout or "").strip()
    if not output:
        return []

    try:
        data = json.loads(output)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Remote query returned non-JSON output: {output[:300]}") from exc

    if not isinstance(data, list):
        raise RuntimeError("Remote query returned invalid payload (expected a list)")

    return [row for row in data if isinstance(row, dict)]


def _apply_filters(
    rows: list[dict[str, Any]],
    supplier: str | None,
    status: str | None,
) -> list[dict[str, Any]]:
    filtered = rows
    if supplier:
        wanted = supplier.strip().lower()
        filtered = [r for r in filtered if str(r.get("supplier", "")).lower() == wanted]

    if status:
        wanted = status.strip().lower()
        filtered = [r for r in filtered if str(r.get("status", "")).lower() == wanted]

    return filtered


def _print_table(rows: list[dict[str, Any]]) -> None:
    if not rows:
        print("No records found.")
        return

    headers = ["job_ref", "supplier", "product", "status", "tracking_ref", "parse_result", "updated_at"]
    widths = {h: len(h) for h in headers}

    for row in rows:
        for h in headers:
            widths[h] = max(widths[h], len(str(row.get(h, "") or "")))

    line = " | ".join(h.ljust(widths[h]) for h in headers)
    sep = "-+-".join("-" * widths[h] for h in headers)
    print(line)
    print(sep)
    for row in rows:
        print(" | ".join(str(row.get(h, "") or "").ljust(widths[h]) for h in headers))


def main() -> int:
    parser = argparse.ArgumentParser(description="Read supplier-status DB records (local or remote over SSH)")
    parser.add_argument("--db-path", default=DEFAULT_REMOTE_DB, help="Local SQLite path (default: Open Claw path)")
    parser.add_argument("--ssh-host", default="", help="Optional SSH host for remote query (e.g. toypi.tail009b36.ts.net)")
    parser.add_argument("--remote-db-path", default=DEFAULT_REMOTE_DB, help="Remote SQLite path when using --ssh-host")
    parser.add_argument("--job-ref", default="", help="Filter by exact job_ref")
    parser.add_argument("--supplier", default="", choices=["", "nphoto", "loxleys"], help="Filter by supplier")
    parser.add_argument("--status", default="", choices=["", "in_production", "dispatched", "received"], help="Filter by status")
    parser.add_argument("--limit", type=int, default=50, help="Max rows to return before local filters")
    parser.add_argument("--json", action="store_true", help="Print JSON output")

    args = parser.parse_args()

    job_ref = args.job_ref.strip() or None

    try:
        if args.ssh_host.strip():
            rows = _query_remote(args.ssh_host.strip(), args.remote_db_path.strip(), job_ref, args.limit)
        else:
            rows = _query_local(args.db_path.strip(), job_ref, args.limit)

        rows = _apply_filters(rows, args.supplier or None, args.status or None)

    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        _print_table(rows)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
