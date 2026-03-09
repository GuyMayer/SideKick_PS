#!/usr/bin/env python3
"""
detect_psa_group.py - Detect the correct order group in a multi-client ProSelect album

Usage:
    python detect_psa_group.py <psa_path> <balance>

Reads the .psa SQLite file and returns the group ID whose outstanding balance
matches the given amount. Used by SideKick PayPlan to target the correct client
when writing payments.

Output:
    GROUP|<id>|<firstName>|<lastName>|<groupCount>
    AMBIGUOUS|<groupCount>|<id1>|<firstName1> <lastName1>|<id2>|<firstName2> <lastName2>|...
    ERROR|<message>
"""

import sys
import sqlite3
import re
import os


def detect_group(psa_path: str, target_balance: float) -> str:
    """Detect which order group matches the given balance.

    Args:
        psa_path: Path to the .psa file
        target_balance: The balance shown in the Add Payment window

    Returns:
        "GROUP|id|firstName|lastName|groupCount" or "ERROR|message"
    """
    if not os.path.exists(psa_path):
        return f"ERROR|File not found: {psa_path}"

    try:
        conn = sqlite3.connect(f"file:{psa_path}?mode=ro", uri=True)
        cursor = conn.cursor()

        cursor.execute("SELECT buffer FROM BigStrings WHERE buffCode='OrderList'")
        row = cursor.fetchone()
        conn.close()

        if not row:
            return "ERROR|No OrderList found in album"

        order_data = row[0]
        if isinstance(order_data, bytes):
            order_data = order_data.decode("utf-8", errors="replace")

        # Parse all Group elements
        groups = []
        for m in re.finditer(
            r'<Group\s+id="(\d+)"[^>]*>(.*?)</Group>', order_data, re.DOTALL
        ):
            gid = int(m.group(1))
            content = m.group(2)

            fn = re.search(r"<firstName>(.*?)</firstName>", content)
            ln = re.search(r"<lastName>(.*?)</lastName>", content)
            first_name = fn.group(1) if fn else ""
            last_name = ln.group(1) if ln else ""

            # Calculate total payments already made
            payment_total = 0.0
            for p in re.finditer(r'value="([\d.]+)"', content):
                payment_total += float(p.group(1))

            groups.append({
                "id": gid,
                "firstName": first_name,
                "lastName": last_name,
                "paymentTotal": round(payment_total, 2),
            })

        group_count = len(groups)

        if group_count == 0:
            return "ERROR|No order groups found"

        # If only one group, return it directly
        if group_count == 1:
            g = groups[0]
            return f"GROUP|{g['id']}|{g['firstName']}|{g['lastName']}|{group_count}"

        # Multiple groups: we need to calculate each group's outstanding balance
        # and match against target_balance
        #
        # Outstanding balance = order total - payments made
        # But we can also match by finding the group whose balance matches
        #
        # Parse order items to calculate totals per group
        group_order_totals = {}
        for g in groups:
            group_order_totals[g["id"]] = 0.0

        # Parse order items - each has groupID and price info
        # Items have: groupID="N" and prices, extras, etc.
        for item_match in re.finditer(
            r'<item\s+[^>]*groupID="(\d+)"[^>]*>(.*?)</item>',
            order_data,
            re.DOTALL,
        ):
            gid = int(item_match.group(1))
            item_content = item_match.group(2)

            if gid not in group_order_totals:
                continue

            # Get base price
            price_match = re.search(r'<Price\s+[^>]*price="([^"]+)"', item_content)
            if price_match:
                try:
                    price = float(price_match.group(1))
                except ValueError:
                    price = 0.0
            else:
                price = 0.0

            # Get qty from the item attributes
            qty_match = re.search(
                r'groupID="' + str(gid) + r'"[^>]*\bqty="(\d+)"',
                item_match.group(0),
            )
            qty = int(qty_match.group(1)) if qty_match else 1

            # Calculate line total (price * qty, but ProSelect stores total in price for some items)
            line_total = price * qty if qty > 0 else price

            # Add extras (discounts, credits, etc.)
            for extra in re.finditer(
                r'<extra[^>]+price="([^"]+)"[^>]*/>', item_content
            ):
                try:
                    extra_price = float(extra.group(1))
                    extra_qty_match = re.search(r'qty="(\d+)"', extra.group(0))
                    extra_qty = int(extra_qty_match.group(1)) if extra_qty_match else 1
                    line_total += extra_price * extra_qty
                except ValueError:
                    pass

            group_order_totals[gid] += line_total

        # Now match: outstanding balance = order total - payments
        target = round(target_balance, 2)
        matches = []

        for g in groups:
            order_total = round(group_order_totals.get(g["id"], 0.0), 2)
            outstanding = round(order_total - g["paymentTotal"], 2)
            g["outstanding"] = outstanding

            diff = abs(outstanding - target)
            if diff <= 1.0:  # Within £1 tolerance for rounding
                matches.append(g)

        # Single match — we know the group
        if len(matches) == 1:
            g = matches[0]
            return f"GROUP|{g['id']}|{g['firstName']}|{g['lastName']}|{group_count}"

        # Multiple matches (same balance) — ambiguous, caller must ask user
        if len(matches) > 1:
            parts = [f"AMBIGUOUS|{group_count}"]
            for g in matches:
                parts.append(f"{g['id']}|{g['firstName']} {g['lastName']}")
            return "|".join(parts)

        # No balance match: check if any group has zero payments
        # (new client that needs payments added)
        groups_without_payments = [g for g in groups if g["paymentTotal"] == 0.0]
        if len(groups_without_payments) == 1:
            g = groups_without_payments[0]
            return f"GROUP|{g['id']}|{g['firstName']}|{g['lastName']}|{group_count}"

        # Still ambiguous — return all groups for user selection
        parts = [f"AMBIGUOUS|{group_count}"]
        for g in groups:
            parts.append(f"{g['id']}|{g['firstName']} {g['lastName']}")
        return "|".join(parts)

    except sqlite3.Error as e:
        return f"ERROR|SQLite error: {str(e)}"
    except Exception as e:
        return f"ERROR|{str(e)}"


def main() -> None:
    """CLI entry point."""
    if len(sys.argv) < 3:
        print("ERROR|Usage: detect_psa_group.py <psa_path> <balance>")
        sys.exit(1)

    psa_path = sys.argv[1]
    try:
        balance = float(sys.argv[2])
    except ValueError:
        print(f"ERROR|Invalid balance: {sys.argv[2]}")
        sys.exit(1)

    print(detect_group(psa_path, balance))


if __name__ == "__main__":
    main()
