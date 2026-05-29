"""
Build GHL production pipeline + custom fields and print ID registry.

Usage:
  python build_ghl_production_pipeline.py --apply
  python build_ghl_production_pipeline.py --dry-run
"""

from __future__ import annotations

import argparse
import base64
import configparser
import json
import os
import sys
from dataclasses import dataclass
from typing import Any

import requests

BASE_URL = "https://services.leadconnectorhq.com"
API_VERSION = "2021-07-28"
PIPELINE_NAME = "Boudoir Production Pipeline"

STAGES = [
    "Order Confirmed",
    "Retouching",
    "Design",
    "Awaiting Approval",
    "With Supplier",
    "QC / Delivery Prep",
    "Ready for Collection",
    "Collected",
    "On Hold",
]

KNOWN_FIELDS: dict[str, str] = {
    "session_job_no": "82WRQe9Rl6o8uJQ8cgZV",
    "session_status": "rcBTBSNw75gA0BOaVPEr",
    "session_date": "j2lMRPMOYHIxapnz5qDK",
}

REQUIRED_SCOPES = [
    "contacts.readonly",
    "contacts.write",
    "opportunities.readonly",
    "opportunities.write",
    "customFields.readonly",
    "customFields.write",
    "invoices.readonly",
    "invoices.write",
    "payments/orders.readonly",
    "payments/orders.write",
    "medias.readonly",
    "medias.write",
]


@dataclass
class FieldSpec:
    key: str
    name: str
    data_type: str
    options: list[str] | None = None


FIELD_SPECS = [
    FieldSpec("production_stage", "Production Stage", "SINGLE_OPTIONS", STAGES),
    FieldSpec("production_last_seen_at", "Production Last Seen At", "DATE"),
    FieldSpec("paid_total", "Paid Total", "NUMERICAL"),
    FieldSpec("paid_ratio_percent", "Paid Ratio Percent", "NUMERICAL"),
    FieldSpec("payments_count", "Payments Count", "NUMERICAL"),
    FieldSpec("amount_remaining", "Amount Remaining", "NUMERICAL"),
    FieldSpec("delivery_ready", "Delivery Ready", "SINGLE_OPTIONS", ["Yes", "No"]),
    FieldSpec("priority_score", "Priority Score", "NUMERICAL"),
    FieldSpec("queue_rank", "Queue Rank", "NUMERICAL"),
    FieldSpec("stage_source", "Stage Source", "SINGLE_OPTIONS", ["manual", "auto"]),
    FieldSpec("stage_confidence", "Stage Confidence", "NUMERICAL"),
    FieldSpec("hold_reason", "Hold Reason", "SINGLE_OPTIONS", ["Awaiting Payment Plan", "Client Requested Delay", "Reprint/Correction in Progress", "Awaiting Client Response", "Cancellation/Dispute/BadDebt"]),
    FieldSpec("supplier_lookup_key", "Supplier Lookup Key", "TEXT"),
    FieldSpec("supplier_last_checked_at", "Supplier Last Checked At", "DATE"),
    FieldSpec(
        "supplier_check_result",
        "Supplier Check Result",
        "SINGLE_OPTIONS",
        ["ok", "manual_review", "parse_error", "excluded_invoice", "remote_update", "manual_verified"],
    ),
    FieldSpec(
        "supplier_overall_status",
        "Supplier Overall Status",
        "SINGLE_OPTIONS",
        ["in_production", "dispatched", "received"],
    ),
    # nPhoto products: books and boxes
    FieldSpec("book_supplier", "Book Supplier", "TEXT"),
    FieldSpec(
        "book_status",
        "Book Status",
        "SINGLE_OPTIONS",
        ["not_ordered", "ordered", "in_production", "dispatched", "received"],
    ),
    FieldSpec("book_tracking_ref", "Book Tracking Ref", "TEXT"),
    FieldSpec("book_ordered_at", "Book Ordered At", "DATE"),
    FieldSpec("box_supplier", "Box Supplier", "TEXT"),
    FieldSpec(
        "box_status",
        "Box Status",
        "SINGLE_OPTIONS",
        ["not_ordered", "ordered", "in_production", "dispatched", "received"],
    ),
    FieldSpec("box_tracking_ref", "Box Tracking Ref", "TEXT"),
    FieldSpec("box_ordered_at", "Box Ordered At", "DATE"),
    # Loxley products: wall art and prints
    FieldSpec("wall_art_supplier", "Wall Art Supplier", "TEXT"),
    FieldSpec(
        "wall_art_status",
        "Wall Art Status",
        "SINGLE_OPTIONS",
        ["not_ordered", "ordered", "in_production", "dispatched", "received"],
    ),
    FieldSpec("wall_art_tracking_ref", "Wall Art Tracking Ref", "TEXT"),
    FieldSpec("wall_art_ordered_at", "Wall Art Ordered At", "DATE"),
    FieldSpec("prints_supplier", "Prints Supplier", "TEXT"),
    FieldSpec(
        "prints_status",
        "Prints Status",
        "SINGLE_OPTIONS",
        ["not_ordered", "ordered", "in_production", "dispatched", "received"],
    ),
    FieldSpec("prints_tracking_ref", "Prints Tracking Ref", "TEXT"),
    FieldSpec("prints_ordered_at", "Prints Ordered At", "DATE"),
]


def _load_config(api_key_arg: str | None, location_id_arg: str | None) -> tuple[str, str]:
    if api_key_arg and location_id_arg:
        return api_key_arg, location_id_arg

    api_key = api_key_arg or ""
    location_id = location_id_arg or ""

    appdata = os.environ.get("APPDATA", "")
    script_dir = os.path.dirname(os.path.abspath(__file__))

    cred_paths = [
        os.path.join(script_dir, "credentials.json"),
        os.path.join(appdata, "SideKick_PS", "credentials.json"),
        os.path.join(script_dir, "ghl_credentials.json"),
        os.path.join(appdata, "SideKick_PS", "ghl_credentials.json"),
    ]

    if not api_key:
        for path in cred_paths:
            if not os.path.exists(path):
                continue
            try:
                with open(path, "r", encoding="utf-8-sig") as f:
                    data = json.load(f)
                enc = data.get("api_key_b64", "")
                if enc:
                    api_key = base64.b64decode(enc).decode("utf-8")
                if not location_id:
                    location_id = data.get("location_id", "")
                if api_key:
                    break
            except Exception:
                continue

    ini_paths = [
        os.path.join(script_dir, "SideKick_PS.ini"),
        os.path.join(os.path.dirname(script_dir), "SideKick_PS.ini"),
        os.path.join(appdata, "SideKick_PS", "SideKick_PS.ini"),
    ]
    if (not api_key) or (not location_id):
        for path in ini_paths:
            if not os.path.exists(path):
                continue
            parser = configparser.ConfigParser()
            try:
                parser.read(path, encoding="utf-8-sig")
            except Exception:
                continue
            ghl = parser["GHL"] if parser.has_section("GHL") else {}
            if not api_key:
                api_b64 = ghl.get("API_Key_V2_B64") or ghl.get("API_Key_B64") or ""
                if api_b64:
                    try:
                        api_key = base64.b64decode(api_b64).decode("utf-8")
                    except Exception:
                        pass
            if not location_id:
                location_id = ghl.get("LocationID", "")
            if api_key and location_id:
                break

    if not api_key or not location_id:
        raise RuntimeError(
            "Missing GHL API key and/or Location ID. Pass --api-key and --location-id or configure SideKick credentials."
        )

    return api_key.strip(), location_id.strip()


def _headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Version": API_VERSION,
    }


def _try_request(
    method: str,
    api_key: str,
    candidates: list[tuple[str, dict[str, Any] | None, dict[str, Any] | None]],
) -> tuple[requests.Response | None, str | None]:
    last_response: requests.Response | None = None
    last_error: str | None = None

    for path, params, payload in candidates:
        url = f"{BASE_URL}{path}"
        try:
            response = requests.request(
                method,
                url,
                headers=_headers(api_key),
                params=params,
                json=payload,
                timeout=30,
            )
        except Exception as exc:
            last_error = f"{path}: {exc}"
            continue

        if response.status_code in (200, 201):
            return response, None

        if response.status_code in (400, 401, 403, 422):
            return response, None

        last_response = response
        last_error = f"{path}: HTTP {response.status_code}"

    return last_response, last_error


def _extract_list(payload: dict[str, Any], keys: list[str]) -> list[dict[str, Any]]:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    return []


def fetch_custom_fields(api_key: str, location_id: str) -> list[dict[str, Any]]:
    candidates = [
        (f"/locations/{location_id}/customFields", None, None),
        ("/custom-fields", {"locationId": location_id}, None),
    ]
    response, err = _try_request("GET", api_key, candidates)
    if response is None:
        raise RuntimeError(f"Unable to query custom fields: {err}")
    if response.status_code != 200:
        raise RuntimeError(f"Custom fields read failed: HTTP {response.status_code} {response.text[:300]}")
    data = response.json()
    return _extract_list(data, ["customFields", "fields"])


def create_custom_field(api_key: str, location_id: str, spec: FieldSpec) -> str:
    options = spec.options or []
    option_rows = options

    payloads = [
        {
            "name": spec.name,
            "fieldKey": f"opportunity.{spec.key}",
            "dataType": spec.data_type,
            "model": "opportunity",
            "options": option_rows,
        },
        {
            "name": spec.name,
            "fieldKey": f"opportunity.{spec.key}",
            "dataType": spec.data_type,
            "options": option_rows,
            "locationId": location_id,
        },
        {
            "name": spec.name,
            "fieldKey": spec.key,
            "dataType": spec.data_type,
            "options": option_rows,
            "locationId": location_id,
        },
    ]

    candidates: list[tuple[str, dict[str, Any] | None, dict[str, Any] | None]] = []
    for payload in payloads:
        candidates.append((f"/locations/{location_id}/customFields", None, payload))
        candidates.append(("/custom-fields", {"locationId": location_id}, payload))

    response, err = _try_request("POST", api_key, candidates)
    if response is None:
        raise RuntimeError(f"Create custom field failed for {spec.key}: {err}")
    if response.status_code == 400:
        # GHL returns existingId in 400 body when fieldKey already exists
        try:
            body = response.json()
            existing_id = body.get("meta", {}).get("existingId", "")
            if existing_id:
                return existing_id
        except Exception:
            pass
        raise RuntimeError(f"Create custom field failed for {spec.key}: HTTP {response.status_code} {response.text[:300]}")
    if response.status_code not in (200, 201):
        raise RuntimeError(f"Create custom field failed for {spec.key}: HTTP {response.status_code} {response.text[:300]}")

    body = response.json() if response.text else {}
    field = body.get("customField") or body.get("field") or body
    field_id = field.get("id") if isinstance(field, dict) else None
    if not field_id:
        raise RuntimeError(f"Custom field {spec.key} created but ID missing in response")
    return field_id


def delete_custom_field(api_key: str, location_id: str, field_id: str, field_name: str = "") -> bool:
    candidates: list[tuple[str, dict[str, Any] | None, dict[str, Any] | None]] = [
        (f"/locations/{location_id}/customFields/{field_id}", None, None),
        (f"/custom-fields/{field_id}", {"locationId": location_id}, None),
    ]
    response, err = _try_request("DELETE", api_key, candidates)
    if response is None:
        print(f"  ⚠ Delete failed for {field_name} ({field_id}): {err}")
        return False
    if response.status_code not in (200, 204):
        print(f"  ⚠ Delete failed for {field_name} ({field_id}): HTTP {response.status_code}")
        return False
    return True


def fetch_pipelines(api_key: str, location_id: str) -> list[dict[str, Any]]:
    candidates = [
        ("/opportunities/pipelines", {"locationId": location_id}, None),
        ("/opportunities/pipelines", None, None),
        ("/pipelines", {"locationId": location_id}, None),
    ]
    response, err = _try_request("GET", api_key, candidates)
    if response is None:
        raise RuntimeError(f"Unable to query pipelines: {err}")
    if response.status_code != 200:
        raise RuntimeError(f"Pipeline read failed: HTTP {response.status_code} {response.text[:300]}")
    data = response.json()
    return _extract_list(data, ["pipelines", "data", "opportunityPipelines"])


def create_pipeline(api_key: str, location_id: str, name: str, stages: list[str]) -> dict[str, Any]:
    stage_rows = [{"name": stage} for stage in stages]
    payloads = [
        {"locationId": location_id, "name": name, "stages": stage_rows},
        {"name": name, "stages": stage_rows},
    ]

    candidates: list[tuple[str, dict[str, Any] | None, dict[str, Any] | None]] = []
    for payload in payloads:
        candidates.append(("/opportunities/pipelines", None, payload))
        candidates.append(("/opportunities/pipelines", {"locationId": location_id}, payload))
        candidates.append(("/pipelines", {"locationId": location_id}, payload))

    response, err = _try_request("POST", api_key, candidates)
    if response is None:
        raise RuntimeError(f"Create pipeline failed: {err}")
    if response.status_code not in (200, 201):
        raise RuntimeError(f"Create pipeline failed: HTTP {response.status_code} {response.text[:300]}")

    body = response.json() if response.text else {}
    pipeline = body.get("pipeline") or body.get("data") or body
    if not isinstance(pipeline, dict):
        raise RuntimeError("Create pipeline returned unexpected payload")
    return pipeline


def create_stage(api_key: str, location_id: str, pipeline_id: str, stage_name: str) -> str:
    payloads = [
        {"name": stage_name, "locationId": location_id},
        {"name": stage_name},
    ]

    candidates: list[tuple[str, dict[str, Any] | None, dict[str, Any] | None]] = []
    for payload in payloads:
        candidates.append((f"/opportunities/pipelines/{pipeline_id}/stages", None, payload))
        candidates.append((f"/opportunities/pipelines/{pipeline_id}/stages", {"locationId": location_id}, payload))
        candidates.append((f"/pipelines/{pipeline_id}/stages", None, payload))
        candidates.append((f"/pipelines/{pipeline_id}/stages", {"locationId": location_id}, payload))

    response, err = _try_request("POST", api_key, candidates)
    if response is None:
        raise RuntimeError(f"Create stage failed for {stage_name}: {err}")
    if response.status_code not in (200, 201):
        raise RuntimeError(f"Create stage failed for {stage_name}: HTTP {response.status_code} {response.text[:300]}")

    body = response.json() if response.text else {}
    stage = body.get("stage") or body.get("data") or body
    if not isinstance(stage, dict):
        raise RuntimeError(f"Create stage returned unexpected payload for {stage_name}")
    stage_id = str(stage.get("id", "")).strip()
    if not stage_id:
        raise RuntimeError(f"Create stage response missing ID for {stage_name}")
    return stage_id


def upsert_pipeline(api_key: str, location_id: str, apply_changes: bool) -> tuple[str | None, dict[str, str], list[str]]:
    logs: list[str] = []
    stages_out: dict[str, str] = {}

    pipelines = fetch_pipelines(api_key, location_id)
    found = None
    for item in pipelines:
        if item.get("name", "").strip().lower() == PIPELINE_NAME.lower():
            found = item
            break

    if found:
        pipeline_id = str(found.get("id", "")).strip() or None
        logs.append(f"Pipeline exists: {PIPELINE_NAME} ({pipeline_id or 'ID unknown'})")
        stage_list = _extract_list(found, ["stages"])
        for row in stage_list:
            name = str(row.get("name", "")).strip()
            sid = str(row.get("id", "")).strip()
            if name and sid:
                stages_out[name] = sid
        missing = [name for name in STAGES if name not in stages_out]
        if missing:
            logs.append("Missing stages on existing pipeline: " + ", ".join(missing))
            if apply_changes and pipeline_id:
                for stage_name in missing:
                    try:
                        stage_id = create_stage(api_key, location_id, pipeline_id, stage_name)
                        stages_out[stage_name] = stage_id
                        logs.append(f"Stage created: {stage_name} ({stage_id})")
                    except RuntimeError as exc:
                        logs.append(str(exc))
        return pipeline_id, stages_out, logs

    logs.append(f"Pipeline missing: {PIPELINE_NAME}")
    if not apply_changes:
        logs.append("Dry-run mode: pipeline creation skipped")
        return None, stages_out, logs

    created = create_pipeline(api_key, location_id, PIPELINE_NAME, STAGES)
    pipeline_id = str(created.get("id", "")).strip() or None
    if not pipeline_id:
        logs.append("Pipeline created but response had no ID; re-run with --debug after checking GHL UI")
    else:
        logs.append(f"Pipeline created: {PIPELINE_NAME} ({pipeline_id})")

    created_stages = _extract_list(created, ["stages"])
    for row in created_stages:
        name = str(row.get("name", "")).strip()
        sid = str(row.get("id", "")).strip()
        if name and sid:
            stages_out[name] = sid

    return pipeline_id, stages_out, logs


def upsert_fields(api_key: str, location_id: str, apply_changes: bool) -> tuple[dict[str, str], list[str]]:
    logs: list[str] = []
    id_map: dict[str, str] = dict(KNOWN_FIELDS)

    existing = fetch_custom_fields(api_key, location_id)
    by_key: dict[str, str] = {}
    for row in existing:
        fid = str(row.get("id", "")).strip()
        if not fid:
            continue
        field_key = str(row.get("fieldKey", "")).strip().lower()
        name = str(row.get("name", "")).strip().lower()
        if field_key:
            by_key[field_key] = fid
        if name:
            by_key[name] = fid

    # --- Clean up old contact-level duplicates ---
    contact_fields_to_delete: list[tuple[str, str]] = []
    for spec in FIELD_SPECS:
        # GHL double-prefixes: fieldKey "contact.book_status" becomes "contact.contactbook_status"
        contact_key = f"contact.{spec.key}".lower()
        contact_key_double = f"contact.contact{spec.key}".lower()
        contact_id = by_key.get(contact_key_double) or by_key.get(contact_key)
        if contact_id:
            contact_fields_to_delete.append((contact_id, spec.name))

    if contact_fields_to_delete and apply_changes:
        logs.append(f"Deleting {len(contact_fields_to_delete)} old contact-level duplicate fields...")
        for fid, fname in contact_fields_to_delete:
            if delete_custom_field(api_key, location_id, fid, fname):
                logs.append(f"  Deleted contact-level: {fname} ({fid})")
            else:
                logs.append(f"  ⚠ Could not delete: {fname} ({fid})")
        # Remove deleted entries from by_key so they don't block opportunity creation
        for spec in FIELD_SPECS:
            contact_key = f"contact.{spec.key}".lower()
            contact_key_double = f"contact.contact{spec.key}".lower()
            by_key.pop(contact_key_double, None)
            by_key.pop(contact_key, None)
            by_key.pop(spec.name.lower(), None)
            by_key.pop(spec.key.lower(), None)
    elif contact_fields_to_delete:
        logs.append(f"Would delete {len(contact_fields_to_delete)} old contact-level duplicate fields (dry-run)")

    # --- Create/map opportunity-level fields ---
    for spec in FIELD_SPECS:
        # GHL double-prefixes: fieldKey "opportunity.book_status" becomes "opportunity.opportunitybook_status"
        key_opp = f"opportunity.{spec.key}".lower()
        key_opp_double = f"opportunity.opportunity{spec.key}".lower()
        existing_id = by_key.get(key_opp_double) or by_key.get(key_opp) or by_key.get(spec.name.lower()) or by_key.get(spec.key.lower())
        if existing_id:
            id_map[spec.key] = existing_id
            logs.append(f"Field exists: {spec.key} ({existing_id})")
            continue

        logs.append(f"Field missing: {spec.key}")
        if not apply_changes:
            continue

        created_id = create_custom_field(api_key, location_id, spec)
        id_map[spec.key] = created_id
        logs.append(f"Field created: {spec.key} ({created_id})")

    return id_map, logs


def print_scope_requirements() -> None:
    print("Required GHL scopes for this builder:")
    for scope in REQUIRED_SCOPES:
        print(f"- {scope}")


def print_registry(
    location_id: str,
    pipeline_id: str | None,
    stage_ids: dict[str, str],
    field_ids: dict[str, str],
) -> None:
    registry = {
        "location_id": location_id,
        "pipeline": {
            "name": PIPELINE_NAME,
            "id": pipeline_id,
            "stages": {stage: stage_ids.get(stage, "") for stage in STAGES},
        },
        "custom_fields": field_ids,
    }

    print("\nID_REGISTRY_JSON_START")
    print(json.dumps(registry, indent=2))
    print("ID_REGISTRY_JSON_END\n")

    print("Stage IDs:")
    for stage in STAGES:
        print(f"- {stage}: {stage_ids.get(stage, 'TODO')}")

    print("\nField IDs:")
    keys = list(KNOWN_FIELDS.keys()) + [spec.key for spec in FIELD_SPECS]
    for key in keys:
        print(f"- {key}: {field_ids.get(key, 'TODO')}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build GHL production pipeline and fields for SideKick_PS")
    parser.add_argument("--api-key", help="GHL Private Integration token (pit-...)")
    parser.add_argument("--location-id", help="GHL Location ID")
    parser.add_argument("--apply", action="store_true", help="Apply changes in GHL")
    parser.add_argument("--dry-run", action="store_true", help="Inspect only; do not create anything")
    parser.add_argument("--debug", action="store_true", help="Verbose output")
    args = parser.parse_args()

    if args.apply and args.dry_run:
        print("ERROR: Use either --apply or --dry-run, not both", file=sys.stderr)
        return 2

    apply_changes = bool(args.apply)
    if not args.apply and not args.dry_run:
        print("No mode specified. Defaulting to --dry-run. Use --apply to create/update.")

    try:
        api_key, location_id = _load_config(args.api_key, args.location_id)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    print_scope_requirements()
    print(f"\nMode: {'APPLY' if apply_changes else 'DRY-RUN'}")
    print(f"Location ID: {location_id}")

    try:
        pipeline_id, stage_ids, pipeline_logs = upsert_pipeline(api_key, location_id, apply_changes)
        field_ids, field_logs = upsert_fields(api_key, location_id, apply_changes)
    except RuntimeError as exc:
        print(f"\nERROR: {exc}", file=sys.stderr)
        print("If this is a 403, update your Private Integration scopes and re-run.")
        return 1

    print("\nPipeline:")
    for row in pipeline_logs:
        print(f"- {row}")

    print("\nFields:")
    for row in field_logs:
        print(f"- {row}")

    print_registry(location_id, pipeline_id, stage_ids, field_ids)

    if args.debug:
        print("\nDebug summary:")
        print(f"- Base URL: {BASE_URL}")
        print(f"- API version header: {API_VERSION}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
