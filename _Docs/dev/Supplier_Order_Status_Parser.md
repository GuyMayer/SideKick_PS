# Supplier Order Status Parser

Parses order status emails from **nPhoto** (books) and **Loxleys** (wall art) suppliers. Runs 3x daily and writes results to a SQLite database on ToyPi.

## Overview

This tool:
- Scans emails from `@nphoto.com` and `@loxleycolour.com`
- Extracts job references (e.g., `P26010P_Johnson`)
- Detects order status: `in_production` or `dispatched`
- Extracts tracking numbers (UPS, DPD, FedEx, etc.)
- Upserts to SQLite on ToyPi with status hierarchy (never downgrades)
- **Does NOT interfere** with the existing invoice/receipt forwarding pipeline

## Files

| File | Purpose |
|------|---------|
| `parser.js` | Email parsing: status keywords, job refs, tracking numbers |
| `db.js` | SQLite database operations and query helpers |
| `remote-upsert.js` | Remote JSON upsert entrypoint for SideKick over SSH |
| `manual-verify-update.js` | Manual verified order updater (when email is missing/deleted) |
| `scanner.js` | Main orchestrator; runs on schedule via cron |

## Database

**Location:** `/home/guy/.openclaw/data/supplier_status.db` on ToyPi  
**Access:** Local direct SQLite (better-sqlite3). Remote systems update/query via SSH commands.

### Schema

```sql
CREATE TABLE supplier_orders (
  job_ref TEXT NOT NULL,              -- e.g., P26010P_Johnson
  supplier TEXT NOT NULL,             -- 'nphoto' or 'loxleys'
  product TEXT,                       -- 'book' or 'wall_art'
  status TEXT,                        -- 'in_production', 'dispatched', 'received'
  ordered_at DATE,                    -- from confirmation email
  dispatched_at DATE,                 -- from dispatch email
  tracking_ref TEXT,                  -- courier tracking number
  email_subject TEXT,                 -- raw subject for audit
  email_received_at DATETIME,         -- when email arrived
  parse_result TEXT,                  -- 'ok', 'manual_review', 'parse_error', 'excluded_invoice'
  raw_snippet TEXT,                   -- first 500 chars of body for debug
  created_at DATETIME,                -- record creation
  updated_at DATETIME,                -- last modification
  PRIMARY KEY (job_ref, supplier)
);
```

## Usage

### Manual Scan

```bash
# Scan since last checkpoint
node scanner.js

# Force full 7-day scan
node scanner.js --full

# Dry run (parse only, no DB write)
node scanner.js --dry-run
```

### Scheduled Scans

Three cron jobs run daily:
- **09:00** - Morning scan
- **13:00** - Midday scan
- **18:00** - Evening scan

Jobs are registered in `~/.openclaw/cron/jobs.json` with IDs: `supplier-status-scan-morning`, `supplier-status-scan-midday`, `supplier-status-scan-evening`.

### Query Database

```bash
# Query directly on ToyPi
node -e "const db=require('./db'); db.getPendingOrders().then(r=>console.log(r.length))"

# Or query remotely over SSH
ssh toypi.tail009b36.ts.net "node -e \"const db=require('/home/guy/.openclaw/scripts/tools/supplier-status/db'); db.getSupplierStatus('NPU_29692036').then(r=>console.log(JSON.stringify(r)))\""
```

### Remote Upsert (SideKick)

Use `remote-upsert.js` when SideKick has structured JSON payloads and needs to update records remotely:

```bash
# stdin payload
cat payload.json | ssh toypi.tail009b36.ts.net "node /home/guy/.openclaw/scripts/tools/supplier-status/remote-upsert.js"

# file payload on ToyPi
ssh toypi.tail009b36.ts.net "node /home/guy/.openclaw/scripts/tools/supplier-status/remote-upsert.js --file /tmp/payload.json"
```

Payload format:

```json
{
  "records": [
    {
      "job_ref": "NPU_29692036",
      "supplier": "nphoto",
      "status": "dispatched",
      "tracking_ref": "TRACK123",
      "parse_result": "remote_update"
    }
  ]
}
```

### Manual Verification Update

Use this when an order is verified manually (for example, source email was deleted or unavailable):

```bash
ssh toypi.tail009b36.ts.net "node /home/guy/.openclaw/scripts/tools/supplier-status/manual-verify-update.js \
  --job-ref NPU_29692036 \
  --supplier nphoto \
  --status received \
  --tracking TRACK123 \
  --note 'Verified manually because source email was missing'"
```

Manual updates are tagged as `parse_result='manual_verified'` for auditability.

## Isolation from Invoice Pipeline

The existing `forward-ai-invoices-to-hubdoc.js` script handles invoice/receipt forwarding.

**How we stay separate:**
- Email search explicitly excludes `invoice`, `receipt`, `payment` keywords
- Parser checks combined subject+body for exclude patterns and sets `parse_result='excluded_invoice'`
- If an email matches both pipelines, they operate independently on separate paths

## Error Handling

- **No job ref found** -> `parse_result = 'manual_review'` (needs human review)
- **Parse exception** -> `parse_result = 'parse_error'`, `raw_snippet` populated with error
- **DB write failure** -> logged, counted in `errors`, does not crash scheduler
- **DB write failure** -> logged, counted in `errors`, cron exits non-zero and Telegram failure alert triggers

## Status Hierarchy

Never downgrades status (only allows promotion):
1. `in_production` (lowest)
2. `dispatched`
3. `received` (highest)

If a dispatch email arrives after a received email, the received status is preserved.

## Logging

Logs written to `~/.openclaw/logs/supplier-status.log` (plaintext, JSON-compatible timestamps).

Example:
```
[2026-04-21T09:15:32.104Z] [scan] Found 12 potential status emails for nphoto
[2026-04-21T09:15:35.204Z] [db] Upsert result: 8 upserted, 2 skipped, 0 errors
[2026-04-21T09:15:35.207Z] === Supplier Status Scan Complete ===
```

## Checkpoint

Stored in `~/.openclaw/data/supplier-status-checkpoint.json`:
```json
{
  "last_scan_at": "2026-04-21T09:15:35.207Z",
  "last_scan_count": 12,
  "last_scan_result": {
    "upserted": 8,
    "skipped": 2,
    "errors": 0
  }
}
```

## Troubleshooting

### "Remote update failed"
- Verify Tailscale is connected: `sudo tailscale status`
- Test SSH: `ssh toypi.tail009b36.ts.net echo ok`
- Validate payload shape for `remote-upsert.js` (must include `job_ref` and `supplier`)

### "Parse errors" spike
- Check email subjects match expected patterns in `SUPPLIERS` config
- Review `raw_snippet` in DB for edge cases
- Run `--dry-run` to see what would be parsed

### "No records found" after scan
- Check `last_scan_at` timestamp — may indicate old checkpoint
- Run `node scanner.js --full` to reset and scan 7 days back
- Verify email filters: `--subject:invoice --subject:receipt` working?

## Future Integration

SideKick_PS Python script can:
1. Read order status via query helper commands on ToyPi
2. Update records remotely with `remote-upsert.js` when it has structured status data
3. Force manual verified updates with `manual-verify-update.js` when email evidence is missing
4. Push finalized status updates to GoHighLevel CRM API

---

**Owner:** Guy  
**Last Updated:** 2026-04-21  
**Status:** Active (3x daily scans)
