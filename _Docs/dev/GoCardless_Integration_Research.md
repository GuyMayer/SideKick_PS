# GoCardless Integration Research for SideKick_PS

**Date**: February 17, 2026  
**Status**: Research Complete - Ready for Implementation

---

## Executive Summary

GoCardless is a **Direct Debit payment platform** ideal for photography payment plans. It offers native instalment schedule support, low fees (1% + 20p capped at £4), and excellent Python SDK integration.

**Key Finding**: No native GoHighLevel integration exists - requires custom development.

---

## 1. GoCardless API Overview

### Authentication
- **Method**: Access Token (Bearer Token)
- **Format**: `Authorization: Bearer <your_access_token>`
- **Environments**:
  - Sandbox: `https://api-sandbox.gocardless.com/`
  - Live: `https://api.gocardless.com/`

### Main API Endpoints

| Resource | Endpoint | Description |
|----------|----------|-------------|
| Customers | `POST /customers` | Create customers |
| Mandates | `POST /mandates` | Create Direct Debit authorizations |
| Payments | `POST /payments` | Create one-off payments |
| Subscriptions | `POST /subscriptions` | Create recurring payments |
| Instalment Schedules | `POST /instalment_schedules` | Payment plans with dates |
| Billing Requests | `POST /billing_requests` | Modern unified payment flow |
| Refunds | `POST /refunds` | Process refunds |

### Direct Debit Payment Flow
```
1. Create Customer → Collect customer details
2. Set up Mandate → Customer authorizes future payments
3. Create Payments → Collect payments against the mandate
4. Webhooks → Receive status updates
```

---

## 2. Fees (UK Standard Plan)

| Type | Fee |
|------|-----|
| Domestic UK | 1% + 20p (capped at £4) |
| International | 2% + 20p |
| Transactions over £2,000 | +0.3% |

### Examples
- £300 payment = £3.00 + £0.20 = **£3.20** fee
- £500 payment = **£4.00** (capped)
- £1,000 payment = **£4.00** (capped)

---

## 3. Integration Architecture for SideKick_PS

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  SideKick_PS    │────▶│  Python Script   │────▶│   GoCardless    │
│  (AutoHotkey)   │     │  (gocardless.py) │     │      API        │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                      │
         ▼                      ▼
    Payment Calculator    GHL Invoice Sync
    (existing)            (existing)
```

### Integration Points with Existing SideKick_PS

1. **Payment Calculator** - Add "Direct Debit" button to create GoCardless payment plan
2. **Invoice Sync** - Link GoCardless schedule to GHL invoice via metadata
3. **Webhooks** - Update GHL invoice status when payments complete

---

## 4. Python SDK

### Installation
```bash
pip install gocardless_pro
```

### Basic Client Setup
```python
import gocardless_pro

client = gocardless_pro.Client(
    access_token="your_access_token",
    environment='sandbox'  # or 'live'
)
```

### Create Payment Plan (Instalment Schedule)
```python
# Create payment plan with specific dates
result = client.instalment_schedules.create_with_dates(params={
    "name": "Wedding Photography Package",
    "total_amount": 150000,  # £1,500 in pence
    "currency": "GBP",
    "instalments": [
        {"charge_date": "2026-03-01", "amount": 50000},
        {"charge_date": "2026-04-01", "amount": 50000},
        {"charge_date": "2026-05-01", "amount": 50000}
    ],
    "links": {"mandate": "MD123"}
})

# Or with automatic scheduling (monthly)
result = client.instalment_schedules.create_with_schedule(params={
    "name": "Portrait Package - 6 months",
    "total_amount": 60000,  # £600
    "currency": "GBP",
    "instalments": {
        "start_date": "2026-03-15",
        "interval_unit": "monthly",
        "interval": 1,
        "amounts": [10000, 10000, 10000, 10000, 10000, 10000]
    },
    "links": {"mandate": "MD123"}
})
```

### Create Mandate Link (Customer Authorization)
```python
# Step 1: Create Billing Request
billing_request = client.billing_requests.create(params={
    "mandate_request": {
        "scheme": "bacs",
        "currency": "GBP"
    }
})

# Step 2: Create Billing Request Flow (hosted payment page)
flow = client.billing_request_flows.create(params={
    "redirect_uri": "https://your-studio.com/payment-complete",
    "exit_uri": "https://your-studio.com/payment-cancelled",
    "prefilled_customer": {
        "given_name": "John",
        "family_name": "Smith",
        "email": "john@example.com"
    },
    "links": {"billing_request": billing_request.id}
})

# Customer visits flow.authorisation_url to set up mandate
print(f"Send this link to customer: {flow.authorisation_url}")
```

---

## 5. Webhook Events

Key events for photography workflow:

| Resource | Event | Description |
|----------|-------|-------------|
| `mandates` | `created` | Mandate set up successfully |
| `mandates` | `cancelled` | Customer cancelled authorization |
| `payments` | `created` | Payment scheduled |
| `payments` | `confirmed` | Payment collected successfully |
| `payments` | `failed` | Payment failed (retry possible) |
| `payments` | `paid_out` | Funds sent to your account |
| `instalment_schedules` | `created` | Payment plan set up |
| `instalment_schedules` | `errored` | Payment plan has issues |

### Webhook Handler Example
```python
import hmac
import hashlib
import json

def verify_webhook(request_body, signature_header, webhook_secret):
    computed_signature = hmac.new(
        webhook_secret.encode(),
        request_body,
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(computed_signature, signature_header)

# Handle payment confirmation
def handle_payment_confirmed(payment_id):
    # Update GHL invoice status
    # Send confirmation email to customer
    pass
```

---

## 6. GoHighLevel Integration Options

**No native integration exists.** Options:

### Option A: Direct API Bridge
Create Python script that:
1. Creates GoCardless payment plan when Payment Calculator is used
2. Stores GoCardless schedule ID in GHL invoice metadata
3. Receives webhooks and updates GHL invoice payments

### Option B: Zapier Integration
- Connect GoCardless webhooks to GHL via Zapier
- Higher latency, monthly subscription required

### Option C: Dual Sync (Recommended)
- Invoice data → GHL (for CRM/client management)
- Payment plan → GoCardless (for collection)
- Link via customer email or booking reference

---

## 7. Xero/QuickBooks Integration

GoCardless has **native integrations** with both:

| Platform | Integration | Auto-Reconciliation |
|----------|-------------|---------------------|
| Xero | Native app | ✅ Yes |
| QuickBooks | Native app | ✅ Yes |

Payments collected via GoCardless automatically match with invoices in accounting software.

---

## 8. Comparison: GoCardless vs Stripe

| Feature | GoCardless | Stripe |
|---------|------------|--------|
| **Primary Focus** | Direct Debit / Bank payments | Cards + Multiple methods |
| **UK Direct Debit** | Native, specialized | Via BACS integration |
| **Fees (UK)** | 1% + 20p (capped £4) | 1% + 20p (capped £5) |
| **Card Payments** | ❌ No | ✅ Yes |
| **Instant Bank Pay** | ✅ Yes (Open Banking) | ✅ Yes |
| **Instalment Schedules** | ✅ Native API | Manual implementation |
| **Settlement** | 2 working days | 2-7 days |
| **Failed Payment Recovery** | Success+ (70% recovery) | Smart retries |

### When to Choose GoCardless
- ✅ Primarily UK/European customers
- ✅ Recurring payments are core business
- ✅ Want lower fees for regular payments
- ✅ Don't need card payments

---

## 9. Supported Countries/Regions

- **UK** (Bacs)
- **Eurozone** (SEPA) - 19+ countries
- **Australia** (BECS)
- **New Zealand** (BECS NZ)
- **Canada** (PAD)
- **USA** (ACH)
- **Sweden** (Autogiro)
- **Denmark** (Betalingsservice)

**30+ countries total** with one integration.

---

## 10. Customer Experience (Mandate Setup)

1. Customer receives payment link (email/SMS)
2. Redirected to GoCardless-hosted page
3. Enters name, email, address
4. Selects their bank
5. Confirms bank account details
6. Reviews and authorizes mandate
7. Redirected back to studio website with confirmation

**Time**: ~2 minutes for customer to complete

---

## 11. Implemented Features in SideKick_PS

### GoCardless Toolbar Button
Click the GC toolbar button to:
1. Check if current client has an existing GoCardless mandate
2. View mandate status and bank details if found
3. Send billing request link via GHL email/SMS templates

### Payment Plan Dialog
When mandate exists, press **Create Payment Plan** to:
- Auto-populate from existing PayPlan lines in ProSelect
- Only includes DD payment types (GoCardless, Direct Debit, BACS)
- Skips non-DD payments (Card, Cash, Cheque, Bank Transfer, etc.)
- Pre-fills: amount, payment count, and start day

### DD Payment Type Filtering
The dialog scans `PayPlanLine[]` array and filters by PayType:
- ✅ **Included**: "GoCardless", "Direct Debit", "DD", "BACS"
- ❌ **Skipped**: "Card", "Cash", "Cheque", "Bank Transfer", etc.

This ensures only Direct Debit payments are submitted to GoCardless.

---

## 12. Future Enhancements

### Phase 2: Automated Flow
1. Auto-create mandate link when Payment Calculator used
2. Optional: Auto-send email via GHL

### Phase 3: Full Integration
1. Webhook server for payment status updates
2. Auto-update GHL invoice when payment confirmed
3. Dashboard showing payment plan status

### Required Settings
```ini
[GoCardless]
Enabled=1
AccessToken=your_access_token
Environment=live
WebhookSecret=your_webhook_secret
RedirectUrl=https://your-studio.com/payment-complete
```

---

## 13. Sample Python Module Structure

```
SideKick_PS/
├── gocardless_api.py           # Main GoCardless CLI client
├── gocardless_webhooks.py      # Webhook handler (Flask/FastAPI)
└── credentials.json            # API keys (gitignored)
```

---

## Next Steps

1. ✅ **Sign up** for GoCardless account (sandbox first)
2. ✅ **Get API credentials** from GoCardless dashboard
3. ✅ **Create** `gocardless_api.py` script
4. ✅ **Add** button to toolbar in SideKick_PS.ahk
5. ✅ **Add** Payment Plan dialog with DD filtering
6. **Test** with sandbox environment
7. **Go live** after testing

---

## Resources

- [GoCardless API Documentation](https://developer.gocardless.com/)
- [Python SDK Reference](https://github.com/gocardless/gocardless-pro-python)
- [Webhook Events Reference](https://developer.gocardless.com/api-reference/#appendix-webhook-events)
- [Instalment Schedules Guide](https://developer.gocardless.com/api-reference/#instalment-schedules)
