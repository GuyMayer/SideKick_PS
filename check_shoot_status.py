"""
Check production status for a shoot: Loxleys, nphoto, and GoCardless.

Usage:
  python check_shoot_status.py P25097P_Field
  python check_shoot_status.py P25097P_Field --json
  python check_shoot_status.py P25097P_Field --ssh-host toypi.tail009b36.ts.net
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys

# ---------------------------------------------------------------------------
# Supplier DB (toypi SSH)
# ---------------------------------------------------------------------------

DEFAULT_SSH_HOST = "toypi.tail009b36.ts.net"
DEFAULT_REMOTE_DB = "/home/guy/.openclaw/data/supplier_status.db"

def _check_suppliers(job_ref: str, ssh_host: str, remote_db: str, shoot_no: str = "", last_name: str = "") -> dict:
    """Query toypi supplier_orders for all rows matching job_ref."""
    try:
        from read_supplier_status_db import _query_remote, _query_local
    except ImportError:
        return {"error": "read_supplier_status_db not found"}

    try:
        if ssh_host:
            rows = _query_remote(ssh_host, remote_db, job_ref, limit=20, shoot_no=shoot_no, last_name=last_name)
        else:
            rows = _query_local(remote_db, job_ref, limit=20, shoot_no=shoot_no, last_name=last_name)
    except Exception as exc:
        return {"error": str(exc)}

    result: dict[str, dict] = {}
    for row in rows:
        supplier = str(row.get("supplier") or "unknown").lower()
        # Keep the most recent row per supplier (query is DESC by updated_at)
        if supplier not in result:
            result[supplier] = {
                "status": row.get("status") or "",
                "product": row.get("product") or "",
                "ordered_at": row.get("ordered_at") or "",
                "dispatched_at": row.get("dispatched_at") or "",
                "tracking_ref": row.get("tracking_ref") or "",
                "parse_result": row.get("parse_result") or "",
                "updated_at": row.get("updated_at") or "",
            }
    return result


# ---------------------------------------------------------------------------
# GoCardless mandate + plan check
# ---------------------------------------------------------------------------

def _load_gc_config():
    """Load GCConfig from SideKick_GC credentials (same search path as GC app)."""
    try:
        # Add SideKick_GC to path so we can import its config module
        gc_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "SideKick_GC")
        if gc_dir not in sys.path:
            sys.path.insert(0, gc_dir)
        from sidekick_gc.config import load_config
        return load_config()
    except Exception as exc:
        return None, str(exc)


def _check_gocardless(email: str = "", shoot_no: str = "", client_name: str = "") -> dict:
    """Look up mandate and payment plan status by trying multiple search strategies."""
    cfg_result = _load_gc_config()
    if isinstance(cfg_result, tuple):
        cfg, err = cfg_result
    else:
        cfg = cfg_result
        err = None

    if cfg is None or not getattr(cfg, "gc_token", ""):
        return {"error": err or "GoCardless credentials not found"}

    try:
        from sidekick_gc.api import check_customer_mandate_by_name, list_mandate_subscriptions
    except ImportError:
        return {"error": "sidekick_gc.api not importable"}

    # Try each search strategy in order: email → shoot_no → client_name
    search_strategies = []
    if email:
        search_strategies.append(("email", email))
    if shoot_no:
        search_strategies.append(("shoot_no", shoot_no))
    if client_name:
        search_strategies.append(("name", client_name))

    mandate_result = None
    used_strategy = None
    
    for strategy_type, search_term in search_strategies:
        if not search_term:
            continue
        mandate_result = check_customer_mandate_by_name(search_term, cfg)
        if mandate_result.has_mandate:
            used_strategy = strategy_type
            break
    
    if mandate_result is None or mandate_result.error:
        return {"error": mandate_result.error if mandate_result else "No search strategies available"}

    if not mandate_result.has_mandate:
        return {
            "has_mandate": False,
            "customer_name": mandate_result.customer_name or "",
            "search_tried": [s[0] for s in search_strategies],
        }

    plans = []
    if mandate_result.mandate_id:
        plan_list = list_mandate_subscriptions(mandate_result.mandate_id, cfg)
        for p in plan_list:
            plans.append({
                "id": p.id,
                "name": p.name,
                "type": p.plan_type,
                "status": p.status,
                "amount": p.amount,
            })

    return {
        "has_mandate": True,
        "mandate_id": mandate_result.mandate_id,
        "mandate_status": mandate_result.mandate_status,
        "customer_name": mandate_result.customer_name,
        "customer_email": mandate_result.customer_email,
        "found_by": used_strategy,
        "plans": plans,
    }


# ---------------------------------------------------------------------------
# Pretty print
# ---------------------------------------------------------------------------

SUPPLIER_STATUS_LABEL = {
    "in_production": "In Production",
    "dispatched":    "Dispatched",
    "received":      "Received",
    "":              "Not found",
}

def _print_report(job_ref: str, suppliers: dict, gc: dict, psa_path: str = "", album_name: str = "") -> None:
    print(f"\n{'='*55}")
    print(f"  Shoot status: {job_ref}")
    if psa_path:
        print(f"  PSA file    : {os.path.basename(psa_path)}")
    if album_name:
        print(f"  Album name  : {album_name}")
    print(f"{'='*55}")

    # ── Loxleys ──────────────────────────────────────────────
    lox = suppliers.get("loxleys")
    print("\n  LOXLEYS")
    if lox is None:
        print("    No record found")
    elif "error" in lox:
        print(f"    Error: {lox['error']}")
    else:
        status = SUPPLIER_STATUS_LABEL.get(lox["status"], lox["status"])
        print(f"    Status      : {status}")
        if lox["product"]:
            print(f"    Product     : {lox['product']}")
        if lox["ordered_at"]:
            print(f"    Ordered at  : {lox['ordered_at']}")
        if lox["dispatched_at"]:
            print(f"    Dispatched  : {lox['dispatched_at']}")
        if lox["tracking_ref"]:
            print(f"    Tracking    : {lox['tracking_ref']}")

    # ── nphoto ───────────────────────────────────────────────
    nph = suppliers.get("nphoto")
    print("\n  NPHOTO")
    if nph is None:
        print("    No record found")
    elif "error" in nph:
        print(f"    Error: {nph['error']}")
    else:
        status = SUPPLIER_STATUS_LABEL.get(nph["status"], nph["status"])
        print(f"    Status      : {status}")
        if nph["product"]:
            print(f"    Product     : {nph['product']}")
        if nph["dispatched_at"]:
            print(f"    Dispatched  : {nph['dispatched_at']}")
        if nph["tracking_ref"]:
            print(f"    Tracking    : {nph['tracking_ref']}")

    # ── GoCardless ───────────────────────────────────────────
    print("\n  GOCARDLESS")
    if "error" in gc:
        print(f"    Error: {gc['error']}")
    elif not gc.get("has_mandate"):
        name = gc.get("customer_name", "")
        searched = gc.get("search_tried", [])
        search_info = f" (searched: {', '.join(searched)})" if searched else ""
        print(f"    No active mandate{' — ' + name if name else ''}{search_info}")
    else:
        print(f"    Mandate     : {gc['mandate_id']} ({gc['mandate_status']})")
        found_by = gc.get("found_by", "unknown")
        print(f"    Found by    : {found_by}")
        if gc.get("customer_name"):
            print(f"    Customer    : {gc['customer_name']} <{gc.get('customer_email','')}>")
        plans = gc.get("plans", [])
        if not plans:
            print("    Plans       : None")
        else:
            for p in plans:
                amt = f"£{p['amount']/100:.2f}" if isinstance(p["amount"], int) else str(p["amount"])
                print(f"    Plan        : [{p['type']}] {p['name']} — {p['status']} ({amt})")

    print(f"\n{'='*55}\n")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def _find_psconsole_path() -> str:
    """Return path to psconsole.exe directory, or '' if not found."""
    candidates = [
        r"C:\Program Files\Pro Studio Software\ProSelect 2025\ProSelect Helpers\plrp.install\win",
        r"C:\Program Files\Pro Studio Software\ProSelect 2024\ProSelect Helpers\plrp.install\win",
        r"C:\Program Files\TimeExposure\ProSelect\ProSelect Helpers\plrp.install\win",
    ]
    for d in candidates:
        if os.path.isfile(os.path.join(d, "psconsole.exe")):
            return d
    return ""


def _psconsole_loadordergroup(contact: dict) -> bool:
    """Call psconsole loadordergroup to update the open ProSelect album with GHL contact data.
    
    Parameters map to ProSelect order group:
    Group, FirstName, LastName, Account, HomePhone, WorkPhone, CellPhone,
    Address1, Address2, City, State, Country, Email, Zip
    """
    import subprocess
    ps_dir = _find_psconsole_path()
    if not ps_dir:
        print("  [WARN] psconsole.exe not found — skipping ProSelect update", flush=True)
        return False

    addr2 = contact.get("address2", "")
    addr3 = contact.get("address3", "")
    combined_addr2 = ", ".join(filter(None, [addr2, addr3]))

    params = [
        "",                                        # Group
        contact.get("firstName", ""),
        contact.get("lastName", ""),
        contact.get("id", ""),                      # Account = GHL contact ID
        contact.get("phone", ""),                   # HomePhone
        "",                                        # WorkPhone
        "",                                        # CellPhone
        contact.get("address1", ""),
        combined_addr2,
        contact.get("city", ""),
        contact.get("state", ""),
        contact.get("country", ""),
        contact.get("email", ""),
        contact.get("postalCode", ""),
    ]

    cmd = [os.path.join(ps_dir, "psconsole.exe"), "loadordergroup"] + params
    try:
        result = subprocess.run(cmd, cwd=ps_dir, capture_output=True, text=True, timeout=30)
        success = result.returncode == 0 or 'status="0"' in result.stdout
        if success:
            print("  [OK] ProSelect client data updated via psconsole", flush=True)
        else:
            print(f"  [WARN] psconsole returned non-zero: {result.stdout.strip()[:200]}", flush=True)
        return success
    except Exception as e:
        print(f"  [WARN] psconsole call failed: {e}", flush=True)
        return False


def _extract_psa_client_data(job_ref: str) -> dict:
    """Find PSA file and extract client data.
    
    From filename: shoot_no, last_name, ghl_contact_id (if present).
    From PSA SQLite OrderList: email, client_code.
    Always returns psa_path, last_name, ghl_contact_id (may be "").
    """
    import re
    archive_paths = [
        os.path.expanduser("~/Pictures/Shoots/Archive"),
        os.path.expanduser("~/Pictures/Shoots/Processed"),
        os.path.expanduser("~/Pictures/Shoots"),
        r"C:\Users\guy\Pictures\Shoots\Archive",
    ]
    
    for archive_path in archive_paths:
        if not os.path.isdir(archive_path):
            continue
        for root, dirs, files in os.walk(archive_path):
            for fname in files:
                if not fname.endswith(".psa") or job_ref not in fname:
                    continue
                psa_path = os.path.join(root, fname)
                stem = fname[:-4]  # strip .psa
                parts = stem.split("_")
                # Parts: [shoot_no, last_name, ghl_contact_id?, ...]
                last_name = parts[1] if len(parts) > 1 else ""
                # GHL contact IDs are 20+ alphanumeric chars
                ghl_id_from_filename = next(
                    (p for p in parts[2:] if re.match(r'^[A-Za-z0-9]{20,}$', p) and p != "test"),
                    ""
                )
                
                # Read email + client_code from PSA SQLite
                email, client_code = "", ""
                try:
                    conn = sqlite3.connect(psa_path)
                    cur = conn.cursor()
                    cur.execute("SELECT buffer FROM BigStrings WHERE buffCode='OrderList' LIMIT 1")
                    row = cur.fetchone()
                    conn.close()
                    if row:
                        xml_str = str(row[0])
                        m = re.search(r'<email>([^<]+)</email>', xml_str, re.IGNORECASE)
                        email = m.group(1) if m else ""
                        m = re.search(r'<clientCode>([^<]+)</clientCode>', xml_str, re.IGNORECASE)
                        client_code = m.group(1) if m else ""
                except Exception:
                    pass
                
                return {
                    "psa_path": psa_path,
                    "last_name": last_name,
                    "ghl_contact_id": ghl_id_from_filename,
                    "email": email,
                    "client_code": client_code,
                }
    
    return {"psa_path": "", "last_name": "", "ghl_contact_id": "", "email": "", "client_code": ""}


def _get_ghl_contact(ghl_id: str = "", email: str = "", client_code: str = "", last_name: str = "") -> dict:
    """Resolve GHL contact and return full raw contact dict.
    
    Strategy order:
    1. Direct fetch by GHL contact ID (from filename)
    2. find_ghl_contact by email
    3. find_ghl_contact by ProSelect client_code (session_job_no)
    4. find_ghl_contact_by_name (last_name only — precise enough)
    Returns {} if not found.
    """
    try:
        from sync_ps_invoice import find_ghl_contact, fetch_ghl_contact, find_ghl_contact_by_name
        
        contact_id = None
        
        if ghl_id:
            contact_id = ghl_id
        elif email:
            contact_id = find_ghl_contact(email=email, client_id=None)
        elif client_code:
            contact_id = find_ghl_contact(email="", client_id=client_code)
        
        if not contact_id and last_name:
            # Name search — pass empty first name so it falls back to last-name-only query
            contact_id = find_ghl_contact_by_name("", last_name)
        
        if not contact_id:
            return {}
        
        contact = fetch_ghl_contact(contact_id)
        if contact:
            contact["id"] = contact_id  # ensure id is set
            return contact
    except Exception as e:
        print(f"  [WARN] GHL lookup failed: {e}", flush=True)
    
    return {}


def _reconstruct_album_name(shoot_no: str, client_name: str, ghl_contact_id: str = "", is_test: bool = False) -> str:
    """Reconstruct album filename according to naming convention.
    
    Format: ShootNo_LastName[_GHL_ContactID][_test].psa
    Examples:
    - P25097P_Field.psa
    - P25097P_Field_8IWxk5M0PvbNf1w3npQU.psa
    - P25097P_Field_test.psa
    """
    parts = [shoot_no, client_name]
    if ghl_contact_id:
        parts.append(ghl_contact_id)
    if is_test:
        parts.append("test")
    return "_".join(parts) + ".psa"


def _rename_album_file(old_path: str, new_name: str) -> bool:
    """Rename a .psa album file in place. Returns True if successful."""
    try:
        old_path = os.path.abspath(old_path)
        if not os.path.isfile(old_path):
            return False
        
        new_path = os.path.join(os.path.dirname(old_path), new_name)
        
        # Only rename if different
        if os.path.normcase(old_path) == os.path.normcase(new_path):
            return True
        
        # Check if target already exists
        if os.path.exists(new_path):
            return False
        
        os.rename(old_path, new_path)
        return True
    except Exception:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Check Loxleys, nphoto, and GoCardless status for a shoot")
    parser.add_argument("job_ref", help="Shoot job ref, e.g. P25097P_Field")
    parser.add_argument("--ssh-host", default=DEFAULT_SSH_HOST, help="Toypi SSH host")
    parser.add_argument("--remote-db", default=DEFAULT_REMOTE_DB, help="Remote supplier DB path")
    parser.add_argument("--json", dest="as_json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    shoot_no = args.job_ref.split("_")[0]

    # ── Step 1: Extract all available data from PSA file ─────────────────────
    print("Checking PSA file...", flush=True)
    psa_data = _extract_psa_client_data(args.job_ref)
    psa_path         = psa_data["psa_path"]
    last_name        = psa_data["last_name"] or args.job_ref.split("_", 1)[1].split("_")[0] if "_" in args.job_ref else args.job_ref
    ghl_id_from_file = psa_data["ghl_contact_id"]
    email            = psa_data["email"]
    client_code      = psa_data["client_code"]

    if psa_path:
        print(f"  PSA found: {os.path.basename(psa_path)}", flush=True)
        print(f"  Name: {last_name}  |  GHL ID in file: {ghl_id_from_file or '(none)'}  |  Email: {email or '(none)'}", flush=True)
    else:
        print(f"  No PSA file found for {args.job_ref}", flush=True)

    # ── Step 2: Resolve GHL contact ───────────────────────────────────────────
    print("\nResolving GHL contact...", flush=True)
    contact = _get_ghl_contact(
        ghl_id=ghl_id_from_file,
        email=email,
        client_code=client_code,
        last_name=last_name,
    )

    album_name = os.path.basename(psa_path) if psa_path else ""

    if contact:
        ghl_contact_id = contact.get("id", "")
        email          = contact.get("email", email)
        first_name     = contact.get("firstName", "")
        full_name      = f"{first_name} {last_name}".strip()
        print(f"  Found: {full_name} <{email}>  (ID: {ghl_contact_id})", flush=True)

        # Update ProSelect client data via psconsole (+ album rename)
        if psa_path:
            print("\nUpdating ProSelect client data...", flush=True)
            updated = _psconsole_loadordergroup(contact)

            # Reconstruct correct album name and rename file if needed
            correct_name = _reconstruct_album_name(shoot_no, last_name, ghl_contact_id)
            current_name = os.path.basename(psa_path)
            if current_name.lower() != correct_name.lower():
                if _rename_album_file(psa_path, correct_name):
                    print(f"  Album renamed: {current_name} → {correct_name}", flush=True)
                    psa_path   = os.path.join(os.path.dirname(psa_path), correct_name)
                    album_name = correct_name
                else:
                    print(f"  [WARN] Could not rename album to {correct_name}", flush=True)
    else:
        ghl_contact_id = ghl_id_from_file
        full_name      = last_name
        print("  No GHL contact found.", flush=True)

    # ── Step 3: Supplier orders ───────────────────────────────────────────────
    print("\nChecking supplier orders...", flush=True)
    suppliers = _check_suppliers(args.job_ref, args.ssh_host, args.remote_db, shoot_no=shoot_no, last_name=last_name)
    if "error" in suppliers:
        suppliers = {"_error": suppliers["error"]}

    # ── Step 4: GoCardless ────────────────────────────────────────────────────
    print("Checking GoCardless...", flush=True)
    gc = _check_gocardless(email=email, shoot_no=shoot_no, client_name=full_name)

    if args.as_json:
        print(json.dumps({"job_ref": args.job_ref, "suppliers": suppliers, "gocardless": gc}, indent=2))
        return 0

    _print_report(args.job_ref, suppliers, gc, psa_path=psa_path, album_name=album_name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
