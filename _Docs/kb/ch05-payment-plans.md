---
title: "Payment Plans — Lock In the Sale Before They Leave"
category: payments
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## Why this matters

A client says yes to a £2,000 wall grouping. They are excited. But if they
walk out without committing to a payment schedule, doubt creeps in overnight.
"Can I really afford this?" By morning, the sale may be gone.

The Payment Calculator lets you build the full payment plan — deposit,
recurring payments, dates — and enter it into ProSelect in seconds. It also
handles the maths so you never have to explain a 1p rounding difference to a
client.

## Before you start

- ProSelect must be open with the client's order ready.
- The **Add Payment** dialog must be open in ProSelect.

## Steps

1. In ProSelect, open **Add Payment** for the order. SideKick PS places a
   **📅 PayPlan** button inside the payment window automatically.
2. Click **📅 PayPlan** — or press **Ctrl+Shift+P** from anywhere — to open
   the Payment Calculator.
3. Check the **Balance Due** at the top. If it is wrong, close the calculator,
   fix the order in ProSelect, and reopen.
4. Enter a deposit amount and choose the payment method (or leave blank for
   no deposit). The date defaults to today.
5. Set **No. Payments** — how many payments spread over time.
6. Choose a **Pay Type** — **GoCardless DD** for automated collection, or
   **Credit Card**, **Cash**, or whatever methods you accept.
7. Select a **Recurring** frequency — **Monthly** is the most common, but
   Weekly, Bi-Weekly, and 4-Weekly are available.
8. Ask the client which day of the month works best, and choose it under
   **Start Date** with the starting month.
9. Click **✓ Schedule Payments**.

SideKick PS enters every payment line into ProSelect — amount, date, and
method — in one go.

## The rounding setting

Sometimes the balance does not divide perfectly. For example, £208.33 split
3 ways: £69.44 × 3 = £208.32, leaving 1p unaccounted for. The Payment
Calculator handles this automatically.

In the calculator, under the deposit section, you will see an **Add rounding
to:** option:

- **Downpayment** — the 1p goes into the deposit.
- **1st Payment** — the 1p goes into the first scheduled payment.

Whatever you choose is remembered for next time.

## What success looks like

All payment lines appear in ProSelect's payment list. Every line has the
correct amount, date, and payment type. You click save. Done.

## When things go wrong

- **GoCardless DD start date was adjusted** — Direct Debit mandates need a
  minimum setup time (usually 3–4 working days). SideKick PS moves the start
  date forward automatically to the earliest valid date.
- **Balance Due shows the wrong figure** — The order total in ProSelect may
  have changed since you opened the calculator. Close it, correct the order,
  and reopen.

## Related

- [GoCardless — Get Paid Without Chasing](ch06-gocardless.md)
- [Your First Sale — Start to Finish](ch03-first-sale.md)
