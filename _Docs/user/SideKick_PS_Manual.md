# SideKick PS — User Manual

**Version 3.0.4** | March 2026 | © Zoom Photography

---

## Contents

1. [What is SideKick PS?](#what-is-sidekick-ps)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [The Toolbar](#the-toolbar)
5. [GHL Client Lookup](#ghl-client-lookup)
6. [Invoice Sync](#invoice-sync)
7. [Invoice Update & Resync](#invoice-update--resync)
8. [Invoice Deletion](#invoice-deletion)
9. [GoCardless Integration](#gocardless-integration)
10. [Payment Plan Calculator](#payment-plan-calculator)
11. [Display — QR Codes & Bank Details](#display--qr-codes--bank-details)
12. [Room Capture](#room-capture)
13. [Room Capture Email](#room-capture-email)
14. [Open GHL Contact](#open-ghl-contact)
15. [Quick Print & Email PDF](#quick-print--email-pdf)
16. [SD Card Download](#sd-card-download)
17. [Greeting Cards (Cardly)](#greeting-cards-cardly)
18. [Settings](#settings)
19. [Keyboard Shortcuts](#keyboard-shortcuts)
20. [System Tray](#system-tray)
21. [Licensing & Activation](#licensing--activation)
22. [Troubleshooting](#troubleshooting)
23. [Support](#support)

---

## What is SideKick PS?

SideKick PS is a Windows companion app for **ProSelect** photography software. It adds a floating toolbar to ProSelect with one-click access to:

- **GoHighLevel (GHL) CRM integration** — import client details, sync invoices, upload contact sheets
- **GoCardless Direct Debit** — check mandates, send DD setup links, create payment plans
- **Payment plan calculator** — generate payment schedules and auto-enter them into ProSelect
- **Greeting cards (Cardly)** — send personalised physical postcards to clients
- **Room capture** — screenshot the ProSelect room view and save as JPG
- **Display** — show QR codes, bank transfer details, and custom slides during a sale
- **SD card download** — download, rename, and archive photos from memory cards

SideKick PS works with **ProSelect 2022, 2024, and 2025** on Windows 10/11.

---

## Installation

1. Download the latest release from [GitHub Releases](https://github.com/GuyMayer/SideKick_PS/releases/latest)
2. Run the installer (`SideKick_PS_Setup.exe`)
3. Accept the license agreement
4. Choose your install location (default: `C:\Program Files (x86)\SideKick_PS`)
5. Launch SideKick PS from the Start Menu or desktop shortcut

SideKick PS installs to the system tray and runs in the background. It activates automatically when ProSelect is open.

---

## Getting Started

### First Launch

On first launch you'll be prompted to:

1. **Enter your license key** or start a **14-day free trial**
2. **Set up GHL integration** (optional) — the Setup Wizard walks you through entering your GHL API Key and Location ID

### Requirements

| Requirement | Details |
|---|---|
| Operating System | Windows 10 or 11 |
| ProSelect | Version 2022, 2024, or 2025 |
| GHL Account | Required for CRM features (optional for payment calculator) |
| Internet | Required for GHL sync, licensing, and updates |

---

## The Toolbar

When ProSelect is open, a floating toolbar appears docked to the ProSelect title bar. Buttons are grouped into three sections — **GHL**, **Shortcuts**, and **Services** — separated by visual dividers. All buttons are configurable in Settings → Toolbar:

#### GHL Buttons

| Button | Icon | What it Does |
|---|---|---|
| **Get Client** | 👤 (blue) | Import client details from GHL into ProSelect |
| **Sync Invoice** | 📋 (green) | Export the current order and sync it to GHL as an invoice. **Ctrl+Click** to delete the last synced invoice |
| **Open GHL** | 🌐 (teal) | Open this client's GHL contact page in your browser |

#### Shortcut Buttons

| Button | Icon | What it Does |
|---|---|---|
| **Review Order** | 🧾 (amber) | Open ProSelect's Orders → Review Order |
| **Room Capture** | 📷 (maroon) | Screenshot the ProSelect room view, with option to email |
| **Open Folder** | 📂 (dynamic) | Open the album's image source folder. Icon changes to match your selected file browser (Bridge, Lightroom, or Explorer) |
| **Photoshop** | PS (pink) | Send selected image to Photoshop (Ctrl+T) |
| **Refresh** | 🔄 (cyan) | Update album (Ctrl+U) |
| **Sort Order** | 🔀 (yellow) | Toggle between random and filename sort order |
| **Quick Print** | 🖨 (orange) | Auto-print with configured template |
| **Email PDF** | 📧 (orange) | Print invoice to PDF, then email it to the client via a GHL email template |
| **QR Code** | QR (white) | Display a QR code on-screen (configurable URL) |
| **SD Download** | 📥 (orange) | Download photos from SD card *(only shown if enabled)* |

#### Service Buttons

| Button | Icon | What it Does |
|---|---|---|
| **GoCardless** | GC (dynamic) | Check mandates, send DD setup links, create payment plans |
| **Cardly** | ✉ (orange) | Send personalised greeting cards via Cardly |
| **Settings** | ⚙ (purple) | Open SideKick PS settings |

### Toolbar Behaviour

- The toolbar **auto-hides** when ProSelect loses focus
- It **stays hidden** when ProSelect dialogs are open (Client Setup, Print, etc.)
- It **reappears** when you return to the main ProSelect window
- Icon colours can be changed in **Settings → Hotkeys → Icon Color**
- **Section separators** visually divide GHL, Shortcuts, and Services button groups

### Toolbar Scaling

The toolbar size can be adjusted to suit different screen sizes:

- **Auto-Scale** — checkbox in Settings → Toolbar auto-links toolbar size to the ProSelect window width
- **Manual Scale** — dropdown (50%–100%) for manually sizing the toolbar on smaller screens

### Toolbar Button Settings

Toolbar buttons are configured using **clickable icons** in Settings → Toolbar. Click an icon to toggle it on/off — the icon background and label update immediately. This replaces the older toggle-slider approach.

---

## GHL Client Lookup

**Toolbar button:** 👤 Get Client | **Shortcut:** Ctrl+Shift+G

Import client data from GoHighLevel into ProSelect with one click.

### How it Works

1. Click the **Get Client** button on the toolbar
2. SideKick PS looks for the client in two ways:
   - **Album name** — if the current ProSelect album contains a GHL Client ID (e.g., `Smith_abc123`), it uses that directly
   - **Chrome browser** — scans open Chrome tabs for a GHL contact page URL
3. Client data is fetched from GHL via the API
4. ProSelect fields are populated automatically:
   - First Name, Last Name
   - Email, Phone
   - Address
   - The album is renamed to include the Client ID (e.g., `Smith_abc123`)

### Auto-Load vs Preview Mode

In **Settings → GHL Integration**, there's an **"Autoload client data"** toggle:

| Mode | Behaviour |
|---|---|
| **Auto-load ON** | Client data is filled in immediately — no dialog |
| **Auto-load OFF** | A preview dialog shows the data first, with an "Update ProSelect" button |

### Tips

- Open the client's GHL contact page in Chrome **before** clicking Get Client
- If the album already has a Client ID embedded, you don't need Chrome open
- The Client ID is stored in the album name so future syncs can find the client automatically

---

## Invoice Sync

**Toolbar button:** 📋 Sync Invoice | **Ctrl+Click:** Delete last synced invoice

Create a professional invoice in GHL from the current ProSelect order.

### How it Works

1. Click the **Sync Invoice** button
2. SideKick PS automatically:
   - Opens ProSelect's **Export Orders** dialog
   - Selects **Standard XML** format
   - Checks all items and exports
   - Parses the exported XML
   - Creates an invoice in GHL with all order items, payments, and client details
3. A **progress window** shows each step in real time
4. When complete, the invoice URL opens in your browser (if enabled)

### What Gets Synced

| Data | Details |
|---|---|
| **Invoice Name** | "Client Name - ShootNo" format |
| **Line Items** | All ordered products with quantities and prices |
| **Product Names** | Automatically matched to GHL products by SKU (see below) |
| **Payments** | Past payments recorded as transactions |
| **Future Payments** | Created as a recurring payment schedule in GHL |
| **Contact Sheet** | JPG thumbnail sheet uploaded to GHL Media (if enabled) |
| **Client Details** | Name, email, phone, address updated on GHL contact |
| **Business Details** | Your business name, address, logo, phone pulled from GHL |
| **Tags** | Contact and opportunity tags applied automatically (if configured) |

### GHL Product Lookup (SKU Matching)

SideKick PS automatically matches your ProSelect products to GHL products using **Product Codes (SKUs)**:

1. When you sync an invoice, SideKick checks each item's **Product Code** from ProSelect
2. It looks up that SKU in your GHL Products (under Payments → Products → Price SKUs)
3. If a match is found, the **GHL product name** is used on the invoice instead of the ProSelect name
4. This ensures invoice line items match your GHL product catalog exactly

**Example:**
- ProSelect exports: `Product_Name: "Luster Print"`, `Product_Code: "com1a"`
- GHL has a product with SKU `com1a` named `"Composite 1 - 43x13"`
- Invoice shows: **"Composite 1 - 43x13"** (the GHL name)

**To set up SKU matching:**
1. Add **Product Codes** to your ProSelect Price Lists (Setup → Price Lists)
2. In GHL → Payments → Products, create products with matching **SKUs** (set in the Price section)
3. The SKUs must match exactly (case-insensitive)

See [ProSelect Product Code Setup](docs/ProSelect_Product_Code_Setup.md) for detailed instructions.

### Duplicate Invoice Detection

When syncing an invoice, SideKick checks for existing invoices for the same shoot. If a duplicate is found, a dialog appears with four options:

| Button | When to Use |
|---|---|
| **Replace** | Delete the old invoice and create a fresh one (default when no payments recorded) |
| **Update** | Update the existing invoice's line items in place, preserving recorded payments (default when payments exist) |
| **New** | Create another invoice alongside the existing one |
| **Cancel** | Do nothing |

The dialog shows the existing invoice's payment status so you can make an informed choice.

### Payment Plan Invoices

If the order has a payment plan with future payments:

- A **main invoice** is created with all line items
- Past payments are recorded immediately
- A **recurring schedule** is set up in GHL for future payments
- The deposit/downpayment is handled separately if rounding applies

### Invoice Settings

Configure in **Settings → GHL Integration → Invoice Sync**:

| Setting | What it Does |
|---|---|
| **Watch Folder** | Where ProSelect exports XML files to |
| **Open invoice URL** | Auto-open the invoice in your browser after sync |
| **Financials only** | Exclude individual image lines, only sync totals |
| **Create contact sheet** | Generate and upload a JPG contact sheet with the order |
| **Contact tags** | Apply a tag to the GHL contact after sync |
| **Opportunity tags** | Apply a tag to the GHL opportunity after sync |
| **Auto tag on inv** | Automatically apply tags during invoice sync |

### Rounding

When payment amounts don't divide evenly, there's a small rounding difference (e.g., £0.01). You can control where this goes:

- **Add to Downpayment** — the deposit absorbs the rounding (simpler)
- **Add to 1st Payment** — the first scheduled payment is adjusted

This is set in the **Payment Calculator** and also in **Settings → GHL Integration**.

---

## Invoice Update & Resync

When an order changes after the initial sync, you don't need to start from scratch. SideKick offers two ways to bring the GHL invoice up to date.

### Update Invoice

Updates the existing invoice's line items and amounts **in place** — preserving any payments already recorded.

**How it works:**

1. When a duplicate invoice is detected, click **Update**
2. SideKick replaces the invoice's line items with the current ProSelect order
3. Payments already recorded in GHL are preserved
4. Any new past payments not yet in GHL are recorded automatically
5. Existing future recurring schedules are cancelled and recreated to match the new amounts

**Best for:** Orders where the client has added or removed products, but some payments are already recorded.

### Resync Invoice

Deletes the old invoice(s) for the shoot and creates a fresh one from scratch.

**How it works:**

1. When a duplicate invoice is detected, click **Replace**
2. SideKick deletes the existing invoice(s) matching the shoot number
3. A new invoice is created with the current ProSelect order data
4. If provider payments (GoCardless/Stripe) need manual refund, the process aborts safely with instructions

**Best for:** Starting over when the order has fundamentally changed.

### Safety Checks

- If the new order total is less than the amount already paid, SideKick warns you and suggests options (replace, refund in GHL, or re-export)
- Provider-managed payments (GoCardless, Stripe) are flagged — you must handle refunds through those platforms before resyncing
- Deletion is scoped to the specific shoot number, not all client invoices

---

## Invoice Deletion

**Trigger:** Ctrl+Click the **Sync Invoice** button

Delete the last synced invoice from GHL.

### How it Works

1. Hold **Ctrl** and click the **Sync Invoice** (📋) button on the toolbar
2. SideKick PS finds the last synced invoice for the current client
3. A confirmation dialog appears showing the invoice details
4. Click **Yes** to delete, or **No** to cancel
5. The invoice is removed from GHL and any associated payment schedules are cancelled

### When to Use

- You synced incorrect order data and need to start fresh
- The client's order has changed and you need to re-sync
- Testing and need to clean up test invoices

### Tips

- Only the most recent invoice for the current client can be deleted
- The client must have a Client ID in the album name
- Payment schedules associated with the invoice are also cancelled

### GHL Integration Disclaimer

**Important:** SideKick connects to YOUR GoHighLevel account using credentials you provide. You are solely responsible for your GHL account and data.

**SideKick does NOT:**
- Have access to your GHL account beyond what you configure
- Act as an agent for GoHighLevel
- Take responsibility for GHL service availability, errors, or outages
- Guarantee accuracy of synced data between ProSelect and GHL
- Accept liability for incorrect invoices, payments, or client data
- Support or maintain GoHighLevel — contact GHL for their issues

**Third-Party Service Notice:** The license or agreement for GoHighLevel is between YOU and GoHighLevel. Zoom Photography Ltd is NOT a party to that agreement. GoHighLevel is solely responsible for their service, warranties (to the extent not disclaimed), and any claims relating to their service. GoHighLevel may change their API, pricing, or terms at any time without notice.

**Disclaimer of Warranties:** SideKick PS is provided "AS IS" and "AS AVAILABLE" without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement. You understand that you use the Software at your own discretion and risk.

**Limitation of Liability:** Zoom Photography Studios Ltd shall not be liable for any direct, indirect, incidental, special, consequential, or exemplary damages arising from your use of GoHighLevel integration, including but not limited to damages for loss of profits, data, or business interruption.

**Indemnification:** You agree to indemnify and hold harmless Zoom Photography Ltd from any claims, damages, or expenses arising from your use of the GHL integration or violation of GoHighLevel's terms of service.

---

## GoCardless Integration

**Toolbar button:** GC (GoCardless)

Manage Direct Debit payments through GoCardless — check mandates, send setup links, and create payment plans.

### What is GoCardless?

GoCardless is a Direct Debit payment platform ideal for photography payment plans. It allows you to collect recurring payments automatically from your clients' bank accounts.

**Supported Regions:**
- 🇬🇧 United Kingdom (BACS Direct Debit)
- 🇺🇸 United States (ACH)
- 🇪🇺 European Union (SEPA)
- 🇦🇺 Australia (BECS)
- 🇨🇦 Canada (PAD)
- 🇳🇿 New Zealand

### Why Set Up DD During the Sale?

**The #1 mistake photographers make:** Agreeing a payment plan with a client, then forgetting to set up the Direct Debit later. This leads to:

- Lost revenue
- Awkward chasing conversations
- Complicated accounting

**With SideKick + GoCardless:** You set up DD payments right there during the sale — before the client leaves. Payments are collected automatically. Never forget, never chase.

### Checking for Existing Mandates

1. Import a client using **GHL Client Lookup** first
2. Click the **GC** button on the toolbar
3. SideKick PS searches GoCardless for matching customer by email
4. If a mandate exists, you'll see:
   - ✅ Mandate status (active/pending)
   - Bank name
   - Option to **Create Payment Plan**
5. If the email isn't found in GoCardless, SideKick automatically retries by **name** (see Name Fallback below)
6. If no customer is found at all, you can **Send Mandate Request**

### Name Fallback (Different Email)

Clients sometimes use a different email with GoCardless than the one in GHL. When the email lookup returns "No Customer", SideKick automatically searches GoCardless by the client’s name.

If a name match is found, a **"Same Client?"** dialog appears showing:
- **GHL details** — name and email from your CRM
- **GoCardless details** — name, email, bank, and mandate status from GoCardless

Choose:
- **Yes** — confirms it's the same client, proceeds to create the payment plan using the GoCardless mandate
- **No — Use Another** — opens a manual search dialog to find the correct mandate by name or email
- **Cancel** — aborts the GoCardless flow

### Sending a Mandate Request

If the client doesn't have a mandate:

1. Click **Send Mandate Request**
2. SideKick creates a GoCardless Billing Request with a setup link
3. Choose to send via GHL **Email**, **SMS**, or both
4. The client receives a link to authorize Direct Debit payments
5. Once they complete setup, their mandate becomes active

### Creating a Payment Plan

When a client has an active mandate:

1. First, create a payment plan in the **Payment Calculator** with GoCardless DD as the payment type
2. Click the **GC** button to check the mandate
3. Click **Create Payment Plan** (or **Replace PayPlan** if existing plans are detected)
4. The dialog auto-populates from your PayPlan lines:
   - **Plan Name** — auto-generated from your naming format in Settings (e.g., ShootNo-LastName)
   - **Amount** — per-payment amount (from DD payments only)
   - **Payments** — count of DD payments found
   - **Day** — day of month for collection

### Silent Plan Creation

When all required data is available — an active mandate and DD payment lines in the album — SideKick creates the GoCardless instalment schedule **silently** (no dialog window). This happens automatically when you click the GC button after entering DD payments, and both the mandate and paylines are ready.

For **single DD payments**, SideKick creates a one-off payment instead of an instalment schedule — this is more appropriate for one-time charges and avoids unnecessary GoCardless schedule overhead.

### Replacing an Existing Plan

If GoCardless already has active plans for the mandate:

1. The mandate dialog shows a **Replace PayPlan** button (instead of "Add PayPlan")
2. Clicking it cancels all active instalment schedules, subscriptions, and pending one-off payments on the mandate
3. A new plan is then created with the current payment data

This is useful when the client's order or payment schedule changes after a plan was already set up.

### Auto-Detect GoCardless on Payment Entry

After writing Direct Debit payments to an album, SideKick detects GoCardless/DD payment types and offers to create them in GoCardless immediately — so you never forget to set up the Direct Debit.

### Use Another Mandate

When no mandate is found for the current client's email, you can search by a **partner's name or email** to find their mandate. Useful when the DD mandate is in the other partner's name.

### Single Payments & Subscriptions (GC Payments Tab)

SideKick_GC includes a **Payments** tab for creating ad-hoc payments against an active mandate:

- **Single Payments** — one-off charges with amount, charge date, description, reference, and metadata
- **Subscriptions** — recurring payments with configurable frequency (weekly/monthly/yearly), interval, day-of-month, and end condition (indefinite, fixed count, or end date)
- **Inline plan naming** — the Statement Label prefix is shown inline so you see the full bank statement name

### Stale Mandates

The **Stale Mandates** window finds GoCardless mandates with no payment plans ever created — ideal for catching forgotten setups.

**To use:**
1. Open **Settings → GoCardless**
2. Click the **Stale Mandates** button
3. A sortable table shows mandates with no plans: customer name, email, last payment date, total collected, and mandate ID
4. Select mandates with checkboxes and click **Cancel** to batch-cancel them (with two-stage safety warnings — cancellation is irreversible)

### Close to Tray (SideKick_GC)

SideKick_GC can stay running in the background for mandate polling:

- **Close to system tray** — enable in GC Settings to have the X button hide the window to the system tray instead of minimising
- **Toast on Mandate Cancellation** — shows a Windows notification when polling detects a bank-cancelled mandate (enabled by default)
- **Exit Program** — the red "⏻ Exit" button in GC Settings fully quits the application. If polling is active, a warning reminds you that SideKick needs to stay running for notifications to work.

### DD Payment Filtering

The payment plan dialog **only includes Direct Debit payments**:

| ✅ Included | ❌ Skipped |
|------------|------------|
| GoCardless DD | Credit Card |
| Direct Debit | Cash |
| BACS | Cheque |
| DD | Bank Transfer |

This ensures only appropriate payments are submitted to GoCardless. Non-DD payments (deposits paid by card, etc.) are skipped automatically.

### Duplicate Plan Names

If you create multiple plans for the same shoot (e.g., client adds more products later), GoCardless requires unique names. SideKick automatically handles this:

- First plan: `P26001-Smith`
- Second plan: `P26001-Smith-1`
- Third plan: `P26001-Smith-2`

The dialog shows the actual name used after creation.

### Finding Forgotten Mandates — Stale Mandates

Even with best intentions, some mandates slip through without payment plans. The **Stale Mandates** button in Settings → GoCardless launches a dedicated window to find and manage these.

**To use:**
1. Open **Settings → GoCardless**
2. Click the **Stale Mandates** button
3. A sortable table shows all active mandates with no payment plans ever created
4. Each row shows: customer name, email, last payment date, total collected, and mandate ID
5. Select mandates with checkboxes for batch cancellation, or click **Copy** to copy the list to clipboard for follow-up

**Useful for:**
- Finding mandates where you forgot to set up the payment plan
- Follow-up reminders to clients who never completed their order
- Identifying setup issues
- Monthly audit of outstanding mandates

**Pro tip:** Run this monthly to catch any forgotten setups before they become awkward conversations.

### Tips

- **Mandate setup takes 2-3 business days** — plan ahead before the first payment date
- GoCardless fees vary by region (UK: 1% + 20p, capped at £4)
- Payments are collected automatically on the scheduled dates
- Failed payments are automatically retried by GoCardless
- **Best practice:** Set up DD during the sale, not later
- **Monthly check:** Use the "No Plans" button to find forgotten mandates

### Compliance & Your Responsibilities

**Important:** When you use GoCardless through SideKick, YOU are the merchant. SideKick is simply a tool that connects to YOUR GoCardless account.

**You are solely responsible for:**
- Having your own valid GoCardless merchant account
- Complying with GoCardless Terms of Service
- Following your regional Direct Debit scheme rules (BACS/BECS/SEPA/ACH/PAD)
- Providing advance payment notifications to your customers (GoCardless handles this automatically)
- Keeping mandate authorization records (GoCardless stores these for you)
- Handling customer disputes and refunds through your GoCardless dashboard

**GoCardless handles for you:**
- DDR Service Agreement (provided to your customers during mandate setup)
- PCI compliance for payment processing
- Payment notifications to customers
- Failed payment retries
- Scheme rule compliance for payment submissions

**SideKick does NOT:**
- Process payments (GoCardless does)
- Store your customers' bank details (stored by GoCardless)
- Have access to your GoCardless account (you provide your own API token)
- Act as an agent for GoCardless
- Take any responsibility for GoCardless service availability, errors, or outages
- Guarantee the accuracy or completeness of any payment data
- Accept liability for failed payments, chargebacks, or disputes

**Third-Party Service Notice:** The license or agreement for GoCardless is between YOU and GoCardless. Zoom Photography Ltd is NOT a party to that agreement. GoCardless is solely responsible for their service, payment processing, warranties (to the extent not disclaimed), and any claims relating to their service. GoCardless may change their API, pricing, or terms at any time without notice.

**Disclaimer of Warranties:** SideKick PS is provided "AS IS" and "AS AVAILABLE" without warranty of any kind, express or implied, including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement. You understand that you use the Software at your own discretion and risk.

**Limitation of Liability:** Zoom Photography Studios Ltd shall not be liable for any direct, indirect, incidental, special, consequential, or exemplary damages arising from your use of GoCardless or payment processing functionality, including but not limited to:
- Failed payments, chargebacks, disputes, or refunds
- Damages for loss of profits, data, or business interruption
- The cost of procurement of substitute payment services
- Any amounts exceeding fees paid in the prior 12 months

**Indemnification:** You agree to indemnify and hold harmless Zoom Photography Ltd from any claims, damages, or expenses arising from your use of the GoCardless integration, disputes with your customers regarding payments, or violation of GoCardless terms of service.

See the [End User License Agreement](LICENSE_EULA.txt) for full terms.

For full compliance details, refer to:
- [GoCardless Merchant Terms](https://gocardless.com/legal/merchants/)
- [GoCardless Privacy Policy](https://gocardless.com/privacy/)
- Your regional Direct Debit scheme documentation

---

## Payment Plan Calculator

**Trigger:** Appears automatically when ProSelect's "Add Payment" window is open | **Shortcut:** Ctrl+Shift+P

Calculate payment schedules and auto-enter them into ProSelect. **Done for you** — no typing, no mistakes, no forgetting.

### The Problem This Solves

Manually entering payment plans is tedious, error-prone, and easy to forget:

- Calculating dates and amounts
- Typing each payment line by line
- Remembering to set up Direct Debit afterwards

**With SideKick:** Tell it the balance and schedule, and it enters every payment into ProSelect automatically. Then set up GoCardless DD on the spot so the client doesn't leave until payments are sorted.

### Opening the Calculator

1. In ProSelect, open the **Add Payment** dialog (click "Add Payment" or the payline area)
2. A small **SideKick button** appears on the payment window
3. Click it to open the **Payment Calculator**

### Calculator Layout

The calculator has two sections:

#### Downpayment / Deposit

| Field | Description |
|---|---|
| **Amount** | Deposit amount (leave blank to skip) |
| **Payment Method** | Credit Card, GoCardless DD, or Bank Transfer |
| **Date** | Date for the deposit (defaults to today) |
| **Rounding** | Shows any rounding difference and where it will be applied |

#### Scheduled Payments

| Field | Description |
|---|---|
| **No. Payments** | Number of recurring payments (1–24) |
| **Pay Type** | Payment method (reads from ProSelect's options) |
| **Payment** | Amount per payment (auto-calculated from balance) |
| **Recurring** | Monthly, Weekly, Bi-Weekly, or 4-Weekly |
| **Start Date** | Day of month and starting month for first payment |

### Using the Calculator

1. The **balance** is read automatically from ProSelect
2. Enter an optional **downpayment** amount
3. Set the **number of payments** — the per-payment amount calculates automatically
4. Choose the **recurring period** and **start date**
5. Click **✓ Schedule Payments**

### What Happens Next

SideKick PS enters all the payments into ProSelect automatically (**Done For You**):

- Each payment is entered with the correct date, amount, and type
- A **progress bar** shows "Payment X of Y" during entry
- A **"HANDS OFF"** warning reminds you not to touch the mouse or keyboard
- Audio feedback plays after each payment is entered
- A **success dialog** confirms the number of payments entered

> **⚠ Important:** Do not touch the mouse or keyboard while payments are being entered. SideKick PS is automating the ProSelect UI and any interaction will interfere.

### Multi-Client Albums

When a ProSelect album contains multiple client groups (e.g., a wedding with two families), SideKick automatically targets the correct client:

- The payment balance is matched against each group's order total
- If the balance is **unique** to one group, that group is selected automatically
- If **multiple groups** share the same balance, a dialog lets you pick the correct client by name

### Existing Payment Detection

When writing payments to an album that already has a payment plan:

1. SideKick detects the existing payments before writing
2. A dialog offers three options:
   - **Replace** — delete old payments and write the new plan
   - **Add** — append new payments alongside existing ones
   - **Cancel** — do nothing

When **Replace** is used, the success dialog confirms how many old payments were removed.

### After Entry — Set Up DD Immediately

Once payments are entered, **set up GoCardless DD on the spot**:

1. Click the **GC** button on the toolbar
2. Check if the client has an existing mandate
3. If not, **Send Mandate Request** via email/SMS
4. Create the **Payment Plan** in GoCardless

This ensures you never forget to set up the Direct Debit — it's done before the client leaves.

### Direct Debit Date Rules

When **GoCardless DD** or any Direct Debit method is selected:
- A minimum **4 business day** setup window is enforced
- If the selected day is too soon, it's automatically adjusted to the next valid day

---

## Display — QR Codes & Bank Details

**Trigger:** Slide cycling on the external display or preview panel

SideKick PS can display QR codes, bank transfer details, and custom images as rotating slides during a sale — visible to the client on a secondary display.

### Slide Cycling

Slides cycle automatically or can be navigated manually with **↑** / **↓** keys:

1. **QR Code** — dynamically generated from your configured URL (e.g., payment link, review link)
2. **Bank Transfer Details** — your bank institution, account name, sort code, and account number displayed as large, readable text
3. **Custom Images** — any additional images you add

### Bank Transfer Details

Configure in **Settings → Display → Bank Transfer Details**:

| Field | Description |
|---|---|
| **Bank Institution** | Your bank name (e.g., "Barclays") |
| **Account Name** | The name on the account |
| **Sort Code** | Automatically formatted as ##-##-## on display |
| **Account Number** | Your account number |

Bank details and QR codes scale with the **Size slider** (25–85%) for optimal readability on different screen sizes.

### Lead Connector QR Toggle

In **Settings → GHL**, a checkbox switches the QR code URL between your white-label domain (opens in browser) and `app.leadconnector.app` (opens the Lead Connector mobile app).

---

## Room Capture

**Toolbar button:** 📷 Room Capture

Capture a screenshot of the ProSelect room view and save it as a high-quality JPG.

### How it Works

1. Click the **Room Capture** button
2. SideKick PS captures the central room area (excluding sidebars and toolbars)
3. The image is saved to your **Documents\ProSelect Room Captures** folder
4. The file path is **copied to your clipboard**
5. A dialog appears with four options:
   - **OK** — close the dialog
   - **Open** — open the image in your default viewer
   - **Reveal** — open the folder in Windows Explorer
   - **Email** — send the room capture to the client via GHL

### File Naming

Images are named automatically:
```
AlbumName-room1.jpg
AlbumName-room2.jpg
AlbumName-room3.jpg
```

The number auto-increments so you can capture multiple room views per album.

### Tips

- Great for sharing room design previews with clients
- The capture is DPI-aware — works correctly on high-resolution displays
- Captured at JPEG quality 95 for high fidelity

---

## Room Capture Email

**Trigger:** Click **Email** button after capturing a room view

Email the room capture image directly to the client via GHL.

### How it Works

1. After capturing a room view, click the **Email** button in the dialog
2. A template picker appears showing available GHL email templates
3. The default template (configured in Settings) is pre-selected
4. Select a different template if desired, or use "(none - use default)"
5. Click **Send** to email the image to the client
6. The room image is embedded in the email body

### Setting Up Email Templates

1. Open **Settings → Shortcuts**
2. In the **Room Capture Email** section, click the **🔄** button
3. Your GHL email templates are loaded into the dropdown
4. Select a default template
5. Click **Apply** to save

### Requirements

- The album must contain a valid GHL Client ID
- An email template must exist in your GHL account
- The contact must have an email address in GHL

### Tips

- Create a dedicated "Room View" email template in GHL with your branding
- The room image is appended to the template body automatically
- Great for same-day room previews to clients

---

## Open GHL Contact

**Toolbar button:** 🌐 Open GHL

Quickly open the current client's GHL contact page in your browser.

### How it Works

1. Click the **Open GHL** button
2. SideKick PS extracts the Client ID from:
   - The ProSelect window title (from the album name), or
   - The most recent exported XML file
3. Your default browser opens the GHL contact page

This is useful for quickly checking appointment history, notes, or communication with a client while working in ProSelect.

---

## Quick Print & Email PDF

### Quick Print

**Toolbar button:** 🖨 Quick Print

Auto-print the current order using a pre-configured print template. SideKick matches the template name from Settings and triggers printing automatically.

Configure templates in **Settings → Shortcuts → Quick Print Templates**:

- **Payment Plan** — template to use when the order has a payment plan
- **Standard** — template for standard orders without payment plans

### Email PDF

**Toolbar button:** 📧 Email PDF

Print the invoice to PDF, then email it to the client via a GHL email template — all in one click.

**How it works:**

1. Click the **Email PDF** toolbar button
2. SideKick follows the same Print-to-PDF procedure (print → save → copy)
3. The generated PDF is then automatically emailed to the client using the configured GHL email template

**Setup:**

1. Open **Settings → Print** tab
2. Select a **GHL email template** from the dropdown (click 🔄 to refresh available templates)
3. Enable the **Email PDF** button in **Settings → Toolbar**

---

## SD Card Download

**Toolbar button:** 📥 SD Download *(must be enabled in Settings)*

Download, rename, and archive photos from memory cards.

### Enabling the Feature

1. Open **Settings → File Management**
2. Toggle **Enable SD Card Download** to ON
3. Configure the required paths:
   - **Card Path** — your SD card reader path (e.g., `F:\DCIM`)
   - **Download To** — temporary download folder
   - **Archive Path** — final archive location

### How it Works

1. Insert your SD card
2. Click the **SD Download** button (or wait for auto-detection if enabled)
3. SideKick PS:
   - Detects the DCIM folder on the card
   - Determines the next shoot number from your archive
   - Copies all images to your download folder
   - Renames files with your configured naming pattern
4. Optionally launches your photo editor when complete

### File Naming

Files are renamed using the pattern: `{Prefix}{Year}{ShootNo}{Suffix}`

| Setting | Example | Result |
|---|---|---|
| Prefix: `P`, Year: ON, Suffix: `P` | Shoot 001 in 2026 | `P2026001P` |
| Prefix: `Z`, Year: OFF, Suffix: ` ` | Shoot 042 | `Z042` |

### Multi-Card Support

If a shoot spans multiple memory cards:
1. Download the first card as normal
2. Insert the second card
3. SideKick PS detects it's the same shoot and continues the numbering

### Auto-Detect

When **Auto-Detect SD Cards** is enabled, SideKick PS monitors for new drive insertions and prompts you to download automatically.

---

## Greeting Cards (Cardly)

**Toolbar button:** ✉ Cardly (orange) *(must be enabled in Settings → Cardly)*

Send personalised physical greeting cards to clients using photos from their ProSelect album, powered by the [Cardly](https://cardly.net) printing and mailing service.

### How it Works

1. Open a ProSelect album and import the GHL contact (Get Client)
2. Click the **Cardly** toolbar button
3. A **loading animation** appears immediately while SideKick prepares the card preview
4. The **Card Preview** window opens showing images from the client's order
5. Select a photo, adjust the crop and zoom, and optionally add a sticker overlay
6. Choose a **template orientation** (Landscape or Portrait) using the ⇄ rotate button
7. Edit the personalised message (pre-filled from the GHL contact's Message field)
8. Optionally set a **Receiving Date** for scheduled delivery
9. Click **Send** — the image is processed, uploaded to Cardly, and a physical postcard is printed and mailed to the client's address

A copy of the postcard photo is also saved locally and uploaded to the client's GHL media folder.

### No-Album Mode

You can launch Cardly **without a ProSelect album open**:

- Album-dependent steps (reading images, extracting thumbnails) are skipped
- A **folder picker** appears to select images manually
- Requires a GHL client to be loaded first (for the recipient address)

This is useful for sending cards to past clients where you don't have the album open.

### Test Mode

Test mode lets you verify your Cardly API setup **without sending a card or incurring any cost**.

To enable it, go to **Settings → Cardly** and tick **Test mode (upload artwork; skip order)**.

#### What Test Mode Does

| Step | Normal Mode | Test Mode |
|---|---|---|
| Validate recipient address | ✅ | ✅ |
| Process & upload artwork to Cardly | ✅ | ✅ |
| Place the order (print & mail) | ✅ | ❌ Skipped |
| Save postcard JPG locally | ✅ | ✅ |
| Upload photo to GHL media | ✅ | ✅ |

**Key points:**

- **No card is sent** — the order step is skipped entirely, so no print or postage cost is incurred
- **API connection is validated** — the artwork upload confirms your API key, image processing, and template configuration are all working correctly
- **Uploaded artwork is harmless** — test artwork that isn't attached to an order remains in your Cardly account at no cost and does not need to be manually deleted
- **Cardly's own test API key** does not support artwork uploads, so this test mode is the only way to fully validate your integration end-to-end without placing a real order

Once you're satisfied everything works, uncheck test mode in Settings to start sending real cards.

### Image Sources

The Card Preview window shows images in this priority order:

1. **Order images** — thumbnails from the PSA album filtered by the most recent XML export
2. **Album folder** — all image files in the album's parent folder
3. **Browse** — click the 📂 button to select any image from disc (opens at the album folder by default; selected images are added to the filmstrip)

### Template Orientation Swap

The ⇄ rotate button in the card preview switches between **Landscape** and **Portrait** crop, automatically using matched template pairs. SideKick discovers L↔P template pairs by name matching — e.g., `thankyou-photocard-l` ↔ `thankyou-photocard-p`. The card size display shows "Landscape" or "Portrait" next to the dimensions.

### Receiving Date

Schedule the card to arrive on a specific date instead of sending immediately:

| Option | Description |
|---|---|
| **ASAP** | Send as soon as possible (default) |
| **Birthday** | Client's birthday from GHL (shows "Unknown" if not on file) |
| **Shoot Anniversary** | Session date + 1 year |
| **Custom date fields** | Any date-type GHL custom fields from the contact record |

Click the **🔄 refresh** button next to the dropdown to fetch all date-type custom fields from the GHL contact. Cardly calculates the dispatch date backward from the requested arrival date.

### Sticker Overlays

Add sticker PNG overlays to the card image. The sticker dropdown includes an **"Open Folder..."** option to open the sticker folder in Explorer for quick access to add or remove sticker PNGs. Stickers are included when exporting/importing settings.

### Requirements

- A valid **Cardly API key** (live key, not test key)
- The client must have a **complete postal address** in ProSelect (Client Setup)
- A **Cardly template/media** must be configured in Settings → Cardly
- GHL integration is required for message pre-fill and media upload (optional)

---

## Settings

Open Settings from the toolbar (⚙ button), system tray, or press **Ctrl+Shift+I**.

### General Tab

| Setting | Description |
|---|---|
| **Start on Boot** | Launch SideKick PS when Windows starts |
| **Show Tray Icon** | Show/hide the system tray icon |
| **Enable Sound Effects** | Play audio feedback during operations |
| **Auto-detect ProSelect Version** | Automatically detect PS 2022/2024/2025 |
| **Dark Mode** | Toggle dark/light theme |
| **Default Recurring** | Default payment schedule period |

### GHL Integration Tab

| Setting | Description |
|---|---|
| **Enable GHL Integration** | Master toggle for all GHL features |
| **Autoload client data** | Skip preview dialog when importing clients |
| **API Key** | Your GHL v1 API key |
| **Location ID** | Your GHL Location/Sub-Account ID |
| **Watch Folder** | Where ProSelect exports XML to |
| **Open invoice URL** | Auto-open invoice in browser after sync |
| **Financials only** | Exclude image line items from invoices |
| **Create contact sheet** | Upload a contact sheet JPG with invoices |
| **Contact/Opportunity tags** | Tags to apply during invoice sync |
| **Save local copies** | Save contact sheet copies to a local folder |

### GoCardless Tab

| Setting | Description |
|---|---|
| **Enable GoCardless** | Master toggle for GoCardless features |
| **API Token** | Your GoCardless access token (stored in encrypted credentials.json) |
| **Setup Wizard** | Step-by-step guide for first-time GoCardless setup |
| **Email Template** | GHL email template for mandate request emails |
| **SMS Template** | GHL SMS template for mandate request texts |
| **Plan Naming Format** | Auto-generate plan names using ShootNo, Surname, Order Date, etc. |
| **🔄 Refresh** | Fetch available templates from GHL |
| **Stale Mandates** | Open the Stale Mandates window to find forgotten mandates |
| **Diagnostics** | Run `gc_diagnose.bat` to troubleshoot connectivity issues |

### Hotkeys Tab

| Setting | Description |
|---|---|
| **GHL Client Lookup** | Shortcut to import client (default: Ctrl+Shift+G) |
| **Open PayPlan** | Shortcut to open calculator (default: Ctrl+Shift+P) |
| **Open Settings** | Shortcut to settings (default: Ctrl+Shift+I) |
| **Icon Color** | Toolbar icon colour: White, Black, Yellow, or Custom |

### Toolbar Tab

Configure toolbar button visibility using **clickable icons**. Click an icon to toggle it on/off — the icon background and label update immediately.

| Setting | Description |
|---|---|
| **Button Icons** | Clickable icons for each toolbar button — click to show/hide |
| **Auto-Scale** | Auto-link toolbar size to ProSelect window width |
| **Manual Scale** | Dropdown (50%–100%) for manually sizing the toolbar |
| **Email PDF toggle** | Show/hide the Email PDF button on the toolbar |

### Print Tab

| Setting | Description |
|---|---|
| **Quick Print Templates** | |
| — Payment Plan | Template name to match in Print dialog when order has a payment plan |
| — Standard | Template name for standard orders without payment plans |
| **Email PDF Template** | GHL email template for emailing invoice PDFs to clients |
| **🔄 Refresh** | Fetch available email templates from GHL |

### Display Tab

| Setting | Description |
|---|---|
| **QR Code URL** | URL to encode in the QR code |
| **Lead Connector QR** | Toggle QR URL between white-label domain and `app.leadconnector.app` |
| **Bank Institution** | Bank name for bank transfer display slide |
| **Account Name** | Account holder name |
| **Sort Code** | Sort code (auto-formatted as ##-##-##) |
| **Account Number** | Bank account number |
| **Size** | Slide display size (25–85%) |

### Shortcuts Tab

Configure toolbar buttons and quick print templates.

| Setting | Description |
|---|---|
| **Room Capture Email** | |
| — Template | Select a GHL email template for room capture emails |
| — 🔄 Refresh | Fetch available email templates from GHL |

### File Management Tab

| Setting | Description |
|---|---|
| **Enable SD Card Download** | Show/hide the SD download toolbar button |
| **Card Path** | SD card / DCIM folder path |
| **Download To** | Temporary download folder |
| **Archive Path** | Final archive location |
| **Prefix / Suffix** | File naming pattern |
| **Include Year** | Add year to shoot number |
| **Auto-Rename by Date** | Sort and rename by EXIF timestamp |
| **Editor Path** | File browser app — auto-detecting dropdown finds installed Adobe Bridge, Lightroom Classic, Photoshop, and Capture One. Browse button for manual selection. |
| **Open Editor After Download** | Auto-launch editor when done |
| **Auto-Detect SD Cards** | Monitor for card insertion |

### License Tab

| Setting | Description |
|---|---|
| **License Key** | Enter and activate your license |
| **Validate** | Check license status with server |
| **Deactivate** | Remove license from this computer |
| **Buy License** | Opens the purchase page |

### About Tab

| Setting | Description |
|---|---|
| **Check for Updates** | Check for new versions |
| **Auto-update** | Enable automatic update checks |
| **What's New** | View the changelog |
| **Reinstall** | Re-download and install the latest version |
| **Auto-send activity logs** | Send diagnostic logs after each sync |
| **Enable debug logging** | Detailed logging for troubleshooting (auto-disables after 24hrs) |
| **Send Logs** | Manually upload logs for support |

### Import / Export Settings

- **Export** — saves all your settings to an encrypted `.skp` file (includes toolbar button visibility, Cardly sticker overlays, and GoCardless settings)
- **Import** — loads settings from a `.skp` file (useful when moving to a new computer)

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| **Ctrl+Shift+G** | GHL Client Lookup |
| **Ctrl+Shift+P** | Open Payment Calculator |
| **Ctrl+Shift+I** | Open Settings |
| **Ctrl+Shift+R** | Reload script *(developer mode only)* |

All shortcuts can be changed in **Settings → Hotkeys**. Click "Set" next to any shortcut, then press your desired key combination.

When ProSelect or SideKick is not the active window, hotkeys are **passed through** to the target application instead of being silently consumed.

---

## System Tray

Right-click the SideKick PS icon in the system tray for:

| Menu Item | Action |
|---|---|
| **PayPlan** | Show the Payment Calculator button |
| **GHL Client Lookup** | Import client from GHL |
| **Settings** | Open Settings |
| **About** | Open the About tab |
| **Reload** | Restart SideKick PS |
| **Exit** | Close SideKick PS |

Double-click the tray icon to open it.

---

## Licensing & Activation

### Free Trial

SideKick PS includes a **14-day free trial** with full functionality. No credit card required.

### Purchasing a License

1. Click **Buy License** in Settings → License, or visit:
   [https://zoomphoto.lemonsqueezy.com](https://zoomphoto.lemonsqueezy.com/checkout/buy/077d6b76-ca2a-42df-a653-86f7aa186895)
2. Complete the purchase
3. You'll receive a license key by email

### Activating Your License

1. Open **Settings → License**
2. Paste your license key
3. Click **Activate**
4. The license is bound to your GHL Location ID

### License Details

- One license per GHL Location (sub-account)
- License can be deactivated and moved to a different location
- Subscription-based — remains active while your subscription is current

---

## Troubleshooting

### Toolbar doesn't appear

- Make sure ProSelect is open and in the foreground
- Check that SideKick PS is running (look for the tray icon)
- Try reloading: right-click tray → Reload

### Client import doesn't find the contact

- Open the client's GHL contact page in **Chrome** before clicking Get Client
- Make sure the URL contains `/contacts/detail/` 
- Check your **GHL API Key** and **Location ID** in Settings

### Invoice sync fails

- Verify the **Watch Folder** in Settings points to a valid folder
- Check that the ProSelect order has items
- Make sure the album has a Client ID (import the client first)
- Check your internet connection

### Payment calculator doesn't appear

- The calculator only shows when ProSelect's **Add Payment** window is open
- Try the keyboard shortcut: **Ctrl+Shift+P**

### "Permission Denied" errors

- This usually means SideKick PS is installed in a protected folder
- The app stores data in `%APPDATA%\SideKick_PS\` to avoid permission issues
- If the problem persists, try running as Administrator

### Invoice appears but has no items

- Make sure **"Financials only"** is turned OFF if you want line items
- Check that items are checked in ProSelect's Export Orders dialog

### Diagnostic Logs

If you're experiencing issues:

1. Open **Settings → About**
2. Toggle **Enable debug logging** ON
3. Reproduce the issue
4. Click **Send Logs**
5. Contact support with the log reference

Debug logging automatically disables after 24 hours.

---

## Support

**Email:** guy@zoom-photo.co.uk
**GitHub:** [github.com/GuyMayer/SideKick_PS](https://github.com/GuyMayer/SideKick_PS)

---

*SideKick PS v3.0.3 — Built for photographers, by a photographer.*
