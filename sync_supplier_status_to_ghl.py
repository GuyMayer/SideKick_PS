"""
Sync supplier-status DB records into GHL contact fields and opportunity stages.

Reads supplier data from the new Open Claw SQLite DB (local or over SSH),
finds GHL contacts by session_job_no, updates available supplier fields, and
optionally moves opportunities in the Boudoir Production Pipeline.

Usage examples:
  python sync_supplier_status_to_ghl.py --ssh-host toypi.tail009b36.ts.net --dry-run
  python sync_supplier_status_to_ghl.py --ssh-host toypi.tail009b36.ts.net --apply
  python sync_supplier_status_to_ghl.py --ssh-host toypi.tail009b36.ts.net --job-ref P26010P_Johnson --apply
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from datetime import datetime
from typing import Any

import requests

from build_ghl_production_pipeline import API_VERSION, BASE_URL, _load_config
from read_supplier_status_db import _query_local, _query_remote

PIPELINE_NAME = "Boudoir Production Pipeline"
DEFAULT_REMOTE_DB = "/home/guy/.openclaw/data/supplier_status.db"
SESSION_JOB_NO_FIELD_ID = "82WRQe9Rl6o8uJQ8cgZV"

STATUS_RANK = {
    "": 0,
    "in_production": 1,
    "dispatched": 2,
    "received": 3,
}

PARSE_RESULT_RANK = {
    "ok": 0,
    "excluded_invoice": 0,
    "remote_update": 0,
    "manual_verified": 0,
    "manual_review": 1,
    "parse_error": 2,
}


def _headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Version": API_VERSION,
    }


def _request(method: str, api_key: str, path: str, *, payload: dict[str, Any] | None = None, params: dict[str, Any] | None = None) -> dict[str, Any]:
    url = f"{BASE_URL}{path}"
    resp = requests.request(
        method,
        url,
        headers=_headers(api_key),
        json=payload,
        params=params,
        timeout=60,
    )
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"{method} {path} failed: HTTP {resp.status_code} {resp.text[:300]}")
    if not resp.text:
        return {}
    try:
        return resp.json()
    except Exception:
        return {}


def _extract_job_number(job_ref: str) -> str | None:
    m = re.search(r"P(\d+)P_", job_ref or "", re.IGNORECASE)
    return m.group(1) if m else None


def _normalise_key(raw_key: str) -> str:
    key = (raw_key or "").strip()
    if "." in key:
        key = key.split(".")[-1]
    return key


def _fetch_custom_field_ids(api_key: str, location_id: str) -> dict[str, str]:
    body = _request("GET", api_key, f"/locations/{location_id}/customFields")
    fields = body.get("customFields", [])
    if not isinstance(fields, list):
        fields = []

    mapping: dict[str, str] = {}
    for f in fields:
        if not isinstance(f, dict):
            continue
        field_id = str(f.get("id") or f.get("_id") or "").strip()
        field_key = _normalise_key(str(f.get("fieldKey") or f.get("key") or ""))
        if field_id and field_key:
            mapping[field_key] = field_id

    # Ensure legacy known field is always available.
    mapping.setdefault("session_job_no", SESSION_JOB_NO_FIELD_ID)
    return mapping


def _find_contact_id_by_job_no(api_key: str, location_id: str, job_no: str) -> str | None:
    payload = {
        "locationId": location_id,
        "filters": [
            {
                "field": f"customFields.{SESSION_JOB_NO_FIELD_ID}",
                "operator": "eq",
                "value": job_no,
            }
        ],
    }
    body = _request("POST", api_key, "/contacts/search", payload=payload)
    contacts = body.get("contacts", [])
    if isinstance(contacts, list) and contacts:
        c = contacts[0]
        if isinstance(c, dict):
            cid = str(c.get("id") or "").strip()
            return cid or None
    return None


def _get_contact_opportunities(api_key: str, location_id: str, contact_id: str) -> list[dict[str, Any]]:
    payload = {"locationId": location_id, "contactId": contact_id}
    body = _request("POST", api_key, "/opportunities/search", payload=payload)
    opportunities = body.get("opportunities", [])
    if not isinstance(opportunities, list):
        return []
    return [o for o in opportunities if isinstance(o, dict)]


def _get_pipeline_and_stage_map(api_key: str, location_id: str, pipeline_name: str) -> tuple[str | None, dict[str, str]]:
    body = _request("GET", api_key, "/opportunities/pipelines", params={"locationId": location_id})
    pipelines = body.get("pipelines", [])
    if not isinstance(pipelines, list):
        pipelines = []

    target = None
    for p in pipelines:
        if isinstance(p, dict) and str(p.get("name", "")).strip() == pipeline_name:
            target = p
            break

    if not target:
        return None, {}

    pipeline_id = str(target.get("id") or target.get("_id") or "").strip() or None
    stage_map: dict[str, str] = {}
    stages = target.get("stages", [])
    if isinstance(stages, list):
        for s in stages:
            if not isinstance(s, dict):
                continue
            name = str(s.get("name") or "").strip()
            sid = str(s.get("id") or s.get("_id") or "").strip()
            if name and sid:
                stage_map[name] = sid

    return pipeline_id, stage_map


def _choose_supplier_value(rows: list[dict[str, Any]], supplier: str, field: str, product: str = "") -> str:
    candidates = [r for r in rows if str(r.get("supplier", "")).lower() == supplier]
    if product:
        product_candidates = [r for r in candidates if product in str(r.get("product", "")).lower()]
        if product_candidates:
            candidates = product_candidates
    if not candidates:
        return ""
    value = str(candidates[0].get(field, "") or "").strip()
    return value


def _choose_best_status(rows: list[dict[str, Any]], supplier: str, product: str = "") -> str:
    best = ""
    for r in rows:
        if str(r.get("supplier", "")).lower() != supplier:
            continue
        if product and product not in str(r.get("product", "")).lower():
            continue
        s = str(r.get("status", "")).lower().strip()
        if STATUS_RANK.get(s, 0) > STATUS_RANK.get(best, 0):
            best = s
    return best


def _has_product(rows: list[dict[str, Any]], supplier: str, product: str) -> bool:
    """Return True if any row matches the given supplier and product keyword."""
    return any(
        str(r.get("supplier", "")).lower() == supplier and product in str(r.get("product", "")).lower()
        for r in rows
    )


def _choose_parse_result(rows: list[dict[str, Any]]) -> str:
    worst = "ok"
    for r in rows:
        pr = str(r.get("parse_result", "ok") or "ok").strip().lower()
        if PARSE_RESULT_RANK.get(pr, 0) > PARSE_RESULT_RANK.get(worst, 0):
            worst = pr
    return worst


def _max_timestamp(rows: list[dict[str, Any]], field: str) -> str:
    values = [str(r.get(field, "") or "").strip() for r in rows]
    values = [v for v in values if v]
    if not values:
        return ""
    return max(values)


def _stage_from_rows(rows: list[dict[str, Any]]) -> str:
    statuses = [str(r.get("status", "")).strip().lower() for r in rows if str(r.get("status", "")).strip()]
    if not statuses:
        return ""

    if statuses and all(s == "received" for s in statuses):
        return "Ready To Collect"

    if any(s in ("in_production", "dispatched", "received") for s in statuses):
        return "Ordered From Lab"

    return ""


def _build_opportunity_updates(rows: list[dict[str, Any]], job_ref: str) -> dict[str, str]:
    parse_result = _choose_parse_result(rows)
    overall_status = ""
    all_statuses = [str(r.get("status", "")).lower().strip() for r in rows]

    if all_statuses and all(s == "received" for s in all_statuses):
        overall_status = "received"
    elif any(s == "dispatched" for s in all_statuses):
        overall_status = "dispatched"
    elif any(s == "in_production" for s in all_statuses):
        overall_status = "in_production"

    hold_reason = ""
    if parse_result == "parse_error":
        hold_reason = "reprintcorrection in progress"
    elif parse_result == "manual_review":
        hold_reason = "reprintcorrection in progress"

    confidence = "95"
    if parse_result == "manual_review":
        confidence = "70"
    elif parse_result == "parse_error":
        confidence = "40"

    return {
        "supplier_lookup_key": job_ref,
        "supplier_last_checked_at": _max_timestamp(rows, "email_received_at") or datetime.utcnow().isoformat(),
        "supplier_check_result": parse_result,
        "supplier_overall_status": overall_status,
        # nPhoto — books
        "book_supplier": "nPhoto" if _has_product(rows, "nphoto", "book") else "",
        "book_status": _choose_best_status(rows, "nphoto", "book"),
        "book_tracking_ref": _choose_supplier_value(rows, "nphoto", "tracking_ref", "book"),
        "book_ordered_at": _choose_supplier_value(rows, "nphoto", "ordered_at", "book"),
        # nPhoto — boxes
        "box_supplier": "nPhoto" if _has_product(rows, "nphoto", "box") else "",
        "box_status": _choose_best_status(rows, "nphoto", "box"),
        "box_tracking_ref": _choose_supplier_value(rows, "nphoto", "tracking_ref", "box"),
        "box_ordered_at": _choose_supplier_value(rows, "nphoto", "ordered_at", "box"),
        # Loxley — wall art
        "wall_art_supplier": "Loxley" if _has_product(rows, "loxleys", "wall") else "",
        "wall_art_status": _choose_best_status(rows, "loxleys", "wall"),
        "wall_art_tracking_ref": _choose_supplier_value(rows, "loxleys", "tracking_ref", "wall"),
        "wall_art_ordered_at": _choose_supplier_value(rows, "loxleys", "ordered_at", "wall"),
        # Loxley — prints (product value: "print" or "artprint")
        "prints_supplier": "Loxley" if _has_product(rows, "loxleys", "print") else "",
        "prints_status": _choose_best_status(rows, "loxleys", "print"),
        "prints_tracking_ref": _choose_supplier_value(rows, "loxleys", "tracking_ref", "print"),
        "prints_ordered_at": _choose_supplier_value(rows, "loxleys", "ordered_at", "print"),
        "production_last_seen_at": _max_timestamp(rows, "email_received_at"),
        "stage_source": "auto",
        "stage_confidence": confidence,
        "hold_reason": hold_reason,
    }


def _update_opportunity_fields(
    api_key: str,
    opportunity_id: str,
    field_id_map: dict[str, str],
    update_values: dict[str, str],
    *,
    apply_changes: bool,
) -> dict[str, Any]:
    payload_fields: list[dict[str, str]] = []
    skipped_missing_keys: list[str] = []

    for key, value in update_values.items():
        field_id = field_id_map.get(key)
        if not field_id:
            skipped_missing_keys.append(key)
            continue
        if value == "":
            continue
        payload_fields.append({"id": field_id, "field_value": value})

    if not payload_fields:
        return {
            "updated": False,
            "field_count": 0,
            "missing_field_keys": skipped_missing_keys,
        }

    if apply_changes:
        _request("PUT", api_key, f"/opportunities/{opportunity_id}", payload={"customFields": payload_fields})

    return {
        "updated": True,
        "field_count": len(payload_fields),
        "missing_field_keys": skipped_missing_keys,
    }


def _move_opportunities_stage(
    api_key: str,
    location_id: str,
    contact_id: str,
    pipeline_id: str | None,
    stage_id: str,
    *,
    apply_changes: bool,
) -> dict[str, Any]:
    opportunities = _get_contact_opportunities(api_key, location_id, contact_id)
    if pipeline_id:
        opportunities = [o for o in opportunities if str(o.get("pipelineId", "")).strip() == pipeline_id]

    moved = 0
    scanned = 0

    for opp in opportunities:
        opp_id = str(opp.get("id") or "").strip()
        if not opp_id:
            continue
        scanned += 1
        current_stage = str(opp.get("pipelineStageId") or "").strip()
        if current_stage == stage_id:
            continue

        if apply_changes:
            payload = {"pipelineStageId": stage_id}
            if pipeline_id:
                payload["pipelineId"] = pipeline_id
            _request("PUT", api_key, f"/opportunities/{opp_id}", payload=payload)
        moved += 1

    return {"opportunities_scanned": scanned, "opportunities_moved": moved}


def _load_rows(args: argparse.Namespace) -> list[dict[str, Any]]:
    job_ref = args.job_ref.strip() or None
    if args.ssh_host.strip():
        return _query_remote(args.ssh_host.strip(), args.remote_db_path.strip(), job_ref, args.limit)
    return _query_local(args.db_path.strip(), job_ref, args.limit)


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync supplier-status DB rows into GHL fields and stages")
    parser.add_argument("--db-path", default=DEFAULT_REMOTE_DB, help="Local supplier-status DB path")
    parser.add_argument("--ssh-host", default="", help="Remote host to query DB over SSH (e.g. toypi.tail009b36.ts.net)")
    parser.add_argument("--remote-db-path", default=DEFAULT_REMOTE_DB, help="Remote supplier-status DB path")
    parser.add_argument("--job-ref", default="", help="Optional single job_ref to sync")
    parser.add_argument("--limit", type=int, default=500, help="Max DB rows to load")
    parser.add_argument("--pipeline-name", default=PIPELINE_NAME, help="Target GHL pipeline name")
    parser.add_argument("--api-key", default="", help="Override GHL API key")
    parser.add_argument("--location-id", default="", help="Override GHL location ID")
    parser.add_argument("--skip-stage-update", action="store_true", help="Update contact fields only")
    parser.add_argument("--apply", action="store_true", help="Apply changes (default is dry-run)")
    parser.add_argument("--json", action="store_true", help="Print JSON summary")
    args = parser.parse_args()

    apply_changes = bool(args.apply)

    try:
        rows = _load_rows(args)
        api_key, location_id = _load_config(args.api_key or None, args.location_id or None)
    except Exception as exc:
        print(f"ERROR: {exc}")
        return 1

    by_job: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if not isinstance(row, dict):
            continue
        job_ref = str(row.get("job_ref", "")).strip()
        if job_ref:
            by_job[job_ref].append(row)

    if not by_job:
        print("No supplier-status records to sync.")
        return 0

    try:
        field_id_map = _fetch_custom_field_ids(api_key, location_id)
        pipeline_id, stage_map = _get_pipeline_and_stage_map(api_key, location_id, args.pipeline_name)
    except Exception as exc:
        print(f"ERROR: Failed loading GHL metadata: {exc}")
        return 1

    summary: dict[str, Any] = {
        "mode": "apply" if apply_changes else "dry-run",
        "jobs_seen": len(by_job),
        "contacts_found": 0,
        "contacts_missing": 0,
        "opportunity_field_updates": 0,
        "opportunities_moved": 0,
        "warnings": [],
        "jobs": [],
    }

    for job_ref, job_rows in sorted(by_job.items()):
        client_job_no = _extract_job_number(job_ref)
        if not client_job_no:
            summary["warnings"].append(f"{job_ref}: could not extract session_job_no")
            continue

        try:
            contact_id = _find_contact_id_by_job_no(api_key, location_id, client_job_no)
        except Exception as exc:
            summary["warnings"].append(f"{job_ref}: contact search failed ({exc})")
            continue

        if not contact_id:
            # Fallback: search by last name extracted from job ref (e.g. P26010P_Johnson → Johnson)
            last_name = job_ref.split("_", 1)[1] if "_" in job_ref else ""
            last_name = last_name.split("_")[0].strip()  # strip any further suffixes
            if last_name:
                try:
                    from sync_ps_invoice import find_ghl_contact_by_name
                    contact_id = find_ghl_contact_by_name("", last_name) or ""
                    if contact_id:
                        summary["warnings"].append(
                            f"{job_ref}: session_job_no not found, resolved via name fallback ({last_name})"
                        )
                except Exception as exc:
                    summary["warnings"].append(f"{job_ref}: name fallback search failed ({exc})")

        if not contact_id:
            summary["contacts_missing"] += 1
            summary["warnings"].append(f"{job_ref}: no contact found for session_job_no={client_job_no}")
            continue

        summary["contacts_found"] += 1

        # Find the opportunity in the Boudoir Production Pipeline
        opportunities = _get_contact_opportunities(api_key, location_id, contact_id)
        if pipeline_id:
            opportunities = [o for o in opportunities if str(o.get("pipelineId", "")).strip() == pipeline_id]

        if not opportunities:
            summary["warnings"].append(f"{job_ref}: no opportunity found for contact {contact_id}")
            continue

        # Use the first matching opportunity
        opportunity_id = str(opportunities[0].get("id") or "").strip()

        update_values = _build_opportunity_updates(job_rows, job_ref)
        stage_name = _stage_from_rows(job_rows)

        try:
            field_result = _update_opportunity_fields(
                api_key,
                opportunity_id,
                field_id_map,
                update_values,
                apply_changes=apply_changes,
            )
        except Exception as exc:
            summary["warnings"].append(f"{job_ref}: opportunity field update failed ({exc})")
            continue

        if field_result.get("updated"):
            summary["opportunity_field_updates"] += 1

        missing_keys = field_result.get("missing_field_keys", [])
        if isinstance(missing_keys, list) and missing_keys:
            summary["warnings"].append(f"{job_ref}: missing custom fields in GHL ({', '.join(missing_keys)})")

        moved_count = 0
        if not args.skip_stage_update and stage_name:
            stage_id = stage_map.get(stage_name, "")
            if not stage_id:
                summary["warnings"].append(f"{job_ref}: stage '{stage_name}' not found in pipeline '{args.pipeline_name}'")
            else:
                try:
                    move_result = _move_opportunities_stage(
                        api_key,
                        location_id,
                        contact_id,
                        pipeline_id,
                        stage_id,
                        apply_changes=apply_changes,
                    )
                    moved_count = int(move_result.get("opportunities_moved", 0) or 0)
                    summary["opportunities_moved"] += moved_count
                except Exception as exc:
                    summary["warnings"].append(f"{job_ref}: stage move failed ({exc})")

        summary["jobs"].append(
            {
                "job_ref": job_ref,
                "contact_id": contact_id,
                "opportunity_id": opportunity_id,
                "stage_target": stage_name,
                "fields_updated": bool(field_result.get("updated")),
                "opportunities_moved": moved_count,
            }
        )

    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print(f"Mode: {summary['mode']}")
        print(f"Jobs seen: {summary['jobs_seen']}")
        print(f"Contacts found: {summary['contacts_found']} | missing: {summary['contacts_missing']}")
        print(f"Opportunity field updates: {summary['opportunity_field_updates']}")
        print(f"Opportunities moved: {summary['opportunities_moved']}")
        if summary["warnings"]:
            print("Warnings:")
            for w in summary["warnings"]:
                print(f"- {w}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
