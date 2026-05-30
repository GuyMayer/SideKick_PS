---
title: "How to set up a payment plan and Direct Debit mandate during a sales session"
category: payments
source_files: SideKick_PS.ahk, Inc_Hotkeys.ahk
last_sync: 2026-05-30
---

## What this does

Guides you through taking a payment plan deposit and setting up a GoCardless
Direct Debit mandate — all while the client authorises it on their own phone.
By the time you finish entering the payment schedule, the mandate is ready
and SideKick connects everything automatically.

## Before you start

- SideKick PS must be running with the floating toolbar visible.
- GoCardless must be enabled and configured in **Settings → GoCardless**.
- Two QR codes must be set up in **Settings → Display**:
  - **Slide 1** — your studio Wi-Fi credentials
  - **Slide 2** — your GoCardless mandate invitation link
- The client's contact record must already be loaded in SideKick PS
  (use **Get Client** first if not).

## Steps

1. Click the **QR Code** button on the SideKick toolbar — the display appears full-screen
   on your presentation monitor showing Slide 1 (Wi-Fi). Use the **↑ / ↓ arrow keys** to
   move between the three available slides. Use the **← / → arrow keys** to move the
   display between monitors if you have more than one screen.

2. Ask the client to scan the Wi-Fi QR code with their phone and join your studio network.
   Confirm they are connected before continuing.

3. Press **↓** to move to Slide 2 (GoCardless mandate invitation). The client scans it and
   begins filling in their bank details on their phone.

4. While the client completes the mandate form on their phone, open **Add Payment** in
   ProSelect and click **📅 PayPlan** (or press **Ctrl+Shift+P**) to open the Payment
   Calculator.

5. Confirm the **Balance Due** is correct. Enter a downpayment amount and payment method
   if applicable.

6. Set **No. Payments**, select **GoCardless DD** as the Pay Type, choose a **Recurring**
   frequency (Monthly or 4-Weekly), then ask the client which day of the month works best
   for them and select it under **Start Date**.

7. Click **✓ Schedule Payments** — SideKick PS enters all payment lines into ProSelect
   automatically.

8. Complete the order in ProSelect and come out of the Review Order section. SideKick PS
   displays a prompt: _"The pay plan has been documented. Now press the GoCardless button
   on the toolbar to set it up."_

9. Press **Escape** or click the **QR Code** button again to dismiss the display, then click
   the **GoCardless** button on the toolbar. SideKick PS automatically locates the client's
   mandate using their name and email address and links the payment schedule to it — no
   manual lookup required.

## What you should see

All payment lines appear in ProSelect's payment list with the correct amounts and dates.
The GoCardless dashboard shows the mandate as active with the schedule attached.

## Something went wrong?

- **Mandate not found by email** — SideKick PS will automatically retry using the client's
  name. If it still cannot match, a **Use Other** option appears — use this if a family
  member or different person is paying under a different name or email address.
- **Client cannot scan the QR code** — Increase the display size in **Settings → Display**
  or use the arrow keys to move the display to the correct monitor.
- **GoCardless button is missing from the toolbar** — GoCardless must be enabled in
  **Settings → GoCardless** before the button appears.

## Related

- How to display a QR code on screen
- How to build a payment plan with the Payment Calculator
- How to set up GoCardless in SideKick PS _(coming soon)_
