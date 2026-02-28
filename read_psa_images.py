#!/usr/bin/env python3
"""
read_psa_images.py - Extracts image information and thumbnails from ProSelect .psa album files

Usage:
    python read_psa_images.py <path_to_psa_file> [--extract-thumbnails <output_folder>]

Output (info mode):
    IMAGES|count|folder_path
    image1_name|image2_name|...

Output (extract mode):
    Extracts JPEG thumbnails to the specified folder
    EXTRACTED|count|folder_path
"""

import sys
import sqlite3
import re
import os
import base64


def get_album_info(psa_path: str) -> dict:
    """Extract album info and image list from .psa file."""

    if not os.path.exists(psa_path):
        return {"error": f"File not found: {psa_path}"}

    try:
        conn = sqlite3.connect(psa_path)
        cursor = conn.cursor()

        # Get ImageList from BigStrings
        cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="ImageList"')
        row = cursor.fetchone()

        if not row:
            conn.close()
            return {"error": "No ImageList found in album"}

        image_data = row[0]
        if isinstance(image_data, bytes):
            image_data = image_data.decode('utf-8', errors='replace')

        # Get OrderList for client info
        cursor.execute('SELECT buffer FROM BigStrings WHERE buffCode="OrderList"')
        order_row = cursor.fetchone()
        order_data = ""
        if order_row:
            order_data = order_row[0]
            if isinstance(order_data, bytes):
                order_data = order_data.decode('utf-8', errors='replace')

        conn.close()

        # Parse source folder from ImageList
        # Look for pattern: ##2##E:\\Shoot Archive\\...\\
        folder_pattern = r'##2##([^"]+?)\\\\?"'
        folder_match = re.search(folder_pattern, image_data)
        source_folder = ""
        if folder_match:
            source_folder = folder_match.group(1).replace('\\\\', '\\')

        # Parse image names from ImageList
        # Pattern: <image name="P25073P0009.tif" ...>
        images = []
        image_pattern = r'<image\s+name="([^"]+)"[^>]+>'

        # Also capture albumimage id for thumbnail matching
        image_ids = {}
        full_image_pattern = r'<image\s+name="([^"]+)"[^>]*>.*?<albumimage\s+id="(\d+)"[^/]*/>'

        for match in re.finditer(full_image_pattern, image_data, re.DOTALL):
            name = match.group(1)
            album_id = int(match.group(2))
            images.append(name)
            image_ids[album_id] = name

        # If no matches with full pattern, try simple pattern
        if not images:
            for match in re.finditer(image_pattern, image_data):
                images.append(match.group(1))

        # Parse client info from OrderList
        client_info = {}
        if order_data:
            first_name_match = re.search(r'<firstName>([^<]*)</firstName>', order_data)
            last_name_match = re.search(r'<lastName>([^<]*)</lastName>', order_data)
            client_code_match = re.search(r'<clientCode>([^<]*)</clientCode>', order_data)

            if first_name_match:
                client_info['first_name'] = first_name_match.group(1)
            if last_name_match:
                client_info['last_name'] = last_name_match.group(1)
            if client_code_match:
                client_info['client_id'] = client_code_match.group(1)

        # Get album name from psa filename
        album_name = os.path.splitext(os.path.basename(psa_path))[0]
        # Extract shoot number (e.g., P25073P from P25073P_Dunkley_...)
        shoot_no = album_name.split('_')[0] if '_' in album_name else album_name

        return {
            "source_folder": source_folder,
            "images": images,
            "image_ids": image_ids,
            "album_name": album_name,
            "shoot_no": shoot_no,
            "client_info": client_info,
            "psa_path": psa_path
        }

    except sqlite3.Error as e:
        return {"error": f"Database error: {e}"}
    except Exception as e:
        return {"error": f"Error: {e}"}


def extract_thumbnails(psa_path: str, output_folder: str) -> dict:
    """Extract all thumbnails from .psa file to a folder.

    Args:
        psa_path: Path to the .psa file
        output_folder: Folder to save extracted thumbnails

    Returns:
        dict with extraction results
    """

    if not os.path.exists(psa_path):
        return {"error": f"File not found: {psa_path}"}

    # Get album info first
    info = get_album_info(psa_path)
    if "error" in info:
        return info

    # Create output folder
    os.makedirs(output_folder, exist_ok=True)

    try:
        conn = sqlite3.connect(psa_path)
        cursor = conn.cursor()

        # Get all thumbnails with type 1 (main thumbnails)
        cursor.execute('''
            SELECT id, imageID, imageData
            FROM Thumbnails
            WHERE thumbnailType = 1 AND imageData IS NOT NULL
        ''')

        extracted = []
        image_ids = info.get("image_ids", {})

        for row in cursor.fetchall():
            thumb_id, image_id, data = row

            if not data:
                continue

            # Verify it's a JPEG (starts with FFD8FF)
            if data[:2] != b'\xff\xd8':
                continue

            # Get image name from mapping, or use ID
            if image_id in image_ids:
                # Use original name but change extension to .jpg
                base_name = os.path.splitext(image_ids[image_id])[0]
                filename = f"{base_name}.jpg"
            else:
                filename = f"thumb_{image_id:04d}.jpg"

            output_path = os.path.join(output_folder, filename)

            with open(output_path, 'wb') as f:
                f.write(data)

            extracted.append(filename)

        conn.close()

        return {
            "success": True,
            "count": len(extracted),
            "folder": output_folder,
            "files": extracted,
            "album_info": info
        }

    except sqlite3.Error as e:
        return {"error": f"Database error: {e}"}
    except Exception as e:
        return {"error": f"Error: {e}"}


def main() -> None:
    """CLI entry point — read image data and optionally extract thumbnails from a .psa file."""
    if len(sys.argv) < 2:
        print("ERROR|Usage: python read_psa_images.py <psa_file> [--extract-thumbnails <folder>]")
        sys.exit(1)

    psa_path = sys.argv[1]

    # Check for extract mode
    if len(sys.argv) >= 4 and sys.argv[2] == "--extract-thumbnails":
        output_folder = sys.argv[3]
        result = extract_thumbnails(psa_path, output_folder)

        if "error" in result:
            print(f"ERROR|{result['error']}")
        else:
            # Output format for AHK parsing
            print(f"EXTRACTED|{result['count']}|{result['folder']}")
            # Also output album info
            info = result['album_info']
            print(f"ALBUM|{info.get('shoot_no', '')}|{info.get('album_name', '')}")
            client = info.get('client_info', {})
            print(f"CLIENT|{client.get('first_name', '')}|{client.get('last_name', '')}|{client.get('client_id', '')}")
    else:
        # Info mode - just return image info
        result = get_album_info(psa_path)

        if "error" in result:
            print(f"ERROR|{result['error']}")
        else:
            print(f"IMAGES|{len(result['images'])}|{result['source_folder']}")
            if result['images']:
                print("|".join(result['images']))


if __name__ == "__main__":
    main()
