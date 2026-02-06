# SideKick PS — User Manual

**Version 2.4.70** | February 2026 | © Zoom Photography

---

## Contents

1. [What is SideKick PS?](#what-is-sidekick-ps)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [The Toolbar](#the-toolbar)
5. [GHL Client Lookup](#ghl-client-lookup)
6. [Invoice Sync](#invoice-sync)
7. [Payment Plan Calculator](#payment-plan-calculator)
8. [Room Capture](#room-capture)
9. [Open GHL Contact](#open-ghl-contact)
10. [SD Card Download](#sd-card-download)
11. [Settings](#settings)
12. [Keyboard Shortcuts](#keyboard-shortcuts)
13. [System Tray](#system-tray)
14. [Licensing & Activation](#licensing--activation)
15. [Troubleshooting](#troubleshooting)
16. [Support](#support)

---

## What is SideKick PS?

SideKick PS is a Windows companion app for **ProSelect** photography software. It adds a floating toolbar to ProSelect with one-click access to:

- **GoHighLevel (GHL) CRM integration** — import client details, sync invoices, upload contact sheets
- **Payment plan calculator** — generate payment schedules and auto-enter them into ProSelect
- **Room capture** — screenshot the ProSelect room view and save as JPG
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

When ProSelect is open, a floating toolbar appears docked to the ProSelect title bar. It contains up to 6 buttons:

| Button | Icon | What it Does |
|---|---|---|
| **Get Client** | 👤 (blue) | Import client details from GHL into ProSelect |
| **Sync Invoice** | 📋 (green) | Export the current order and sync it to GHL as an invoice |
| **Open GHL** | 🌐 (teal) | Open this client's GHL contact page in your browser |
| **Room Capture** | 📷 (maroon) | Screenshot the ProSelect room view |
| **SD Download** | 📥 (orange) | Download photos from SD card *(only shown if enabled)* |
| **Settings** | ⚙ (purple) | Open SideKick PS settings |

### Toolbar Behaviour

- The toolbar **auto-hides** when ProSelect loses focus
- It **stays hidden** when ProSelect dialogs are open (Client Setup, Print, etc.)
- It **reappears** when you return to the main ProSelect window
- Icon colours can be changed in **Settings → Hotkeys → Icon Color**

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

**Toolbar button:** 📋 Sync Invoice

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
| **Payments** | Past payments recorded as transactions |
| **Future Payments** | Created as a recurring payment schedule in GHL |
| **Contact Sheet** | JPG thumbnail sheet uploaded to GHL Media (if enabled) |
| **Client Details** | Name, email, phone, address updated on GHL contact |
| **Business Details** | Your business name, address, logo, phone pulled from GHL |
| **Tags** | Contact and opportunity tags applied automatically (if configured) |

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

## Payment Plan Calculator

**Trigger:** Appears automatically when ProSelect's "Add Payment" window is open | **Shortcut:** Ctrl+Shift+P

Calculate payment schedules and auto-enter them into ProSelect.

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

SideKick PS enters all the payments into ProSelect automatically:

- Each payment is entered with the correct date, amount, and type
- A **progress bar** shows "Payment X of Y" during entry
- A **"HANDS OFF"** warning reminds you not to touch the mouse or keyboard
- Audio feedback plays after each payment is entered

> **⚠ Important:** Do not touch the mouse or keyboard while payments are being entered. SideKick PS is automating the ProSelect UI and any interaction will interfere.

### Direct Debit Date Rules

When **GoCardless DD** or any Direct Debit method is selected:
- A minimum **4 business day** setup window is enforced
- If the selected day is too soon, it's automatically adjusted to the next valid day

---

## Room Capture

**Toolbar button:** 📷 Room Capture

Capture a screenshot of the ProSelect room view and save it as a high-quality JPG.

### How it Works

1. Click the **Room Capture** button
2. SideKick PS captures the central room area (excluding sidebars and toolbars)
3. The image is saved to your **Documents\ProSelect Room Captures** folder
4. The file path is **copied to your clipboard**
5. A dialog appears with three options:
   - **OK** — close the dialog
   - **Open** — open the image in your default viewer
   - **Reveal** — open the folder in Windows Explorer

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

## Settings

Open Settings from the toolbar (⚙ button), system tray, or press **Ctrl+Shift+W**.

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

### Hotkeys Tab

| Setting | Description |
|---|---|
| **GHL Client Lookup** | Shortcut to import client (default: Ctrl+Shift+G) |
| **Open PayPlan** | Shortcut to open calculator (default: Ctrl+Shift+P) |
| **Open Settings** | Shortcut to settings (default: Ctrl+Shift+W) |
| **Icon Color** | Toolbar icon colour: White, Black, Yellow, or Custom |

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
| **Editor Path** | Photo editor to launch after download |
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

- **Export** — saves all your settings to an encrypted `.skp` file
- **Import** — loads settings from a `.skp` file (useful when moving to a new computer)

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| **Ctrl+Shift+G** | GHL Client Lookup |
| **Ctrl+Shift+P** | Open Payment Calculator |
| **Ctrl+Shift+W** | Open Settings |
| **Ctrl+Shift+R** | Reload script *(developer mode only)* |

All shortcuts can be changed in **Settings → Hotkeys**. Click "Set" next to any shortcut, then press your desired key combination.

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
   [https://zoomphoto.lemonsqueezy.com](https://zoomphoto.lemonsqueezy.com/buy/234060d4-063d-4e6f-b91b-744c254c0e7c)
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

*SideKick PS v2.4.70 — Built for photographers, by a photographer.*
