---
title: "After They Leave — Invoice, PDF, Postcard"
category: delivery
source_files: SideKick_PS.ahk
last_sync: 2026-05-30
---

## Why this matters

The client has just left. The order is in ProSelect. Now what? You could
spend 20 minutes exporting an invoice, typing it into GoHighLevel, printing
a PDF, composing an email, and addressing a thank-you card. Or you could
click four buttons and go home. This chapter covers everything that happens
after the client walks out the door.

## Sync the invoice to GoHighLevel

1. Make sure the order is finalised in ProSelect.
2. Click the **Sync Invoice** button (green document icon) on the toolbar.
3. SideKick PS exports the order data and creates the invoice in GoHighLevel.
   A progress bar appears while it works.
4. When complete, a summary confirms the invoice total and shows a link.

If an invoice already exists for this shoot, SideKick PS asks you to choose:

- **Replace** — delete the old invoice and create a new one. Use this if the
  client changed their mind and the order is different.
- **Update** — keep the existing invoice and update the line items. Use this
  if payments have already been made — it preserves them.
- **New** — create a second invoice alongside the existing one.

## Print a PDF of the order

1. Navigate to the page you want to save in ProSelect.
2. Click the **PDF** button (red document icon) on the toolbar.
3. SideKick PS prints the page to PDF automatically — no print dialog, no
   filename typing.
4. The PDF is saved to your album folder and, if configured, a secondary
   output folder.

The first time you use this, you need to calibrate: open **Settings →
Toolbar**, enable **Print to PDF**, and click **Calibrate Print Button**.
Follow the prompt to click the Print button in ProSelect's print dialog
once. SideKick PS remembers the position for every future print.

## Email the PDF to the client

1. Click the **Email PDF** button (envelope icon) on the toolbar.
2. SideKick PS prints the page to PDF and sends it to the client's email
   address using your GoHighLevel email template.
3. A confirmation appears when the email is sent.

You choose which email template to use in **Settings → GHL Integration →
PDF Email Template**.

## Send a printed thank-you card

1. Click the **Cardly** button on the toolbar.
2. A preview appears showing the postcard design with the client's name and
   address.
3. Review the preview, choose a photo if prompted, and click **Send**.
4. The postcard is printed and posted — it arrives within a few working days.

Cardly needs an API key — enter it in **Settings → Cardly**. You also choose
your preferred card design there.

## Capture a room photo to email

1. Arrange the wall grouping or room display you want to photograph.
2. Click the **Camera** button (red/maroon) on the toolbar.
3. SideKick PS captures the ProSelect room view and saves it as a JPG.
4. A dialog appears — click **Email** to send it to the client via
   GoHighLevel, or **Open** to view the photo.

Use this when a client is considering wall art — seeing their images on their
own wall, even digitally, closes the sale.

## What success looks like

- The invoice is in GoHighLevel with every line item and payment recorded.
- The client has a PDF of their order in their inbox.
- A printed thank-you card is on its way to their home.
- You are done for the day — no admin pile-up.

## When things go wrong

- **Sync failed** — Check your GHL connection in **Settings → GHL
  Integration**. If the API key has expired, generate a new one in GHL.
- **PDF calibration missed the button** — Recalibrate in **Settings →
  Toolbar → Calibrate Print Button**. The button position changes if you
  resize the ProSelect window significantly.
- **Cardly button missing** — A Cardly API key must be entered in
  **Settings → Cardly** before the button appears.

## Related

- [Your First Sale — Start to Finish](ch03-first-sale.md)
- [The Display — QR Codes, Bank Details & Images](ch08-display.md)
