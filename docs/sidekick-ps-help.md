# SideKick PS — Help Guide

> Paste this entire file into ChatGPT, Claude, or any AI chat, then ask your
> question. The AI will answer based on the SideKick PS documentation below.

_Last updated: 2026-05-30_

---

## How to install and activate SideKick PS

Gets SideKick PS installed on your Windows computer and links it to your license so all features are unlocked.

### Before you start

- You need the SideKick PS installer file (from your purchase confirmation email or the SideKick website).
- ProSelect must be installed on the same machine.

### Steps

1. Double-click the SideKick PS installer and follow the on-screen prompts to complete installation.
2. SideKick PS starts automatically and its icon appears in the Windows taskbar tray.
3. Open **Settings** by clicking the gear icon on the toolbar, or by pressing **Ctrl+Shift+I**.
4. Go to the **About** tab, click **Enter License Key**, paste the key from your purchase email, and click **Activate**.
5. SideKick PS confirms activation and unlocks all features.

### What you should see

The About tab shows your name and license status as **Active**. The floating toolbar is fully functional alongside ProSelect.

### Something went wrong?

- **"License invalid"** — Check that you copied the full key with no extra spaces. Keys are case-sensitive.
- **"Could not activate"** — SideKick PS needs internet access to validate your license. Connect to the internet and try again.
- **Trial mode still showing after activation** — Right-click the SideKick PS tray icon and select **Reload**.

---

## How to connect SideKick PS to GoHighLevel

Links SideKick PS to your GoHighLevel account so it can look up clients, sync invoices, and push payment plans.

### Before you start

- You need a GoHighLevel account with a sub-account (Location) set up for your studio.
- You need a **Private Integration Token** (API key) from your GHL sub-account — found in **Settings → Integrations → Private Integrations** inside GHL.
- You need your GHL **Location ID** — found in GHL under **Settings → Business Profile**.

### Steps

1. On first run, SideKick PS displays a setup wizard automatically. Click **Set up GoHighLevel connection**.
2. Paste your **API Key** into the first field.
3. Paste your **Location ID** into the second field.
4. Click **Save & Test** — SideKick PS verifies the connection.
5. If the test succeeds, click **Done**.

_To update your credentials later: open **Settings** (gear icon or **Ctrl+Shift+I**), go to the **GHL** tab, and update the fields there._

### What you should see

The GHL tab in Settings shows a green confirmation. The toolbar's **Get Client**, **Sync Invoice**, and **Open GHL Contact** buttons become fully active.

### Something went wrong?

- **"Connection failed"** — Check that your API key is a V2 Private Integration Token, not an older API key. Generate a new one in GHL under **Settings → Integrations → Private Integrations**.
- **"Location ID not found"** — Make sure you are using the Location ID, not the Agency ID. These are different values found in different parts of GHL settings.

---

## How to customise and reposition the toolbar

Changes the toolbar's size, icon colour, and screen position so it sits naturally alongside your ProSelect window.

### Before you start

- SideKick PS must be running with the toolbar visible.

### Steps

1. Open **Settings** (gear icon on the toolbar, or **Ctrl+Shift+I**) and go to the **Appearance** tab.
2. Under **Icon Colour**, choose **White**, **Black**, **Yellow**, or click **Custom** to pick any colour. The toolbar updates live as you choose.
3. To resize the toolbar, go to the **Toolbar** tab and choose a scale percentage from the dropdown (50% to 100%).
4. To reposition the toolbar, close Settings and **Ctrl+Click** the dotted grab handle (⣿) on the left edge of the toolbar, then drag it where you want it.
5. To return the toolbar to its default position, open **Settings → Toolbar** and click **Reset Position**.

### What you should see

The toolbar moves to your chosen position and remembers it between sessions. Icon colours and scale update immediately.

### Something went wrong?

- **Toolbar has disappeared** — Right-click the SideKick PS tray icon and select **Reload**. The toolbar reappears at its last saved position.
- **Icons are invisible against the background** — Enable **Auto Background Detection** in **Settings → Appearance** so SideKick PS can automatically match the toolbar background to ProSelect.

---

## How to look up a client from GoHighLevel

Pulls the current client's details from GoHighLevel into SideKick PS so their name, email, and contact ID are available for invoice sync, payment plans, and direct messaging.

### Before you start

- SideKick PS must be connected to GoHighLevel.
- The client must have a contact record in GoHighLevel.
- The correct album must be open in ProSelect.

### Steps

1. In ProSelect, open the album for the client you are working with.
2. Click the **Get Client** button on the SideKick toolbar (person+ icon), or press **Ctrl+Shift+G**.
3. SideKick PS searches GoHighLevel for the matching client.
4. If a single match is found, a confirmation prompt shows the client's name — click **Yes** to load them.
5. If multiple matches appear, select the correct contact from the list and click **Confirm**.

### What you should see

The client's name and email address appear in the SideKick PS status area. The **Sync Invoice**, **Open GHL Contact**, and **Payment Calculator** buttons are now linked to this client.

### Something went wrong?

- **"No client found"** — The album or shoot name may not match the contact's record in GHL closely enough. Open GHL in your browser, find the correct contact, then use **Use Other** in the Get Client dialog to select them manually.
- **Wrong client loaded** — Click **Get Client** again to redo the lookup, or use **Use Other** to pick a different contact.

---

## How to sync a ProSelect invoice to GoHighLevel

Exports the current client's ProSelect order to GoHighLevel as an invoice, creating or updating the matching invoice and opportunity record automatically.

### Before you start

- A client must be loaded in SideKick PS.
- The order must be finalised in ProSelect with the correct items and amounts.

### Steps

1. In ProSelect, confirm the client's order is complete and the correct album is open.
2. Click the **Sync Invoice** button (document icon, green) on the SideKick toolbar.
3. SideKick PS exports the order data and uploads it to GoHighLevel.
4. A progress indicator appears while the sync runs.
5. When complete, a summary confirms the invoice total and shows a link to the GHL record.
6. Click the link to open the invoice in GoHighLevel, or click **Close** to return to ProSelect.

### What you should see

A new invoice appears in the client's GHL contact record matching the ProSelect order. An opportunity is also created or updated in the pipeline.

### Something went wrong?

- **Duplicate invoice warning** — SideKick PS has detected a previous sync for the same order. Review the existing GHL invoice before proceeding to avoid creating a duplicate charge.
- **Sync failed — check connection** — Verify your GHL API credentials in **Settings → GHL** and retry.
- **Line items are missing** — Make sure the ProSelect order has been saved and all items confirmed before syncing.

---

## How to open a client's GoHighLevel contact record

Opens the current client's GoHighLevel contact page directly in your browser — useful for checking notes, sending messages, or reviewing history mid-session.

### Before you start

- A client must be loaded in SideKick PS.

### Steps

1. Click the **Open GHL Contact** button (ID card icon, teal) on the SideKick toolbar.
2. Your default browser opens directly to the client's contact record in GoHighLevel.

### What you should see

The client's full GHL contact profile opens, showing their details, activity history, and linked invoices.

### Something went wrong?

- **Browser opens to the GHL dashboard instead of the contact** — The client may not have been loaded yet. Run **Get Client** (Ctrl+Shift+G) first, then try again.
- **"Contact ID not set"** — No client is currently loaded. Use **Get Client** to load the correct contact.

---

## How to open the GHL Production opportunity

Jumps directly to the production pipeline record for the current shoot in GoHighLevel — the opportunity that is created when an invoice is synced for production tracking.

### Before you start

- An invoice must have been synced to GHL for the current shoot.
- The **Production** button (factory icon, navy) must be visible on the toolbar — it only appears once a production opportunity has been linked to the open album.

### Steps

1. Click the **Production** button on the SideKick toolbar (factory/building icon, navy).
2. Your browser opens directly to the production opportunity in GoHighLevel.

### What you should see

The GHL opportunity record for this shoot opens in your browser, showing the pipeline stage, assigned tasks, and any linked invoices.

### Something went wrong?

- **Production button is not visible** — The current album has not had an invoice synced to GHL yet, or the production link has not been saved. Use the **Sync Invoice** button first.

---

## How to build a payment plan with the Payment Calculator

Calculates and schedules all payment lines for a client's order directly into ProSelect in one step — splitting the balance into a deposit and regular payments so you never have to enter them manually.

### Before you start

- ProSelect's **Add Payment** dialog must be open for the current order.
- SideKick PS must be running.

### Steps

1. In ProSelect, open the **Add Payment** dialog. A **📅 PayPlan** button appears automatically in the dialog.
2. Click **📅 PayPlan** — or press **Ctrl+Shift+P** from anywhere — to open the Payment Calculator.
3. Confirm the **Balance Due** shown at the top is correct. If not, close the calculator, correct the order in ProSelect, then reopen it.
4. In the **Downpayment / Deposit** section, enter the deposit amount and select the payment method. The date defaults to today — change it if needed.
5. In the **Scheduled Payments** section, set **No. Payments**, choose a **Pay Type**, and select a **Recurring** frequency (Monthly, Weekly, Bi-Weekly, or 4-Weekly).
6. Ask the client which day they prefer for payments, then select it under **Start Date** along with the start month.
7. Click **✓ Schedule Payments** — SideKick PS enters all payment lines into ProSelect automatically.

### What you should see

Each payment line appears in the ProSelect Add Payment list with the correct amount, date, and payment type — ready to save.

### Something went wrong?

- **Balance Due shows the wrong amount** — Close the calculator, correct the order total in ProSelect, then reopen via **📅 PayPlan**.
- **"GoCardless DD" start date was adjusted automatically** — Direct Debit mandates require a minimum setup period. SideKick PS has moved the start date to the earliest valid date.

---

## How to set the rounding adjustment

Controls where the rounding difference goes when a balance cannot be split into perfectly equal payments — either added to the deposit or to the first scheduled payment.

### Before you start

- The Payment Calculator must be open.

### Steps

1. Open the Payment Calculator (**📅 PayPlan** button in the Add Payment dialog, or **Ctrl+Shift+P**).
2. In the **Downpayment / Deposit** section, find the **Add rounding to:** radio buttons.
3. Select **Downpayment** to add the rounding difference to the deposit amount, or **1st Payment** to add it to the first scheduled payment.

_Example: a £208.33 balance split 3 ways gives £69.44 × 3 = £208.32, leaving a 1p rounding difference. This setting controls where that 1p goes._

### What you should see

A rounding info line below the deposit amount updates to show the adjustment amount (e.g. "Rounding of £0.01 added to deposit"). Your preference is saved for future sessions.

### Something went wrong?

- **No rounding notice appears** — The balance divides exactly, so no adjustment is needed and the notice will not show.

---

## How to set up a payment plan and Direct Debit mandate during a sales session

Guides you through taking a payment plan deposit and setting up a GoCardless Direct Debit mandate — all while the client authorises it on their own phone. By the time you finish entering the payment schedule, the mandate is ready and SideKick connects everything automatically.

### Before you start

- SideKick PS must be running with the floating toolbar visible.
- GoCardless must be enabled and configured in **Settings → GoCardless**.
- Two QR codes must be set up in **Settings → Display**:
  - **Slide 1** — your studio Wi-Fi credentials
  - **Slide 2** — your GoCardless mandate invitation link
- The client's contact record must already be loaded in SideKick PS (use **Get Client** first if not).

### Steps

1. Click the **QR Code** button on the SideKick toolbar — the display appears full-screen on your presentation monitor showing Slide 1 (Wi-Fi). Use the **↑ / ↓ arrow keys** to move between the three available slides. Use the **← / → arrow keys** to move the display between monitors if you have more than one screen.

2. Ask the client to scan the Wi-Fi QR code with their phone and join your studio network. Confirm they are connected before continuing.

3. Press **↓** to move to Slide 2 (GoCardless mandate invitation). The client scans it and begins filling in their bank details on their phone.

4. While the client completes the mandate form on their phone, open **Add Payment** in ProSelect and click **📅 PayPlan** (or press **Ctrl+Shift+P**) to open the Payment Calculator.

5. Confirm the **Balance Due** is correct. Enter a downpayment amount and payment method if applicable.

6. Set **No. Payments**, select **GoCardless DD** as the Pay Type, choose a **Recurring** frequency (Monthly or 4-Weekly), then ask the client which day of the month works best for them and select it under **Start Date**.

7. Click **✓ Schedule Payments** — SideKick PS enters all payment lines into ProSelect automatically.

8. Complete the order in ProSelect and come out of the Review Order section. SideKick PS displays a prompt: _"The pay plan has been documented. Now press the GoCardless button on the toolbar to set it up."_

9. Press **Escape** or click the **QR Code** button again to dismiss the display, then click the **GoCardless** button on the toolbar. SideKick PS automatically locates the client's mandate using their name and email address and links the payment schedule to it — no manual lookup required.

### What you should see

All payment lines appear in ProSelect's payment list with the correct amounts and dates. The GoCardless dashboard shows the mandate as active with the schedule attached.

### Something went wrong?

- **Mandate not found by email** — SideKick PS will automatically retry using the client's name. If it still cannot match, a **Use Other** option appears — use this if a family member or different person is paying under a different name or email address.
- **Client cannot scan the QR code** — Increase the display size in **Settings → Display** or use the arrow keys to move the display to the correct monitor.
- **GoCardless button is missing from the toolbar** — GoCardless must be enabled in **Settings → GoCardless** before the button appears.

---

## How to review an order in ProSelect

Opens the Review Order screen in ProSelect for the current album in one click — without navigating through ProSelect's menus.

### Before you start

- ProSelect must be open with an album loaded.

### Steps

1. Click the **Review Order** button (receipt icon) on the SideKick toolbar.
2. ProSelect navigates to the **Orders → Review Order** screen for the current album.

### What you should see

The Review Order screen opens showing the client's current order with all items, quantities, and prices.

### Something went wrong?

- **Nothing happens** — Ensure ProSelect is open and an album is active. SideKick PS must be able to detect the ProSelect window to send the navigation command.

---

## How to refresh or reload the open album

Forces ProSelect to re-read the current album's image files — useful after adding, moving, or renaming images outside of ProSelect.

### Before you start

- ProSelect must be open with an album loaded.

### Steps

1. Click the **Refresh** button (circular arrow icon, navy) on the SideKick toolbar.
2. ProSelect reloads the current album's contents from disk.

### What you should see

The album view updates to reflect any newly added or changed images.

### Something went wrong?

- **Images still missing after refresh** — Confirm the image files are in the correct folder for the open album. If you have moved files to a different location, update the album path inside ProSelect directly.

---

## How to toggle image sort mode

Switches the current album between alphabetical (filename) order and randomised display order — useful for controlling the presentation sequence during a sales session.

### Before you start

- ProSelect must be open with an album loaded.

### Steps

1. The **Sort** button on the SideKick toolbar shows **🔤** when the album is currently in random order (the default when an album first loads).
2. Click **🔤** to sort images alphabetically by filename.
3. Click the button again to return to random order.

### What you should see

The album images reorder immediately in ProSelect. The toolbar button icon changes to reflect the current mode.

### Something went wrong?

- **Sort does not appear to change** — The album may have only one image, or ProSelect may need a manual refresh. Click the **Refresh** button after toggling sort.

---

## How to open the shoot folder

Opens the current shoot's archive folder in your preferred file browser — Windows Explorer, Adobe Bridge, or Lightroom — so you can access the raw image files directly without navigating there manually.

### Before you start

- The shoot archive path must be configured in **Settings → File Management → Archive Path**.
- To change which application opens the folder, go to **Settings → File Management → File Browser**.

### Steps

1. Click the **Open Folder** button on the SideKick toolbar. The icon matches your configured file browser (Explorer, Bridge, or Lightroom).
2. The shoot folder opens in your chosen application.

### What you should see

Your configured file browser opens showing the contents of the current shoot's archive folder.

### Something went wrong?

- **"Folder not found"** — The shoot archive path may not be set, or the folder does not exist yet. Check **Settings → File Management → Archive Path**.
- **Wrong folder opens** — Confirm the archive path in **Settings → File Management** points to the correct root folder for your shoot archives.

---

## How to quick print from the toolbar

Sends the current ProSelect page to your selected printer in one click — without opening the ProSelect print dialog.

### Before you start

- ProSelect must be open and displaying the page you want to print.
- Your preferred printer must be set in **Settings → Toolbar → Quick Print Printer** (leave blank to use the Windows default printer).

### Steps

1. In ProSelect, navigate to the page or layout you want to print.
2. Click the **Print** button (printer icon, dark grey) on the SideKick toolbar.
3. ProSelect sends the current page to the selected printer immediately — no dialog appears.

### What you should see

The page prints without any dialog box appearing. The printer receives the job within a few seconds.

### Something went wrong?

- **Wrong printer used** — Set your preferred printer in **Settings → Toolbar → Quick Print Printer**.
- **Nothing prints** — Confirm that ProSelect has a layout open and that the printer is online and connected.

---

## How to print a ProSelect page to PDF

Saves the current ProSelect page as a PDF file automatically, using a pre-calibrated button location — no print dialog interaction required.

### Before you start

- **Print to PDF** must be enabled in **Settings → Toolbar → Enable Print to PDF**.
- The PDF print button location must be calibrated once (see Step 1 below).
- Optionally, set a **PDF Output Folder** in **Settings → Toolbar** to send a copy of every PDF to a specific folder automatically.

### Steps

1. **First-time setup only:** Open **Settings → Toolbar**, enable **Print to PDF**, then click **Calibrate Print Button** and follow the on-screen prompt to click the print button inside ProSelect's print dialog. Calibration only needs to be done once per machine.
2. In ProSelect, navigate to the page or layout you want to save.
3. Click the **PDF** button (document icon, maroon) on the SideKick toolbar.
4. SideKick PS triggers ProSelect's print function and automatically clicks through to save the file.

### What you should see

A PDF is saved to your configured output folder. If no folder is set, the PDF saves to ProSelect's default output location.

### Something went wrong?

- **Print dialog appears but nothing is clicked automatically** — Calibration may be out of date if you have resized or moved the ProSelect window significantly. Recalibrate via **Settings → Toolbar → Calibrate Print Button**.
- **PDF saves to the wrong location** — Set the correct path in **Settings → Toolbar → PDF Output Folder**.

---

## How to email a PDF to a client via GoHighLevel

Prints the current ProSelect page to PDF and sends it to the loaded client via a GoHighLevel email template — all in one action from the toolbar.

### Before you start

- Print to PDF must be enabled and calibrated.
- The **Email PDF** button must be enabled in **Settings → Toolbar → Show Email PDF Button**.
- A GHL email template for PDF delivery must be selected in **Settings → GHL → PDF Email Template**.
- A client must be loaded in SideKick PS.

### Steps

1. In ProSelect, navigate to the page you want to email.
2. Click the **Email PDF** button (envelope icon) on the SideKick toolbar.
3. SideKick PS prints the page to PDF, then sends it to the loaded client's email address using the configured GHL template.
4. A confirmation message appears when the email has been sent successfully.

### What you should see

The client receives an email via GoHighLevel containing the PDF. A record of the sent email appears in the client's GHL activity feed.

### Something went wrong?

- **Email PDF button is not on the toolbar** — Enable it in **Settings → Toolbar → Show Email PDF Button**.
- **"No client loaded"** — Use **Get Client** (Ctrl+Shift+G) to load the client first, then try again.
- **Wrong email template used** — Update the selected template in **Settings → GHL → PDF Email Template**.

---

## How to display a QR code or bank transfer details on screen

Shows a full-screen display on your presentation monitor — a QR code for Wi-Fi, a payment mandate link, bank transfer details, or any content you configure — so clients can scan or read it on their own device without you showing them your screen.

### Before you start

- Display content must be configured in **Settings → Display**:
  - **Slides 1, 2, 3** — enter a URL or text to generate a QR code for each slide, or leave a slide blank.
  - Bank transfer details (sort code, account number) can also be configured here as a text slide.
- Your presentation monitor must be connected and detected by Windows.

### Steps

1. Click the **QR Code** button (grid icon, teal) on the SideKick toolbar to open the full-screen display on your presentation monitor.
2. Use the **↑ / ↓ arrow keys** to cycle between Slide 1, Slide 2, and Slide 3.
3. Use the **← / → arrow keys** to move the display to a different monitor if needed.
4. When finished, press **Escape** or click the **QR Code** button again to close the display.

### What you should see

A full-screen display appears on your chosen monitor showing the QR code or content for the selected slide.

### Something went wrong?

- **QR code is hard to scan** — Increase the display size in **Settings → Display → Display Size**.
- **Display appears on the wrong monitor** — Use the **← / →** arrow keys while the display is open to move it to the correct screen. You can also set a default monitor in **Settings → Display → Monitor**.
- **Slide appears blank** — No content has been configured for that slide. Add a URL or text in **Settings → Display**.

---

## How to send a Cardly postcard to a client

Sends a personalised printed postcard to the client via the Cardly service — directly from the SideKick toolbar, using the loaded client's name and address.

### Before you start

- A Cardly API key must be entered in **Settings → Cardly**.
- A card design must be selected in **Settings → Cardly → Card Design**.
- A client must be loaded in SideKick PS.
- The client's postal address must be present in their GoHighLevel contact record.

### Steps

1. Click the **Cardly** button on the SideKick toolbar.
2. A preview of the postcard appears showing the design and the client's name and address.
3. Review the preview — if the details are correct, click **Send**.
4. Cardly confirms the order and submits the postcard for printing and postal delivery.

### What you should see

A confirmation appears showing the postcard has been submitted to Cardly. Delivery typically takes several working days.

### Something went wrong?

- **Cardly button is missing from the toolbar** — Check that a Cardly API key is entered in **Settings → Cardly** and the button is enabled.
- **Client address is missing from the preview** — The loaded client does not have a postal address in their GHL contact record. Add the address in GHL and reload the client using **Get Client**, then try again.

---

## How to download images from an SD card

Copies image files from a camera SD card to your studio's shoot archive folder, assigns a shoot number, and optionally opens the folder in your file browser when finished.

### Before you start

- Configure the following paths in **Settings → File Management** before your first download:
  - **SD Card Path** — the drive letter and DCIM folder for your camera's SD card (e.g. F:\DCIM)
  - **Download Path** — a temporary working folder for copied files
  - **Archive Path** — the final destination for finished shoots
- Insert the SD card into your computer's card reader.

### Steps

1. Click the **Download** button (arrow-down icon, orange) on the SideKick toolbar.
2. A dialog appears confirming the SD card path detected. Click **Continue**.
3. Enter or confirm the shoot number for this session. SideKick PS suggests the next available number automatically.
4. SideKick PS copies all image folders from the card to your archive.
5. When the copy is complete, your configured file browser opens automatically (if enabled in Settings).

### What you should see

All images from the SD card appear in a new numbered folder in your shoot archive. The file browser opens to that folder.

### Something went wrong?

- **"SD card not found"** — Check the card is inserted and that the drive letter in **Settings → File Management → SD Card Path** matches the card's current drive letter in Windows Explorer.
- **Download stops part-way through** — Check there is sufficient free space on your archive drive. SideKick PS will report the error if space runs out.
- **Shoot number already exists** — SideKick PS will warn you before overwriting. Change the shoot number in the confirmation dialog.

---

## How to capture a room photo

Takes a photo of the room or wall arrangement using a connected camera or webcam and saves it linked to the current shoot — useful as a reference when presenting room views to clients in ProSelect.

### Before you start

- A camera or webcam must be connected and recognised by Windows.
- Optionally, set a save folder in **Settings → File Management → Room Capture Folder** (default: Documents\ProSelect Room Captures).

### Steps

1. Arrange the room or wall display you want to photograph.
2. Click the **Camera** button (maroon) on the SideKick toolbar.
3. SideKick PS triggers the camera and saves the photo to the room capture folder.
4. The button briefly changes colour to confirm the capture was successful, then returns to its normal state.

### What you should see

A photo file is saved in your room capture folder, named with the current date and time.

### Something went wrong?

- **Camera button shows in yellow** — The camera is in calibration mode. Click it once to complete calibration, then click again to capture.
- **No photo saved** — Confirm the camera is connected and not in use by another application. Check the save folder path in **Settings → File Management → Room Capture Folder**.

---

## How to change keyboard shortcuts

Reassigns the three global hotkeys used to trigger SideKick PS features from anywhere on your computer — without switching to the toolbar first.

### Before you start

- SideKick PS must be running.

### Steps

1. Open **Settings** (gear icon on the toolbar, or press **Ctrl+Shift+I**) and go to the **General** tab.
2. Find the **Keyboard Shortcuts** section. The three defaults are:
   - **GHL Client Lookup** — default: **Ctrl+Shift+G**
   - **Payment Calculator** — default: **Ctrl+Shift+P**
   - **Settings** — default: **Ctrl+Shift+I**
3. Click the field next to the shortcut you want to change and press your new key combination.
4. Click **Save** to apply the change.

### What you should see

The new shortcuts take effect immediately. Pressing them from any active window triggers the corresponding SideKick PS action.

### Something went wrong?

- **New shortcut does not work** — Another application may already be using that combination. Choose a different combination, or check for conflicts in Windows settings.
- **Shortcut reverts after restart** — Make sure you clicked **Save** before closing Settings.

---

## How to check for updates and view What's New

Keeps SideKick PS up to date and lets you review the latest changes and improvements added to the software.

### Before you start

- SideKick PS must be running with an internet connection available.

### Steps

1. SideKick PS checks for updates automatically every time it starts. If a new version is available, a notification appears asking if you want to update now or later.
2. To check manually: open **Settings** (gear icon or **Ctrl+Shift+I**) and go to the **About** tab.
3. Click **Check for Updates**.
4. To view the version history and release notes, click **What's New** on the About tab.
5. If an update is available and you click **Update Now**, SideKick PS downloads and installs the update, then restarts automatically.

### What you should see

The About tab shows the current version number and build date. After updating, the new version number is confirmed when SideKick PS restarts.

### Something went wrong?

- **"No updates available" but you expected one** — Confirm your internet connection is active and try again. If the issue persists, download the latest installer manually using the link in your original purchase confirmation email.
- **Update failed to install** — Try running SideKick PS as administrator (right-click the .exe → **Run as administrator**) and attempt the update again.
