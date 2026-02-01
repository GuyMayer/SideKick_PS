"""
GHL Media Uploader - Upload files to GoHighLevel Media Storage
Author: GuyMayer
Date: 2026-01-27
Usage: python upload_ghl_media.py <file_path> [folder_name]
       python upload_ghl_media.py "C:/path/to/image.jpg" "Client Photos"
"""

import subprocess
import sys
import json
import os
import mimetypes

# Auto-install dependencies
def install_dependencies() -> None:
    """Auto-install required Python packages if not present."""
    required = ['requests']
    for package in required:
        try:
            __import__(package)
        except ImportError:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', package, '-q'])

install_dependencies()
import requests

# Configuration - Token passed as 3rd argument, or use default
API_KEY = sys.argv[3] if len(sys.argv) > 3 else "pit-c0d5c542-b383-4acf-b0f4-b80345f68b05"
LOCATION_ID = "8IWxk5M0PvbNf1w3npQU"


def _get_output_dir():
    """Get a writable directory for output files."""
    appdata = os.environ.get('APPDATA')
    if appdata:
        sidekick_dir = os.path.join(appdata, 'SideKick_PS')
        try:
            os.makedirs(sidekick_dir, exist_ok=True)
            return sidekick_dir
        except OSError:
            pass
    return os.environ.get('TEMP', os.getcwd())
DEBUG = "--debug" in sys.argv

# API endpoints
BASE_URL = "https://services.leadconnectorhq.com"
MEDIA_UPLOAD_URL = f"{BASE_URL}/medias/upload-file"
MEDIA_FILES_URL = f"{BASE_URL}/medias/files"

def debug_print(msg):
    """Print debug message if debug mode is enabled"""
    if DEBUG:
        print(f"[DEBUG] {msg}")

def get_headers() -> dict:
    """Get authorization headers."""
    debug_print(f"Using API Token: {API_KEY[:20]}...{API_KEY[-10:]}")
    return {
        "Authorization": f"Bearer {API_KEY}",
        "Version": "2021-07-28"
    }

def list_folders() -> dict | None:
    """List all folders in media storage."""
    headers = get_headers()
    headers["Content-Type"] = "application/json"

    params = {
        "altId": LOCATION_ID,
        "altType": "location",
        "sortBy": "createdAt",
        "sortOrder": "desc"
    }

    try:
        response = requests.get(MEDIA_FILES_URL, headers=headers, params=params, timeout=30)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error listing folders: {response.status_code}")
            print(response.text)
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None

def find_folder_id(folder_name: str) -> str | None:
    """Find folder ID by name."""
    data = list_folders()
    if not data:
        return None

    # Search in folders
    folders = data.get('files', [])
    for folder in folders:
        if folder.get('name', '').lower() == folder_name.lower():
            return folder.get('id')

    return None

def upload_file(file_path: str, folder_name: str | None = None) -> dict:
    """Upload a file to GHL Media Storage."""

    if not os.path.exists(file_path):
        return {
            'success': False,
            'error': f"File not found: {file_path}"
        }

    # Get mime type
    mime_type, _ = mimetypes.guess_type(file_path)
    if not mime_type:
        mime_type = 'application/octet-stream'

    file_name = os.path.basename(file_path)

    headers = get_headers()
    # Don't set Content-Type for multipart - requests handles it

    try:
        with open(file_path, 'rb') as f:
            files = {
                'file': (file_name, f, mime_type)
            }

            # Note: hosted should be false or omitted when uploading a local file
            # hosted=true is only for when providing a fileUrl to an already-hosted file
            data = {
                'name': file_name
            }

            # Add location info
            params = {
                'altId': LOCATION_ID,
                'altType': 'location'
            }

            print(f"Uploading: {file_name}")
            print(f"Size: {os.path.getsize(file_path) / 1024:.1f} KB")
            print(f"Type: {mime_type}")
            debug_print(f"URL: {MEDIA_UPLOAD_URL}")
            debug_print(f"Params: {params}")
            debug_print(f"Headers: Authorization=Bearer {API_KEY[:15]}...")

            response = requests.post(
                MEDIA_UPLOAD_URL,
                headers=headers,
                params=params,
                files=files,
                data=data,
                timeout=120
            )

            if response.status_code in [200, 201]:
                result = response.json()
                print(f"\n✓ Upload successful!")
                print(f"File URL: {result.get('url', 'N/A')}")
                return {
                    'success': True,
                    'data': result,
                    'url': result.get('url')
                }
            else:
                print(f"\n✗ Upload failed: {response.status_code}")
                print(response.text)
                return {
                    'success': False,
                    'error': f"API returned status {response.status_code}",
                    'message': response.text[:500]
                }

    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def main() -> None:
    """Main entry point for GHL Media Uploader."""
    if len(sys.argv) < 2:
        print("GHL Media Uploader")
        print("=" * 40)
        print("\nUsage:")
        print('  python upload_ghl_media.py <file_path> [folder_name]')
        print("\nExamples:")
        print('  python upload_ghl_media.py "C:\\Photos\\image.jpg"')
        print('  python upload_ghl_media.py "C:\\Photos\\image.jpg" "Client Photos"')
        print("\nCommands:")
        print('  python upload_ghl_media.py --list-folders')
        sys.exit(1)

    # List folders command
    if sys.argv[1] == "--list-folders":
        print("Fetching folders from GHL Media Storage...")
        data = list_folders()
        if data:
            print("\nFolders found:")
            for item in data.get('files', []):
                if item.get('isDir'):
                    print(f"  📁 {item.get('name')} (ID: {item.get('id')})")
        sys.exit(0)

    file_path = sys.argv[1]
    folder_name = sys.argv[2] if len(sys.argv) > 2 else None

    print("GHL Media Uploader")
    print("=" * 40)

    result = upload_file(file_path, folder_name)

    # Save result
    with open(os.path.join(_get_output_dir(), "ghl_upload_result.json"), 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2)

    print(json.dumps(result, indent=2))
    sys.exit(0 if result['success'] else 1)

if __name__ == "__main__":
    main()
