---
title: "How to build a payment plan with the Payment Calculator"
category: payments
source_files: SideKick_PS.ahk, Inc_Hotkeys.ahk
last_sync: 2026-05-30
---

## What this does

Calculates and schedules all payment lines for a client's order directly into ProSelect in one step — splitting the balance into a deposit and regular payments so you never have to enter them manually.

## Before you start

- ProSelect's **Add Payment** dialog must be open for the current order.
- SideKick PS must be running.

## Steps

1. In ProSelect, open the **Add Payment** dialog. A **📅 PayPlan** button appears automatically in the dialog.
2. Click **📅 PayPlan** — or press **Ctrl+Shift+P** from anywhere — to open the Payment Calculator.
3. Confirm the **Balance Due** shown at the top is correct. If not, close the calculator, correct the order in ProSelect, then reopen it.
4. In the **Downpayment / Deposit** section, enter the deposit amount and select the payment method. The date defaults to today — change it if needed.
5. In the **Scheduled Payments** section, set **No. Payments**, choose a **Pay Type**, and select a **Recurring** frequency (Monthly, Weekly, Bi-Weekly, or 4-Weekly).
6. Ask the client which day they prefer for payments, then select it under **Start Date** along with the start month.
7. Click **✓ Schedule Payments** — SideKick PS enters all payment lines into ProSelect automatically.

## What you should see

Each payment line appears in the ProSelect Add Payment list with the correct amount, date, and payment type — ready to save.

## Something went wrong?

- **Balance Due shows the wrong amount** — Close the calculator, correct the order total in ProSelect, then reopen via **📅 PayPlan**.
- **"GoCardless DD" start date was adjusted automatically** — Direct Debit mandates require a minimum setup period. SideKick PS has moved the start date to the earliest valid date to comply with GoCardless requirements.

## Related

- How to set the rounding adjustment
- How to set up a payment plan and Direct Debit mandate during a sales session
