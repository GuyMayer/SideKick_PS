# SideKick PS — Xero Integration Changelog

<!--
AI INSTRUCTIONS - When publishing Xero-related changes:
1. Update this CHANGELOG_Xero.md with the new version entry
2. Also update the main CHANGELOG.md with relevant Xero entries
3. Check ProSelect_GHL_Field_Mapping.md (docs/) is up to date with any new field mappings
4. Update docs.html Xero section if field mappings or tax codes change

This file tracks only changes relevant to the ProSelect → GHL → Xero sync pipeline:
- SKU / ItemCode field mapping
- Tax code handling (OUTPUT2, OUTPUT, NONE)
- Invoice line item structure
- GHL product lookup by SKU
- Invoice update / resync behaviour that affects Xero-synced data

NOTE: Xero integration is passive — SideKick creates GHL invoices with the correct
fields (sku, taxable, quantity, price) and GHL's native Xero sync pushes them through.
No direct Xero API calls are made by SideKick.

Field mapping reference:
  ProSelect Product_Code → GHL SKU → Xero ItemCode
  GHL tax_label "VAT (20%)" → Xero TaxType OUTPUT2
  GHL tax_label "VAT (5%)"  → Xero TaxType OUTPUT
  (empty / no tax)          → Xero TaxType NONE
-->

---

## v3.0.8 (2026-03-17)

### Current State
Full end-to-end pipeline established: ProSelect → XML export → SideKick → GHL Invoice → Xero.

- **SKU (ItemCode) matching**: `Product_Code` from ProSelect XML is sent as GHL `sku` — Xero matches by `ItemCode` for automatic product pairing
- **Tax codes**: `tax_label` and `tax_rate` extracted per line item; GHL sends `taxable: true/false` and the tax name, which Xero maps to `OUTPUT2` (20%), `OUTPUT` (5%), or `NONE`
- **Zero-price item guard**: Items with unit price £0 are sent without tax arrays — Xero rejects tax on zero-value lines
- **Invoice update & resync**: `--update-invoice` and `--resync` preserve Xero-synced payment history; only line items and future schedules are replaced
- **Documentation**: Full field mapping guide at `docs/ProSelect_GHL_Field_Mapping.md` and `docs.html` (Xero section)

---

## v2.5.46 (2026-03-04)

### Improvements
- **Invoice Update preserves Xero history**: `--update-invoice` diffs past payments against GHL `amountPaid` and only records the difference — no duplicate payment records pushed to Xero
- **Invoice Resync**: `--resync` deletes and recreates the GHL invoice cleanly — Xero re-syncs the new invoice on next GHL → Xero run
- **Shoot-scoped deletion**: `delete_shoot_invoices()` targets only invoices matching the shoot number, preventing accidental deletion of unrelated Xero-synced invoices

---

## v2.5.18 (2026-02-17)

### Improvements
- **Tax on invoice items**: `taxes` array now added to each GHL line item when `tax_rate > 0` — Xero receives correct OUTPUT / OUTPUT2 tax type per line
- **Clean invoice display**: ProSelect description cleared when GHL product found by SKU — Xero Description field shows the GHL product name, not raw ProSelect text

---

## v2.5.15 (2026-02-17)

### Bug Fixes
- **GHL Product SKU Lookup**: Fixed SKU fetch — GHL stores SKUs on **price** objects, not product variants. Price-level SKUs are now fetched correctly, so `Product_Code` → GHL product → Xero `ItemCode` matching works reliably

---

## v2.5.14 (2026-02-17)

### Bug Fixes
- **Zero-quantity items**: Bundled items with `qty=0` (e.g. Mat/Frame included free with main product) are now skipped — GHL requires `qty ≥ 0.1` and Xero would reject a £0 quantity line with tax

---

## v2.5.13 (2026-02-17)

### New Features
- **GHL Product Lookup by SKU**: When a `Product_Code` is present in the ProSelect XML, SideKick looks it up in GHL by SKU and uses the GHL product name on the invoice — the same SKU is sent through to Xero as `ItemCode` for product matching

---

## v2.5.12 (2026-02-17)

### Bug Fixes
- **GHL Invoice Tax**: Switched to `taxInclusive` boolean flag per GHL API docs — fixes mixed VAT rate handling where items had different rates in the same invoice (required for correct Xero OUTPUT / OUTPUT2 split)

---

## v2.5.11 (2026-02-17)

### Bug Fixes
- **CRITICAL — GHL Invoice Tax HTTP 422**: Fixed `taxInclusive` on £0-price items — GHL API rejects taxes on zero-price items, which previously caused the entire invoice sync to fail before reaching Xero

---

## v2.5.9 (2026-02-17)

### New Features
- **Per-line tax**: Each invoice item now carries `tax_label`, `tax_rate`, and `price_includes_tax` — required for Xero to apply the correct `TaxType` per line (OUTPUT2 for 20% VAT, OUTPUT for 5%)

---

## v2.5.8 (2026-02-17)

### Documentation
- **Docs button**: Settings About tab links to field mapping documentation including the full GHL → Xero section
- **Xero Setup Guide**: `docs/ProSelect_GHL_Field_Mapping.md` published with step-by-step Xero connection instructions and tax code mapping table

---

## v2.5.7 (2026-02-17)

### New Features — Xero Pipeline Foundation
- **SKU field extraction**: `Product_Code` extracted from ProSelect XML and sent as `sku` on GHL invoice line items — primary key for Xero `ItemCode` matching
- **Full tax details**: `tax_label`, `tax_rate`, and `price_includes_tax` extracted per item
- **Product line fields**: `ProductLineName` code and name extracted for Xero account code categorisation
- **Size / Template fields**: `Size` and `Template_Name` preserved for product identification
- **ProSelect item ID**: Internal PS item ID tracked for traceability across systems

### Improvements
- **No string merging**: All ProSelect fields passed through to GHL unchanged — Xero receives the raw values without SideKick modification
- **Xero/QuickBooks ready**: Invoice items now include all fields required for GHL's native accounting sync (sku, price, quantity, taxable, description)
