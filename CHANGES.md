# SideKick_PS — Change Log

## sync_ps_invoice.py — Session Changes (April 2026)

---

### 1. Opportunity Monetary Value

- `move_contact_opportunity_to_production` now writes `monetaryValue` from ProSelect order total as **whole pounds** (`int(round(order_total))`).
- Previously, a stage-lookup failure caused an early return before the value was written. This is fixed — stage lookup failure now sets a warning but field updates continue.

---

### 2. Contact ID Lookup Priority

Order is now: **Album name ID → Client ID → API (job ref then email)**

- New helper `_extract_ghl_contact_id_from_album_name`: splits album name on `_`, `-`, space and picks the rightmost 15+ alphanumeric token as the GHL contact ID.
- GHL contacts search (`_search_ghl_contacts`) gained required `page`/`pageLimit` fields (fixes 422 errors).

---

### 3. Pipeline Stage Resolution

- `PRODUCTION_ORDER_CONFIRMED_STAGE` changed from `'Order Confirmed'` to `'New Order'` to match the live pipeline.
- `_PRODUCTION_STAGE_ALIASES` dict added — if the wanted stage name is not found, aliases are tried:

  ```python
  _PRODUCTION_STAGE_ALIASES = {
      'awaiting approval': ['proofing'],
      'order confirmed':   ['new order'],
      'complete':          ['compleate'],
      'completed':         ['compleate'],
  }
  ```

- `_ARCHIVE_STAGE_MAP` entry `PRINTING` corrected from `'Awaiting Approval'` → `'Proofing'`.

---

### 4. Payment Status Label

`_summarize_payment_status` is now plan-count–aware rather than math-based:

| Condition | Label |
| --- | --- |
| > 1 payments | `Pay Plan Active` |
| 1 payment == order total | `Paid in Full` |
| 1 payment < order total | `Paid` |
| 0 payments | `Payment Due` |

---

### 5. Order Release Date (new)

New helper `_calculate_release_goods_date(order_data, threshold_pct=0.25)`:

- Sorts actual received payments by date (ascending).
- Walks the cumulative total until it first reaches **25% of order total**.
- Returns that payment's date as `YYYY-MM-DD`.

The result is written to the GHL opportunity field **Order Release Date** (`PwIU5Qp2uGKBEHAuKO3s`), and included in the Notes field summary:

```
Order Total: £3750.00 | Paid: £3750.00 | Remaining: £0.00 | Payments: 25 | Paid %: 100.00 | Order Release Date: 2025-07-15
```

> GHL field was renamed from "Expected Return Date" → **"Order Release Date"** via API.
> Code key renamed from `expected_return_date` → `order_release_date`.

---

### 6. Ordered Products Field

- Credit and deposit line items are excluded via `_is_non_product_financial_line(name)`.
- Shipping is left in (user preference — can be removed manually in GHL if needed).

---

### 7. Supplier Sync Failsafes

Two new failsafe checks prevent unnecessary/failed supplier syncs:

1. **SSH Host Reachability** — New helper `_can_reach_ssh_host(ssh_host, timeout=5)` pings the SSH host before attempting sync. If unreachable, supplier sync is skipped gracefully.

2. **Empty RT Folder** — If the `Processed/RT` folder is empty (no retouching work), supplier sync is skipped. There will be no lab work data to retrieve from SSH.

---

### 8. Other Fixes

| Fix | Detail |
| --- | --- |
| Single-candidate chooser popup | Auto-selects when only one unresolved opportunity candidate exists |
| Tag updates clobbering value/stage | `add_tags_to_opportunity` now preserves `monetaryValue`, `pipelineId`, `pipelineStageId` in the PUT payload |

---

### 9. Production Opportunity Toolbar Button (new)

Added a new toolbar button in SideKick ProSelect to open the synced production opportunity directly in GHL.

- Position: In the GHL section, immediately to the right of Invoice Sync.
- Visibility: Only shown when invoice sync has completed and a production opportunity URL is available.
- Click action: Opens the production opportunity details page in browser.

Implementation details:

- `sync_ps_invoice.py`
  - `move_contact_opportunity_to_production` now returns `opportunity_id` for the first successfully moved opportunity.

- `SideKick_PS.ahk`
  - New global state: `GHL_ProductionOpportunityURL`.
  - New setting toggle state: `Settings_ShowBtn_ProductionOpp`.
  - Toolbar render logic updated to include the new button only when URL is present.
  - New handler: `Toolbar_OpenProductionOpp`.
  - On sync success, reads `opportunity_id` from `ghl_invoice_sync_result.json`, builds the GHL opportunity URL, stores it, and rebuilds toolbar so the button appears immediately.
  - Persists URL in result JSON as `production_opportunity_url` and restores it on startup.

---

### GHL Reference

| Field | ID | Type |
| --- | --- | --- |
| Job Number | `NB9y9rQqcSeV1mLF4q2v` | TEXT |
| Invoice Reference | `201pXcaWtrcw2rDnhGnp` | TEXT |
| Payment Status | `SJff8258CBB2oxWpCJIq` | SINGLE_OPTIONS |
| Ordered Products | `Ku0bYIvAOrLicNTCZZEG` | MULTIPLE_OPTIONS |
| Notes | `un03xwZ6Eb3zleDKHuGN` | LARGE_TEXT |
| Hold Reason | `vS01WIDN72JMv2XkDrfG` | DROPDOWN |
| Production Start Date | `qJC8YkyvFBKWi0vhrJDq` | DATE |
| Order Release Date | `PwIU5Qp2uGKBEHAuKO3s` | DATE |

Live pipeline: **Boudoir Production Pipeline** (`M4KlAuzaA93TnNbgymlv`)

| Stage | ID |
| --- | --- |
| New Order | `8f204d0b-0407-4c85-82fa-5022e5db9e83` |
| Retouching | `d53ba8fc-83c7-4ad1-b5ed-7acb587ad711` |
| Design | `12d81b9c-8cf7-4785-b46c-fe3ee3fc5079` |
| Proofing | `74cb6ea7-f20f-4641-b035-1aca4a14553a` |
| Ordered From Lab | `84e3b9b8-7e38-4be1-9fa0-636864711277` |

---

### 10. Factory Opportunity Button + PSA Startup Restore (new)

Updated the new GHL production button to the factory workflow.
Reload behavior is now stateful from PSA metadata.

- Button text/intent updated from production wording to factory wording in
  the toolbar tooltip.
- Opportunity deep-link URL format updated to the live route:

  ```text
  https://<domain>/v2/location/<locationId>/opportunities/<opportunityId>?tab=Opportunity+Details
  ```

- Added PSA metadata bootstrap on app reload:
  - If result JSON does not already provide an opportunity URL,
    startup now tries to read the currently open album `.psa`.
  - It reads `ghl_last_opportunity_id` and `ghl_location_id` from `sk_ps_meta`.
  - If both values exist, it rebuilds the opportunity URL and
    refreshes the toolbar so the Factory button appears
    without re-syncing.

- Added CLI utility support in `sync_ps_invoice.py`:
  - New flag: `--read-psa-meta <PSA_PATH>`
  - Prints `sk_ps_meta` as JSON and exits.
  - Used by startup logic to load open-album sync state.

---

### 11. Factory Button State Refresh Refinement (new)

Refined the Factory button behavior after live testing.

- Removed the periodic album watcher timer.
  - Factory state refresh no longer polls every few seconds.
  - PSA sync state is now refreshed only when the toolbar rebuilds.

- Added album/path safety on click.
  - Clicking the GHL Production button now forces a PSA refresh first.
  - The current open album path is compared with the PSA path that the
    stored opportunity URL belongs to.
  - If the open album changed, the button will not open the old
    opportunity by mistake.

- Added open-album JSON refresh.
  - When PSA metadata is loaded for the current album, SideKick now writes
    `%APPDATA%\SideKick_PS\ghl_open_album_state.json`.
  - This stores the current album PSA path plus the resolved production
    opportunity state for the open album.

- Final button UI update.
  - Tooltip changed to `GHL Production`.
  - The button icon was changed away from the globe and document fallback
    to an explicit factory glyph.
