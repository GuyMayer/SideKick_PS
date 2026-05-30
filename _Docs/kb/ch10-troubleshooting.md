---
title: "When Things Go Wrong"
category: troubleshooting
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## Why this matters

Most of the time, SideKick PS just works. When something does not, you need
the answer quickly — not a technical explanation. This page covers the most
common real-world problems and their fixes, sorted by how often they actually
happen.

## Common problems and fixes

### QR code does not appear on screen

**You click the QR Code button and nothing happens, or a blank screen appears.**

Go to **Settings → Display** and check that at least one slide has content.
An empty slide produces a blank screen. Enter a URL or text in Slide 1, 2,
or 3 — or fill in your bank details at the bottom of the tab. At least one
slide needs content for the display to show.

### "No client found" when clicking Get Client

**SideKick PS cannot match the album to a GoHighLevel contact.**

The album name in ProSelect needs to contain the client's name or shoot
number in a way that matches GoHighLevel. Open GHL in your browser, find
the correct contact, then click **Get Client** again and use **Use Other**
to pick them manually.

### Toolbar has disappeared

**The floating toolbar is no longer visible.**

Right-click the SideKick PS tray icon (the rocket in the taskbar) and select
**Reload**. The toolbar reappears at its last saved position. If this happens
repeatedly, go to **Settings → Toolbar → Reset Position** to return it to
the default spot.

### GoCardless mandate not found

**You click the GoCardless button and it says no mandate exists.**

SideKick PS searches first by the client's email address, then by their name.
If both fail, the client may not have set up a mandate yet. Send them a setup
request — use the **Send Request** button in the dialog. If someone else is
paying (a partner, a parent), use **Use Another** to search by their name or
email instead.

### Sync Invoice failed

**The invoice does not appear in GoHighLevel after syncing.**

Check your GHL connection in **Settings → GHL Integration**. Click **Save &
Test** to verify. If the API key has expired, generate a new Private
Integration token in GoHighLevel (Settings → Integrations → Private
Integrations) and paste it in. Also check that your GHL Location ID is
correct — it is different from your Agency ID.

### Duplicate invoice warning keeps appearing

**Every time you sync, SideKick PS warns about an existing invoice.**

This is normal when you sync the same shoot more than once. Choose **Update**
to keep the existing invoice and any payments already made. Choose **Replace**
only when the order has changed significantly and you want to start fresh.
**New** creates a second invoice — rarely what you want.

### Camera button does nothing

**You click the Camera button and no photo is saved.**

The camera capture takes a screenshot of the ProSelect room view. Make sure
ProSelect is the active window and an album is open. Check that the save
folder exists — go to **Settings → File Management → Room Capture Folder**
and confirm the path is correct.

### Toolbar icons are invisible

**You can see the toolbar background but the icons blend in.**

SideKick PS normally detects the ProSelect background colour and adjusts.
If it gets it wrong, go to **Settings → Toolbar** and toggle **Auto
Background Detection** off, then manually choose an icon colour (White or
Black usually works). You can also pick a custom colour.

### Payment Calculator shows wrong balance

**The Balance Due at the top of the Payment Calculator does not match the order.**

Close the calculator, confirm the order total in ProSelect, and reopen it
via **📅 PayPlan**. The calculator reads the current order total when it
opens — it does not update live if you change the order with the calculator
open.

### Licence says "trial" after activation

**You entered a licence key but it still shows as trial mode.**

Right-click the SideKick PS tray icon and select **Reload**. The licence
status is checked on startup. If it still shows trial after reloading, check
that your internet connection is active — licence validation requires an
online check.

## Still stuck?

Open an AI chat (ChatGPT, Claude, or Gemini — free accounts work fine). Go
to `ps.ghl-sidekick.com/help.html`, click the copy button, and paste the
entire manual into the chat. Then ask your question in plain English.

## Related

- [AI Help — Ask ChatGPT About SideKick PS](ch11-ai-help.md)
- [Settings — Make SideKick Yours](ch09-settings-reference.md)
