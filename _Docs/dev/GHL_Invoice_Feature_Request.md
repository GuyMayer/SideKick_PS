# GoHighLevel Feature Request

## Subject: Combine Downpayment with Recurring Invoice Schedule

---

**To:** GoHighLevel Support Team  
**From:** Guy Mayer, Zoom Photography Studios Ltd  
**Date:** February 3, 2026

---

## Summary

Requesting the ability to combine a one-time downpayment/deposit with a recurring payment schedule in a single invoice operation.

---

## Current Use Case

We operate a photography studio and frequently create payment plans for clients. A typical payment plan looks like this:

| Payment Type | Amount | Method | Date |
|-------------|--------|--------|------|
| Deposit/Downpayment | £250 | Credit Card | Today |
| Payment 1 | £333.33 | Direct Debit | March |
| Payment 2 | £333.33 | Direct Debit | April |
| Payment 3 | £333.33 | Direct Debit | May |

This is a very common pattern across many service industries:
- Photography & Videography
- Wedding & Event Services
- Home Improvements & Construction
- Coaching & Training Programs
- Any service with a booking deposit

---

## The Problem

Currently, the GHL invoice and scheduling API doesn't support combining a one-time downpayment with a recurring payment schedule in a single operation.

### Current Workarounds (All Suboptimal)

1. **Separate Invoices** - Create one invoice for the deposit, then a separate recurring schedule for remaining payments
   - *Problem:* Fragmented records, difficult reconciliation

2. **Include Deposit in Schedule** - Add deposit as first payment in recurring schedule
   - *Problem:* Doesn't work when payment methods differ (Card vs DD)

3. **Manual Adjustment** - Manually adjust amounts to account for rounding
   - *Problem:* Time-consuming, error-prone

### Technical Limitation

The current `/invoices/schedule/` endpoint only supports:
- A single `amount` for all payments
- A single `paymentMethod` for the schedule
- No concept of an "initial" or "deposit" payment

---

## Requested Functionality

The ability to create an invoice schedule that includes:

### 1. Initial Payment (Downpayment/Deposit)
- Custom amount (different from recurring amount)
- Separate payment method (e.g., Credit Card)
- Immediate or specific date

### 2. Recurring Payments
- Regular equal amounts
- Different payment method (e.g., GoCardless/Direct Debit)
- Configurable start date and frequency

---

## Proposed API Structure

```json
{
  "name": "Payment Plan - John Smith",
  "contactId": "abc123",
  "schedule": {
    "initialPayment": {
      "amount": 250.00,
      "dueDate": "2026-02-03",
      "paymentMethod": "credit_card",
      "description": "Booking Deposit"
    },
    "recurringPayments": {
      "amount": 333.33,
      "startDate": "2026-03-03",
      "frequency": "MONTHLY",
      "count": 3,
      "paymentMethod": "direct_debit",
      "description": "Monthly Payment"
    }
  }
}
```

### Alternative: Array-Based Approach

```json
{
  "payments": [
    {
      "amount": 250.00,
      "dueDate": "2026-02-03",
      "paymentMethod": "credit_card",
      "isInitial": true
    },
    {
      "amount": 333.33,
      "startDate": "2026-03-03",
      "frequency": "MONTHLY",
      "count": 3,
      "paymentMethod": "direct_debit"
    }
  ]
}
```

---

## Business Impact

This enhancement would:

| Benefit | Description |
|---------|-------------|
| **Streamlined Workflow** | One API call instead of multiple |
| **Cleaner Records** | Single payment plan, not fragmented invoices |
| **Better Reconciliation** | All payments linked to one agreement |
| **Real-World Accuracy** | Reflects actual client payment agreements |
| **Reduced Complexity** | Simpler integrations for third-party tools |
| **Time Savings** | Faster payment plan creation for businesses |

---

## Who Would Benefit

- **Service-based businesses** with deposit + payment plans
- **Subscription businesses** with setup fees
- **Agencies** billing retainer + project fees
- **Integration developers** building GHL automations
- **Any business** using split payment methods

---

## Our Integration Context

We're building **SideKick_PS**, an automation tool that syncs invoices from ProSelect (photography software) to GoHighLevel. Our users frequently need to:

1. Take a deposit by card at the session
2. Set up recurring Direct Debit for the balance

This is currently our most requested feature, and the API limitation is the only blocker.

---

## Willingness to Participate

We're happy to:
- Provide additional technical details
- Test beta API endpoints
- Share real-world use cases and data
- Provide feedback during development

---

## Contact

**Guy Mayer**  
Zoom Photography Studios Ltd  
guy@zoom-photo.co.uk

---

*Thank you for considering this feature request. We believe it would benefit a significant portion of the GHL user base.*
