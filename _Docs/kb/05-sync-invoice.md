---
title: "How to sync a ProSelect invoice to GoHighLevel"
category: sync
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## What this does

Exports the current client's ProSelect order to GoHighLevel as an invoice, creating or updating the matching invoice and opportunity record automatically.

## Before you start

- A client must be loaded in SideKick PS (see How to look up a client from GoHighLevel).
- The order must be finalised in ProSelect with the correct items and amounts.

## Steps

1. In ProSelect, confirm the client's order is complete and the correct album is open.
2. Click the **Sync Invoice** button (document icon, green) on the SideKick toolbar.
3. SideKick PS exports the order data and uploads it to GoHighLevel.
4. A progress indicator appears while the sync runs.
5. When complete, a summary confirms the invoice total and shows a link to the GHL record.
6. Click the link to open the invoice in GoHighLevel, or click **Close** to return to ProSelect.

## What you should see

A new invoice appears in the client's GHL contact record matching the ProSelect order. An opportunity is also created or updated in the pipeline.

## Something went wrong?

- **Duplicate invoice warning** — SideKick PS has detected a previous sync for the same order. Review the existing GHL invoice before proceeding to avoid creating a duplicate charge.
- **Sync failed — check connection** — Verify your GHL API credentials in **Settings → GHL** and retry.
- **Line items are missing** — Make sure the ProSelect order has been saved and all items confirmed before syncing.

## Related

- How to look up a client from GoHighLevel
- How to open a client's GoHighLevel contact record
- How to open the GHL Production opportunity
