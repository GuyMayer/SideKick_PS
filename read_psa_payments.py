#!/usr/bin/env python3
"""
read_psa_payments.py - Reads payment data from ProSelect .psa album files

Usage:
    python read_psa_payments.py <path_to_psa_file>

Output:
    PAYMENTS|count|payment1|payment2|...
    Where each payment is: date,amount,method,methodID
    Date format: DD,MM,YYYY

    NO_PAYMENTS - No payments found
    ERROR|message - Error occurred
"""

import sys
import sqlite3
import re
import os

def read_payments_from_psa(psa_path) -> str:
    """Read payment data from a .psa SQLite database file."""

    if not os.path.exists(psa_path):
        return f"ERROR|File not found: {psa_path}"

    try:
        conn = sqlite3.connect(psa_path)
        cursor = conn.cursor()

        # Read OrderList from BigStrings
        cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="OrderList"')
        row = cursor.fetchone()

        if not row:
            conn.close()
            return "ERROR|No OrderList found in album"

        order_data = row[0]
        if isinstance(order_data, bytes):
            order_data = order_data.decode('utf-8', errors='replace')

        conn.close()

        # Extract order date from Group element's lastOrderChanged attribute
        order_date = ""
        group_match = re.search(r'<Group[^>]+lastOrderChanged="(\d{4})-(\d{2})-(\d{2})', order_data)
        if group_match:
            order_date = f"{group_match.group(3)}/{group_match.group(2)}/{group_match.group(1)}"  # DD/MM/YYYY

        # Parse payments from XML
        # Format: <payment value="200" methodID="12" methodName="GoCardless DD" jdate="2026-03-01 12:41:33" id="10" />
        payments = []

        # Find all payment elements
        payment_pattern = r'<payment\s+([^>]+)/>'
        for match in re.finditer(payment_pattern, order_data, re.IGNORECASE):
            attrs = match.group(1)

            # Extract attributes - value can be integer or decimal (e.g., "91.7" or "500")
            value_match = re.search(r'value="([\d.]+)"', attrs)
            method_id_match = re.search(r'methodID="(\d+)"', attrs)
            method_name_match = re.search(r'methodName="([^"]+)"', attrs)
            jdate_match = re.search(r'jdate="(\d{4})-(\d{2})-(\d{2})', attrs)

            if value_match and jdate_match:
                # Value is in whole currency units (not pence)
                amount = float(value_match.group(1))
                year = jdate_match.group(1)
                month = jdate_match.group(2)
                day = jdate_match.group(3)

                method_name = method_name_match.group(1) if method_name_match else "Unknown"
                method_id = method_id_match.group(1) if method_id_match else "0"

                # Format: day,month,year,amount,methodName,methodID
                payment_str = f"{int(day)},{int(month)},{year},{amount:.2f},{method_name},{method_id}"
                payments.append(payment_str)

        if not payments:
            return "NO_PAYMENTS" + (f"|{order_date}" if order_date else "")

        return f"PAYMENTS|{len(payments)}|{order_date}|" + "|".join(payments)

    except sqlite3.Error as e:
        return f"ERROR|SQLite error: {str(e)}"
    except Exception as e:
        return f"ERROR|{str(e)}"


def main() -> None:
    """CLI entry point — read and output payment data from a .psa file."""
    if len(sys.argv) < 2:
        print("ERROR|No .psa file path provided")
        sys.exit(1)

    psa_path = sys.argv[1]
    result = read_payments_from_psa(psa_path)
    print(result)


if __name__ == "__main__":
    main()
