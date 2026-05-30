---
title: "How to connect SideKick PS to GoHighLevel"
category: setup
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## What this does

Links SideKick PS to your GoHighLevel account so it can look up clients, sync invoices, and push payment plans.

## Before you start

- You need a GoHighLevel account with a sub-account (Location) set up for your studio.
- You need a **Private Integration Token** (API key) from your GHL sub-account — found in **Settings → Integrations → Private Integrations** inside GHL.
- You need your GHL **Location ID** — found in GHL under **Settings → Business Profile**.

## Steps

1. On first run, SideKick PS displays a setup wizard automatically. Click **Set up GoHighLevel connection**.
2. Paste your **API Key** into the first field.
3. Paste your **Location ID** into the second field.
4. Click **Save & Test** — SideKick PS verifies the connection.
5. If the test succeeds, click **Done**.

_To update your credentials later: open **Settings** (gear icon or **Ctrl+Shift+I**), go to the **GHL** tab, and update the fields there._

## What you should see

The GHL tab in Settings shows a green confirmation. The toolbar's **Get Client**, **Sync Invoice**, and **Open GHL Contact** buttons become fully active.

## Something went wrong?

- **"Connection failed"** — Check that your API key is a V2 Private Integration Token, not an older API key. Generate a new one in GHL under **Settings → Integrations → Private Integrations**.
- **"Location ID not found"** — Make sure you are using the Location ID, not the Agency ID. These are different values found in different parts of GHL settings.

## Related

- How to look up a client from GoHighLevel
- How to sync a ProSelect invoice to GoHighLevel
