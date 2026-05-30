---
title: "How to set the rounding adjustment"
category: payments
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## What this does

Controls where the rounding difference goes when a balance cannot be split into perfectly equal payments — either added to the deposit or to the first scheduled payment.

## Before you start

- The Payment Calculator must be open (see How to build a payment plan with the Payment Calculator).

## Steps

1. Open the Payment Calculator (**📅 PayPlan** button in the Add Payment dialog, or **Ctrl+Shift+P**).
2. In the **Downpayment / Deposit** section, find the **Add rounding to:** radio buttons.
3. Select **Downpayment** to add the rounding difference to the deposit amount, or **1st Payment** to add it to the first scheduled payment.

_Example: a £208.33 balance split 3 ways gives £69.44 × 3 = £208.32, leaving a 1p rounding difference. This setting controls where that 1p goes._

## What you should see

A rounding info line below the deposit amount updates to show the adjustment amount (e.g. "Rounding of £0.01 added to deposit"). Your preference is saved for future sessions.

## Something went wrong?

- **No rounding notice appears** — The balance divides exactly, so no adjustment is needed and the notice will not show.

## Related

- How to build a payment plan with the Payment Calculator
