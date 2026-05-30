---
title: "How to download images from an SD card"
category: setup
source_files: SideKick_PS.ahk, Inc_SDCard.ahk
last_sync: 2026-05-30
---

## What this does

Copies image files from a camera SD card to your studio's shoot archive folder, assigns a shoot number, and optionally opens the folder in your file browser when finished.

## Before you start

- Configure the following paths in **Settings → File Management** before your first download:
  - **SD Card Path** — the drive letter and DCIM folder for your camera's SD card (e.g. `F:\DCIM`)
  - **Download Path** — a temporary working folder for copied files
  - **Archive Path** — the final destination for finished shoots
- Insert the SD card into your computer's card reader.

## Steps

1. Click the **Download** button (arrow-down icon, orange) on the SideKick toolbar.
2. A dialog appears confirming the SD card path detected. Click **Continue**.
3. Enter or confirm the shoot number for this session. SideKick PS suggests the next available number automatically.
4. SideKick PS copies all image folders from the card to your archive.
5. When the copy is complete, your configured file browser opens automatically (if enabled in Settings).

## What you should see

All images from the SD card appear in a new numbered folder in your shoot archive. The file browser opens to that folder.

## Something went wrong?

- **"SD card not found"** — Check the card is inserted and that the drive letter in **Settings → File Management → SD Card Path** matches the card's current drive letter in Windows Explorer.
- **Download stops part-way through** — Check there is sufficient free space on your archive drive. SideKick PS will report the error if space runs out.
- **Shoot number already exists** — SideKick PS will warn you before overwriting. Change the shoot number in the confirmation dialog.

## Related

- How to open the shoot folder
