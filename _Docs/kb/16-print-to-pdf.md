---
title: "How to print a ProSelect page to PDF"
category: setup
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## What this does

Saves the current ProSelect page as a PDF file automatically, using a pre-calibrated button location — no print dialog interaction required.

## Before you start

- **Print to PDF** must be enabled in **Settings → Toolbar → Enable Print to PDF**.
- The PDF print button location must be calibrated once (see Step 1 below).
- Optionally, set a **PDF Output Folder** in **Settings → Toolbar** to send a copy of every PDF to a specific folder automatically.

## Steps

1. **First-time setup only:** Open **Settings → Toolbar**, enable **Print to PDF**, then click **Calibrate Print Button** and follow the on-screen prompt to click the print button inside ProSelect's print dialog. Calibration only needs to be done once per machine.
2. In ProSelect, navigate to the page or layout you want to save.
3. Click the **PDF** button (document icon, maroon) on the SideKick toolbar.
4. SideKick PS triggers ProSelect's print function and automatically clicks through to save the file.

## What you should see

A PDF is saved to your configured output folder. If no folder is set, the PDF saves to ProSelect's default output location.

## Something went wrong?

- **Print dialog appears but nothing is clicked automatically** — Calibration may be out of date if you have resized or moved the ProSelect window significantly. Recalibrate via **Settings → Toolbar → Calibrate Print Button**.
- **PDF saves to the wrong location** — Set the correct path in **Settings → Toolbar → PDF Output Folder**.

## Related

- How to email a PDF to a client via GoHighLevel
- How to quick print from the toolbar
