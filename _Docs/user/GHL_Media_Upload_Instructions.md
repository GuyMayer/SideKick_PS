# GHL Media Uploader - Instructions

Upload images and files to GoHighLevel Media Storage and update contact photo links.

## SideKick Toolbar Integration

A **Postcard Upload** button is available on the Light Blue Shoot screen toolbar.

### How it works:
1. Open a shoot in Light Blue
2. Click the **Postcard** icon on the SideKick toolbar
3. SideKick searches for the **latest image** (by modified date) matching the shoot number in the configured Postcard Folder
4. Confirm upload to GHL Media Storage (Client Photos folder)
5. URL is copied to clipboard
6. If GHL Contact ID is found, offers to update the **Contact Photo Link** field
7. If photo link already exists, asks whether to replace it

### Configure Settings:
1. Open SideKick Settings (gear icon)
2. Under **GHL API Configuration**, configure:
   - **GHL API Key** - v1 API key for contact operations
   - **GHL Media Token** - v2 Private Integration Token for media uploads (starts with `pit-`)
   - **Postcard Folder** - Where to search for postcard images (default: `D:\Shoot_Archive\Post Cards`)
   - **Contact Photo Field ID** - Custom field ID for photo link (default: `FvzCW7qdPl6Dsy1LIgCs`)
3. Click **Apply** to save

### Getting the Media Token:
1. Go to GHL **Settings > Integrations > Private Integrations**
2. Create a new integration with **Media** scope
3. Copy the Access Token (starts with `pit-`)

---

## Command Line Usage

### Quick Start

```powershell
python upload_ghl_media.py "C:/path/to/image.jpg" "Client Photos" "pit-your-token-here"
```

## Requirements

- Python 3.x installed
- `requests` library (auto-installed on first run)
- GHL API Key (v1) for contact operations
- GHL Media Token (v2) for media uploads - Private Integration Token

## Usage

### Upload a Single File

```powershell
python upload_ghl_media.py "C:/Photos/client_photo.jpg" "" "pit-your-token"
```

### Upload to a Specific Folder

```powershell
python upload_ghl_media.py "C:/Photos/image.jpg" "Client Photos" "pit-your-token"
```

### With Debug Output

```powershell
python upload_ghl_media.py "C:/Photos/image.jpg" "Client Photos" "pit-your-token" --debug
```

### Update Contact Photo Link

```powershell
python update_ghl_contact.py --update-photo "<contact_id>" "<api_key>" "<photo_url>" "<field_id>"
```

## Available Folders

| Folder Name         | Description                    |
|---------------------|--------------------------------|
| Iris Photos         | Iris photography               |
| Mixed Display       | Mixed display images           |
| Content AI          | AI-generated content           |
| Testimonials        | Customer testimonials          |
| Duck Display        | Duck display images            |
| Social Media Assets | Social media graphics          |
| Page Assets         | Website page assets            |
| Portrait Display    | Portrait photography           |
| Boudoir Display     | Boudoir photography            |
| **Client Photos**   | Client photo uploads           |
| Staff & Logos       | Staff photos and logos         |

## Supported File Types

- **Images**: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.bmp`, `.tiff`
- **Videos**: `.mp4`, `.mov`, `.avi`, `.webm`
- **Documents**: `.pdf`, `.doc`, `.docx`

## Output

On successful upload, returns:
```json
{
  "success": true,
  "url": "https://storage.googleapis.com/...",
  "data": { ... }
}
```

Results are saved to `ghl_upload_result.json`

## Examples

### Upload from PowerShell

```powershell
# Activate virtual environment
& C:\Stash\.venv\Scripts\Activate.ps1

# Upload image
python upload_ghl_media.py "C:/Users/guy/Pictures/photo.jpg" "Client Photos"
```

### Upload from AutoHotkey

```ahk
; Upload file via Python script
file_path := "C:\Photos\client.jpg"
folder := "Client Photos"
RunWait, python upload_ghl_media.py "%file_path%" "%folder%",, Hide
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| `File not found` | Check file path exists |
| `401 Unauthorized` | API key may be expired |
| `413 Payload Too Large` | File exceeds size limit |
| `Network error` | Check internet connection |

## Configuration

Edit `upload_ghl_media.py` to change:
- `API_KEY` - Your GHL API token
- `LOCATION_ID` - Your GHL location ID

## Location

- **Script**: `C:\Stash\upload_ghl_media.py`
- **Output**: `C:\Stash\ghl_upload_result.json`
