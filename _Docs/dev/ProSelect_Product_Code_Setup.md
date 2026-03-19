# ProSelect Product Code (SKU) Setup Guide

## Why Product Codes Matter

Product codes (SKUs) in ProSelect are essential for:
- **GHL Product Name Matching** - SideKick looks up your GHL products by SKU and uses the GHL product name on invoices
- **Xero/QuickBooks sync** - Maps to accounting product codes
- **Inventory tracking** - Identifies products across systems

**When you add a Product Code in ProSelect and create a matching product with the same SKU in GHL, SideKick automatically uses the GHL product name on invoices.**

### How It Works

1. You add a **Product Code** (e.g., `com1a`) to a product in ProSelect
2. In GHL → Payments → Products, you create a product with a **Price** that has SKU `com1a`
3. When you sync an order, SideKick finds the matching GHL product
4. The invoice line item shows the **GHL product name** (not the ProSelect name)

---

## How to Add Product Codes in ProSelect

### Step 1: Open Price Lists

1. In ProSelect, go to **Setup** menu
2. Select **Price Lists...**
3. Choose the price list you want to edit

### Step 2: Add Product Codes to Products

For each product in your price list:

1. **Select the product** in the price list
2. Look for the **Product Code** or **SKU** field
3. Enter a unique code that matches your GHL/Xero product

![ProSelect Price List Setup](images/proselect_price_list.png)

### Step 3: Product Code Best Practices

| Item Type | Example Product Code | Notes |
|-----------|---------------------|-------|
| Prints | `PRINT-8x10`, `smp75` | Use size or lab code |
| Frames | `FRM-BLK-11x14` | Include finish + size |
| Albums | `ALB-LEATHER-10x10` | Include type + size |
| Collections | `COLL-PORTRAIT-1` | Use collection name |
| Wall Art | `WALL-CANVAS-24x36` | Include product + size |
| Digital Files | `DIG-HIRES`, `DIG-WEB` | Resolution indicator |
| Mats | `MAT-WHT-8x10` | Color + size |

### Step 4: Verify Export

After adding product codes:

1. Create a test order
2. Export via **File → Export Orders...**
3. Open the XML file and verify `<Product_Code>` tags have values

---

## Matching GHL Products

For SideKick_PS to auto-link products:

1. **GHL Setup**: In GHL → Payments → Products, add products with matching names or SKUs
2. **Exact Match**: The GHL product name should match ProSelect's `Product_Name` field
3. **SKU Match**: Alternatively, use matching SKU codes for more reliable linking

### GHL Product Setup

1. Go to GHL → **Payments** → **Products**
2. Click **+ Add Product**
3. Enter:
   - **Name**: The name you want to appear on invoices (e.g., "Composite 1 - 43x13")
   - Click **Add Price** to add a price tier
   - In the Price settings, set the **SKU** to match your ProSelect product code (e.g., "com1a")
   - **Price**: Set your standard price (ProSelect price takes precedence)

**Important:** In GHL, SKUs are set on the **Price** level, not the product level. You must add a Price to your product and set the SKU there.

---

## Common Issues

### Empty Product Names (Wall Groupings/Collections)

**Problem**: Wall groupings and collections may have empty `Product_Name` fields.

**Solution**: In ProSelect's Price List setup:
1. Give your collections/groupings a proper **Product Name** (e.g., "Portrait Collection 1")
2. Add a **Product Code** (e.g., "COLL-PORT-1")

### Missing Product Codes for Accessories

**Problem**: Mats, frames, and accessories often have no product code.

**Solution**: 
1. Open your Price List in ProSelect
2. Navigate to the Accessories section
3. Add product codes to each accessory item

### How to Check Your XML Export

To verify your product codes are exporting:

```xml
<!-- Good - has both Product_Name and Product_Code -->
<Ordered_Item>
    <Product_Name>Fujifilm DP2 Lustre</Product_Name>
    <Product_Code>smp75</Product_Code>
    <Extended_Price>195.00</Extended_Price>
</Ordered_Item>

<!-- Bad - missing Product_Code -->
<Ordered_Item>
    <Product_Name>Black Image Box Mat</Product_Name>
    <Product_Code></Product_Code>  <!-- EMPTY - won't match in GHL -->
</Ordered_Item>

<!-- Bad - missing both (typical for Collections) -->
<Ordered_Item>
    <ItemType>Wall Grouping</ItemType>
    <Description>Collection 1</Description>
    <Product_Name></Product_Name>  <!-- EMPTY -->
    <Product_Code></Product_Code>  <!-- EMPTY -->
</Ordered_Item>
```

---

## ProSelect Price List Location

Your price lists are typically stored in:
- **Windows**: `C:\Users\[Username]\Documents\ProSelect\Price Lists\`
- **Mac**: `~/Documents/ProSelect/Price Lists/`

---

## Quick Checklist

- [ ] All products have a **Product Name**
- [ ] All products have a **Product Code** (SKU)
- [ ] Collections/Wall Groupings have product names (not just descriptions)
- [ ] GHL products match ProSelect product names OR SKUs
- [ ] Accessory items (mats, frames) have product codes
- [ ] Test export shows populated `<Product_Code>` tags

---

## Need Help?

If you're still having issues with product matching:

1. **Check the XML**: Export an order and open the XML file to verify product codes
2. **Enable Debug Logging**: Settings → Debug Logging → Enable for 24hrs
3. **Contact Support**: Send your XML file and debug logs for analysis

---

*Document Version: 2.5.18 | Last Updated: 2026-02-17*
