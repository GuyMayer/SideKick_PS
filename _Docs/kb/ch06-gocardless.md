---
title: "GoCardless — Get Paid Without Chasing"
category: payments
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## Why this matters

Chasing late payments is the worst part of running a photography business. It
is awkward, it damages the client relationship, and it takes time you do not
have. GoCardless Direct Debit means the money comes to you automatically on
the agreed date — no reminders, no awkward texts, no chasing.

SideKick PS makes the whole thing quick: the client sets up their mandate on
their own phone while you finish the order, and SideKick PS links everything
together.

## Before you start

- GoCardless must be enabled in **Settings → GoCardless**.
- You need a GoCardless account connected to SideKick PS.
- Two QR codes in **Settings → Display**:
  - **Slide 1** — your studio Wi-Fi credentials.
  - **Slide 2** — your GoCardless mandate invitation link.

## During a sale: the full flow

### 1. Show the QR codes

Click the **QR Code** button on the toolbar. A full-screen display appears on
your presentation monitor. Slide 1 shows your Wi-Fi QR code — the client scans
it and joins your studio network.

Press **↓** to move to Slide 2 — your GoCardless mandate invitation. The
client scans it and fills in their bank details on their phone. You carry on
with the order.

### 2. Build the payment plan

While the client completes the mandate, open **Add Payment** in ProSelect,
click **📅 PayPlan**, and build the payment schedule (see the Payment Plans
chapter). Choose **GoCardless DD** as the Pay Type.

### 3. Link the mandate

After scheduling the payments and completing the order, come out of the
Review Order section. SideKick PS shows a prompt: "Now press the GoCardless
button."

Click the **GoCardless** button on the toolbar. SideKick PS searches for the
client's mandate — first by email, then by name if email fails. If it finds
a match, it links the payment schedule to the mandate. Done.

### 4. If no mandate exists yet

If the client does not have a mandate, SideKick PS offers to send them a
setup request by email or SMS using your GoHighLevel templates. The client
receives the link and completes the setup on their own device.

## Checking a mandate outside a sale

You can click the **GoCardless** button at any time to check if a client has
an active mandate. If they do, you can add a new payment plan or view their
GoCardless account.

## Use Another — when someone else is paying

Sometimes the person paying is not the client in the album. A parent, a
partner, a different name or email. When SideKick PS cannot match by email
or name, click **Use Another** and type the payer's name or email. SideKick
PS searches GoCardless for that person's mandate instead.

## What success looks like

The GoCardless dashboard shows the mandate as active with the payment
schedule attached. The client receives their payment notifications
automatically. You receive the money on the scheduled dates — no chasing.

## When things go wrong

- **Mandate not found** — SideKick PS tries email, then name. If both fail,
  the client may not have a mandate yet. Send a setup request.
- **"Use Another" cannot find the payer** — Double-check the spelling of the
  name or email. GoCardless matches exactly.
- **GoCardless button is missing from the toolbar** — GoCardless must be
  enabled in **Settings → GoCardless** first.

## Related

- [Payment Plans — Lock In the Sale Before They Leave](ch05-payment-plans.md)
- [The Display — QR Codes, Bank Details & Images](ch08-display.md)
