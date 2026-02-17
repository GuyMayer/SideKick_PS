# ProSelect to GoHighLevel Field Mapping Guide

## Overview

SideKick PS extracts order data from ProSelect XML exports and syncs it to GoHighLevel (GHL) invoices. This document explains the field mapping and how the data flows through to Xero and QuickBooks via GHL's accounting integrations.

---

## Invoice Line Item Field Mapping

### ProSelect XML → GHL Invoice

| ProSelect XML Field | GHL Invoice Field | Description | Example Value |
|---------------------|-------------------|-------------|---------------|
| `Product_Code` | `sku` | **Primary matching key** - used to look up GHL product | `smp75`, `com1a`, `l20wtb` |
| `Product_Name` | `name` | Falls back to this if SKU not found in GHL | `Fujifilm DP2 Lustre` |
| `Description` | `description` | Full line item description | `Single 8x10/ 5x7 Print M 10.0 x 8.0 in Fujifilm DP2 Lustre` |
| `Extended_Price` | `price` | Line item total price | `195.00` |
| `Quantity` | `quantity` | Number of items | `1` |
| `ItemType` | `item_type` | Product category | `Traditional Matted Layout`, `Wall Grouping`, `Mat` |
| `Size` | `size` | Product dimensions | `10.0x8.0` |
| `Template_Name` | `template` | ProSelect template used | `Single 8x10/ 5x7 Print` |
| `ID` | `ps_item_id` | ProSelect internal item ID | `50` |

### GHL Product SKU Lookup

When syncing invoices, SideKick PS automatically matches ProSelect products to GHL products:

1. **SKU Lookup**: The `Product_Code` from ProSelect is used to search GHL products
2. **Price-Level SKUs**: GHL stores SKUs on the Price level (not product level), so SideKick fetches all prices for each product
3. **Name Replacement**: If a matching SKU is found, the **GHL product name** replaces the ProSelect product name on the invoice
4. **Fallback**: If no SKU match, the original `Product_Name` from ProSelect is used

**Example:**
```
ProSelect: Product_Name="Luster Print", Product_Code="com1a"
GHL:       Product="Composite 1 - 43x13", Price SKU="com1a"
Result:    Invoice line item name = "Composite 1 - 43x13"
```

### Tax Information

| ProSelect XML Field | GHL Field | Description | Example Value |
|---------------------|-----------|-------------|---------------|
| `Tax/@taxable` | `taxable` | Whether item is taxable | `true` |
| `Tax` | `vat_amount` | Tax amount | `32.50` |
| `Tax1/@label` | `tax_label` | Tax type label | `VAT (20%)` |
| `Tax1/@rate` | `tax_rate` | Tax percentage | `20` |
| `Tax1/@priceIncludesTax` | `price_includes_tax` | Tax-inclusive pricing | `true` |

### Product Line Categorization

| ProSelect XML Field | GHL Field | Description | Example Value |
|---------------------|-----------|-------------|---------------|
| `ProductLineName` | `product_line` | Price list name | `Studio Pricing` |
| `ProductLineName/@code` | `product_line_code` | Price list code | `A` |

---

## Client Information Mapping

| ProSelect XML Field | GHL Contact Field | Notes |
|---------------------|-------------------|-------|
| `First_Name` | `firstName` | |
| `Last_Name` | `lastName` | |
| `Email_Address` | `email` | Primary lookup field |
| `Home_Phone` | `phone` | Converted to E.164 format |
| `Street` | `address1` | |
| `City` | `city` | |
| `State` | `state` | |
| `Zip_Code` | `postalCode` | |
| `Client_ID` | `customField` | ProSelect album ID stored for reference |

---

## GHL → Xero Integration

When GHL syncs invoices to Xero, the following mappings apply:

### Required for Xero Product Matching

| GHL Field | Xero Field | Notes |
|-----------|------------|-------|
| `sku` | `ItemCode` | **Primary matching key** - must match exactly |
| `name` | `Description` | Falls back if no ItemCode match |
| `price` | `UnitAmount` | |
| `quantity` | `Quantity` | |
| `taxable` | `TaxType` | Maps to Xero tax codes (OUTPUT, NONE) |

### Xero Tax Codes

| GHL `tax_label` | Xero `TaxType` | Description |
|-----------------|----------------|-------------|
| `VAT (20%)` | `OUTPUT2` | UK VAT 20% |
| `VAT (5%)` | `OUTPUT` | UK VAT 5% |
| (empty/false) | `NONE` | Zero-rated/exempt |

### Setting Up Xero Integration

1. **Create Items in Xero** with `Code` matching your ProSelect `Product_Code`
2. **Connect GHL to Xero** via Payments → Integrations
3. **Configure Account Codes** for revenue categories
4. Invoices created in GHL will auto-sync with matched products

---

## GHL → QuickBooks Integration

When GHL syncs invoices to QuickBooks, the following mappings apply:

### Required for QuickBooks Product Matching

| GHL Field | QuickBooks Field | Notes |
|-----------|------------------|-------|
| `name` | Query by `Name` | QuickBooks matches by name first |
| `sku` | `Sku` | Stored but not used for matching |
| `price` | `UnitPrice` | |
| `quantity` | `Qty` | |
| `taxable` | `Taxable` | Boolean |

### QuickBooks Matching Behavior

> **Important:** QuickBooks uses **Item Name** for matching, not SKU. Ensure your QuickBooks product names match the `Product_Name` from ProSelect.

### Setting Up QuickBooks Integration

1. **Create Items in QuickBooks** with names matching ProSelect `Product_Name`
2. **Optionally add SKU** to the QuickBooks item for reference
3. **Connect GHL to QuickBooks** via Payments → Integrations
4. **Map Tax Codes** in GHL settings

---

## Best Practices for Multi-System Sync

### Consistent Product Naming

For seamless syncing across all systems, maintain consistent naming:

```
ProSelect Product_Code → GHL SKU → Xero ItemCode
ProSelect Product_Name → GHL Name → QuickBooks Item Name
```

### Recommended Product Code Format

| Product Type | Code Pattern | Example |
|--------------|--------------|---------|
| Small Prints | `smp{size}` | `smp75` (Small Matted Print 7x5) |
| Boxed Matted | `bm{size}i` | `bm75i` (Boxed Matted 7x5 Included) |
| Treasure Box | `l{count}wtb` | `l20wtb` (Large 20 Window Treasure Box) |
| Wall Art | `wa{size}` | `wa5020` (Wall Art 50x20) |
| Albums | `alb{size}` | `alb1010` (Album 10x10) |

### Tax Configuration Checklist

- [ ] ProSelect: Enable VAT in Preferences → Pricing
- [ ] ProSelect: Set correct VAT rate (20% UK standard)
- [ ] ProSelect: Configure tax-inclusive pricing if needed
- [ ] GHL: Set default tax rate in Payments settings
- [ ] Xero: Create matching tax codes (OUTPUT2 for 20% VAT)
- [ ] QuickBooks: Configure tax agency and rates

---

## Troubleshooting

### Products Not Matching in Xero

1. Check `Product_Code` in ProSelect matches `ItemCode` in Xero **exactly**
2. Verify no trailing spaces in either system
3. Check Xero item is marked as "Sold" (has sales account)

### Products Not Matching in QuickBooks

1. Verify `Product_Name` in ProSelect matches QuickBooks item name
2. QuickBooks is case-sensitive - ensure exact match
3. Check item type is correct (Service, Inventory, Non-inventory)

### Tax Not Calculating Correctly

1. Verify `priceIncludesTax` setting matches your pricing setup
2. Check tax rates match between ProSelect and accounting software
3. Ensure taxable flag is correctly set per item

---

## Data Flow Diagram

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  ProSelect  │────▶│     GHL     │────▶│    Xero     │
│    XML      │     │   Invoice   │     │   Invoice   │
│             │     │             │     │             │
│ Product_Code│────▶│    sku      │────▶│  ItemCode   │
│ Product_Name│────▶│    name     │     │             │
│ Description │────▶│ description │────▶│ Description │
│ Tax/@rate   │────▶│  tax_rate   │────▶│  TaxType    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           │            ┌─────────────┐
                           └───────────▶│ QuickBooks  │
                                        │   Invoice   │
                                        │             │
                                        │ Item (Name) │
                                        │    Sku      │
                                        └─────────────┘
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.5.7 | 2026-02-17 | Added SKU extraction, full tax details, product line fields |
| 2.5.6 | 2026-02-12 | GHL API compatibility updates |

---

## Support

For issues with field mapping or integration:
- Check the SideKick PS debug logs in `%APPDATA%\SideKick_PS\Logs`
- Enable Debug Logging in Settings → About
- Contact support with the log file attached
