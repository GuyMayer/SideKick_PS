#!/usr/bin/env python3
"""
write_psa_payments.py - Writes payment lines directly into a ProSelect .psa album file

Usage:
    python write_psa_payments.py <psa_path> <payment1> [payment2] ...

Each payment format: day,month,year,methodName,amount
    - day: 1-31
    - month: 1-12
    - year: 2-digit (26) or 4-digit (2026)
    - methodName: e.g., "GoCardless DD", "Credit Card", "Bank Transfer"
    - amount: decimal (e.g., 250.00 or 250)

Options:
    --clear     Clear all existing payments before adding new ones
    --group N   Target order group (default: 1)

Output:
    SUCCESS|count_added
    ERROR|message

Example:
    python write_psa_payments.py album.psa "26,2,26,Credit Card,200" "26,3,26,GoCardless DD,250"
"""

import sys
import sqlite3
import re
import os
from datetime import datetime


# Known ProSelect payment method name -> methodID mapping
# These are the defaults observed across multiple albums
KNOWN_METHOD_IDS = {
    "cash": 1,
    "credit card": 2,
    "check": 3,
    "cheque": 3,
    "bank transfer": 4,
    "bt": 4,
    "paypal": 5,
    "other": 6,
    "gift certificate": 7,
    "store credit": 8,
    "eft": 9,
    "debit card": 10,
    "stripe": 11,
    "gocardless dd": 12,
    "dd": 12,
    "direct debit": 12,
    "bacs": 12,
}


def get_method_id(method_name, existing_methods):
    """
    Resolve a payment method name to its ProSelect methodID.

    1. Check existing payments in the album for an exact match
    2. Fall back to the known defaults map (case-insensitive)
    3. Default to 1 (Cash) if nothing matches
    """
    # Check existing methods first (exact match from album data)
    lower_name = method_name.strip().lower()
    if lower_name in existing_methods:
        return existing_methods[lower_name]

    # Check known defaults
    if lower_name in KNOWN_METHOD_IDS:
        return KNOWN_METHOD_IDS[lower_name]

    # If it's a numeric string, use it directly
    if method_name.strip().isdigit():
        return int(method_name.strip())

    # Default to 1 (Cash)
    return 1


def parse_payment_arg(arg):
    """
    Parse a payment argument string: day,month,year,methodName,amount
    Returns dict with parsed values or raises ValueError.
    """
    parts = arg.split(",")
    if len(parts) < 5:
        raise ValueError(f"Expected day,month,year,method,amount but got: {arg}")

    day = int(parts[0].strip())
    month = int(parts[1].strip())
    year_str = parts[2].strip()

    # Handle 2-digit or 4-digit year
    year = int(year_str)
    if year < 100:
        year += 2000

    # Method name might contain commas in theory, but in practice it doesn't
    # The last element is always the amount, everything between index 3 and last is method
    amount_str = parts[-1].strip()
    method_name = ",".join(parts[3:-1]).strip()

    amount = float(amount_str)

    return {
        "day": day,
        "month": month,
        "year": year,
        "method_name": method_name,
        "amount": amount,
    }


def format_amount(amount):
    """
    Format amount to match ProSelect convention.
    Whole numbers: "250", decimals: "200.05"
    """
    if amount == int(amount):
        return str(int(amount))
    else:
        return f"{amount:.2f}"


def write_payments_to_psa(psa_path, payment_args, clear_existing=False, target_group=1):
    """
    Write payment lines into a .psa SQLite database file.

    Args:
        psa_path: Path to the .psa file
        payment_args: List of payment argument strings (day,month,year,method,amount)
        clear_existing: If True, remove all existing payments first
        target_group: Order group ID to modify (default 1)

    Returns:
        "SUCCESS|count" or "ERROR|message"
    """
    if not os.path.exists(psa_path):
        return f"ERROR|File not found: {psa_path}"

    # Parse all payment arguments first (fail fast on bad input)
    payments = []
    for arg in payment_args:
        try:
            payments.append(parse_payment_arg(arg))
        except ValueError as e:
            return f"ERROR|Bad payment format: {e}"

    if not payments:
        return "ERROR|No payment lines provided"

    try:
        # Open database for read-write
        conn = sqlite3.connect(psa_path)
        cursor = conn.cursor()

        # Read OrderList
        cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode=?', ('OrderList',))
        row = cursor.fetchone()

        if not row:
            conn.close()
            return "ERROR|No OrderList found in album"

        order_data = row[0]
        if isinstance(order_data, bytes):
            order_data = order_data.decode('utf-8', errors='replace')

        # Build existing method name -> ID map from current payments
        existing_methods = {}
        for m in re.finditer(r'methodID="(\d+)"[^/]*methodName="([^"]+)"', order_data):
            mid = int(m.group(1))
            mname = m.group(2).strip().lower()
            existing_methods[mname] = mid

        # Find current max payment ID
        max_id = 0
        for m in re.finditer(r'<payment[^>]+\bid="(\d+)"', order_data):
            pid = int(m.group(1))
            if pid > max_id:
                max_id = pid

        # Find the target Group element
        group_pattern = rf'<Group\s+id="{target_group}"[^>]*>'
        group_match = re.search(group_pattern, order_data)
        if not group_match:
            conn.close()
            return f"ERROR|Order group {target_group} not found"

        # Detect indentation from existing data
        # Look for existing payment lines to match indentation
        indent = "\t\t\t\t\t\t"  # Default: 6 tabs (matches observed format)
        payment_indent_match = re.search(r'^(\s+)<payment\s', order_data, re.MULTILINE)
        if payment_indent_match:
            indent = payment_indent_match.group(1)

        payments_tag_indent = indent[:-1] if len(indent) > 0 else "\t\t\t\t\t"  # 5 tabs for <payments> tag

        # Handle clear mode
        if clear_existing:
            # Remove all existing payment elements
            order_data = re.sub(
                r'<payments>\s*(?:<payment[^/]*/>\s*)*</payments>',
                '<payments>\n' + payments_tag_indent + '</payments>',
                order_data,
                flags=re.DOTALL
            )
            max_id = 0

        # Find the </payments> closing tag to insert before it
        payments_close = re.search(r'(\s*)</payments>', order_data)

        if not payments_close:
            # No <payments> section exists - need to create one
            # Insert after the last customer field before </Group>
            # Look for position just before </Group> in the target group
            group_end = re.search(
                rf'(<Group\s+id="{target_group}"[^>]*>.*?)(</Group>)',
                order_data,
                re.DOTALL
            )
            if group_end:
                insert_pos = group_end.start(2)
                new_section = (
                    f"{payments_tag_indent}<payments>\n"
                    f"{payments_tag_indent}</payments>\n"
                )
                order_data = order_data[:insert_pos] + new_section + order_data[insert_pos:]
                # Re-find the closing tag
                payments_close = re.search(r'(\s*)</payments>', order_data)

        if not payments_close:
            conn.close()
            return "ERROR|Could not find or create <payments> section"

        # Build new payment XML lines
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        new_lines = []
        next_id = max_id + 1

        for p in payments:
            method_id = get_method_id(p["method_name"], existing_methods)
            jdate = f"{p['year']:04d}-{p['month']:02d}-{p['day']:02d} {now_str.split(' ')[1]}"
            amount_str = format_amount(p["amount"])

            # Match ProSelect's exact formatting: double-space between attributes
            line = (
                f'{indent}<payment value="{amount_str}"  exported="No"  '
                f'methodID="{method_id}"  SCEntryID=""  '
                f'methodName="{p["method_name"]}"  status="0"  '
                f'jdate="{jdate}" id="{next_id}" />'
            )
            new_lines.append(line)
            next_id += 1

        # Insert new payment lines before </payments>
        insert_text = "\n".join(new_lines) + "\n"
        insert_pos = payments_close.start()
        order_data = order_data[:insert_pos] + "\n" + insert_text + order_data[insert_pos:]

        # Update NextPaymentID on the Group element
        new_max_id = next_id - 1
        order_data = re.sub(
            rf'(<Group\s+id="{target_group}"[^>]*?)NextPaymentID="\d+"',
            rf'\g<1>NextPaymentID="{new_max_id}"',
            order_data
        )

        # Update lastPaymentsChanged timestamp on the Group element
        order_data = re.sub(
            rf'(<Group\s+id="{target_group}"[^>]*?)lastPaymentsChanged="[^"]*"',
            rf'\g<1>lastPaymentsChanged="{now_str}"',
            order_data
        )

        # Write back to database
        cursor.execute(
            'UPDATE BigStrings SET buffer=? WHERE buffCode=?',
            (order_data, 'OrderList')
        )
        conn.commit()
        conn.close()

        return f"SUCCESS|{len(payments)}"

    except sqlite3.Error as e:
        return f"ERROR|SQLite error: {str(e)}"
    except Exception as e:
        return f"ERROR|{str(e)}"


def main():
    if len(sys.argv) < 3:
        print("ERROR|Usage: write_psa_payments.py <psa_path> <payment1> [payment2] ...")
        print("  Payment format: day,month,year,methodName,amount")
        print("  Options: --clear (remove existing payments first)")
        print("           --group N (target order group, default 1)")
        sys.exit(1)

    psa_path = sys.argv[1]
    clear_existing = False
    target_group = 1
    payment_args = []

    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--clear":
            clear_existing = True
        elif arg == "--group" and i + 1 < len(sys.argv):
            i += 1
            target_group = int(sys.argv[i])
        else:
            payment_args.append(arg)
        i += 1

    result = write_payments_to_psa(psa_path, payment_args, clear_existing, target_group)
    print(result)


if __name__ == "__main__":
    main()
