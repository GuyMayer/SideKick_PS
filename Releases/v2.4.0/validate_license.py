"""
SideKick_PS License Validation
Validates license keys against LemonSqueezy API with location ID binding.
"""

import requests
import hashlib
import json
import sys
import os
import base64
from datetime import datetime

# LemonSqueezy API Configuration
LEMON_API_URL = "https://api.lemonsqueezy.com/v1"
STORE_ID = "zoomphoto"
PRODUCT_ID = "234060d4-063d-4e6f-b91b-744c254c0e7c"

def get_instance_id(location_id: str) -> str:
    """
    Generate a unique instance identifier based on GHL Location ID.
    This ties the license to a specific GHL location.
    """
    # Hash the location ID to create a consistent instance identifier
    instance = hashlib.sha256(f"sidekick_ps_{location_id}".encode()).hexdigest()[:32]
    return instance

def _get_encryption_key() -> bytes:
    """
    Generate encryption key from app secret.
    Uses a fixed salt + app identifier to create consistent key.
    """
    # Secret salt - change this to your own unique value
    salt = "SK_PS_2026_ZoomPhoto_Trial_Salt_v1"
    key_material = f"sidekick_proselect_{salt}_encryption"
    # Create 32-byte key from hash
    return hashlib.sha256(key_material.encode()).digest()

def _xor_encrypt(data: bytes, key: bytes) -> bytes:
    """Simple XOR encryption with repeating key."""
    key_len = len(key)
    return bytes([data[i] ^ key[i % key_len] for i in range(len(data))])

def _encrypt_trial_data(trial_data: dict, location_hash: str) -> str:
    """
    Encrypt trial data using location hash + app key.
    Returns base64 encoded encrypted string.
    """
    # Combine app key with location hash for unique encryption per location
    app_key = _get_encryption_key()
    location_key = hashlib.sha256(location_hash.encode()).digest()
    combined_key = bytes([app_key[i] ^ location_key[i] for i in range(32)])
    
    # Add integrity check
    json_str = json.dumps(trial_data, sort_keys=True)
    checksum = hashlib.md5(json_str.encode()).hexdigest()[:8]
    payload = f"{checksum}|{json_str}"
    
    # Encrypt
    encrypted = _xor_encrypt(payload.encode('utf-8'), combined_key)
    return base64.b64encode(encrypted).decode('ascii')

def _decrypt_trial_data(encrypted_str: str, location_hash: str) -> dict | None:
    """
    Decrypt trial data. Returns None if decryption fails or data is tampered.
    """
    try:
        # Combine app key with location hash
        app_key = _get_encryption_key()
        location_key = hashlib.sha256(location_hash.encode()).digest()
        combined_key = bytes([app_key[i] ^ location_key[i] for i in range(32)])
        
        # Decrypt
        encrypted = base64.b64decode(encrypted_str.encode('ascii'))
        decrypted = _xor_encrypt(encrypted, combined_key).decode('utf-8')
        
        # Verify integrity
        if '|' not in decrypted:
            return None
        checksum, json_str = decrypted.split('|', 1)
        
        # Verify checksum
        expected_checksum = hashlib.md5(json_str.encode()).hexdigest()[:8]
        if checksum != expected_checksum:
            return None  # Data was tampered with
        
        return json.loads(json_str)
    except Exception:
        return None  # Decryption failed

def validate_license(license_key: str, location_id: str) -> dict:
    """
    Validate a license key with LemonSqueezy.
    The license is bound to the GHL Location ID.
    
    Returns:
        dict with keys: valid, status, message, customer_name, customer_email, expires_at
    """
    result = {
        "valid": False,
        "status": "invalid",
        "message": "",
        "customer_name": "",
        "customer_email": "",
        "expires_at": "",
        "license_key": license_key,
        "location_id": location_id
    }
    
    if not license_key or not location_id:
        result["message"] = "License key and Location ID are required"
        return result
    
    instance_id = get_instance_id(location_id)
    
    try:
        # LemonSqueezy license validation endpoint
        response = requests.post(
            f"{LEMON_API_URL}/licenses/validate",
            json={
                "license_key": license_key,
                "instance_name": instance_id
            },
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json"
            },
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            
            # Check validation result
            if data.get("valid", False) or data.get("license_key", {}).get("status") == "active":
                license_data = data.get("license_key", data.get("data", {}))
                meta = data.get("meta", {})
                
                result["valid"] = True
                result["status"] = license_data.get("status", "active")
                result["message"] = "License is valid"
                result["customer_name"] = license_data.get("user_name", meta.get("customer_name", ""))
                result["customer_email"] = license_data.get("user_email", meta.get("customer_email", ""))
                result["expires_at"] = license_data.get("expires_at", "")
                result["activation_limit"] = license_data.get("activation_limit", 1)
                result["activation_usage"] = license_data.get("activation_usage", 0)
            else:
                result["message"] = data.get("error", "License validation failed")
                result["status"] = "invalid"
                
        elif response.status_code == 404:
            result["message"] = "License key not found"
            result["status"] = "not_found"
        elif response.status_code == 400:
            error_data = response.json()
            result["message"] = error_data.get("error", "Invalid license key format")
            result["status"] = "invalid"
        else:
            result["message"] = f"API error: {response.status_code}"
            result["status"] = "error"
            
    except requests.exceptions.Timeout:
        result["message"] = "Connection timeout - check internet"
        result["status"] = "timeout"
    except requests.exceptions.ConnectionError:
        result["message"] = "Connection failed - check internet"
        result["status"] = "connection_error"
    except Exception as e:
        result["message"] = f"Error: {str(e)}"
        result["status"] = "error"
    
    return result

def activate_license(license_key: str, location_id: str) -> dict:
    """
    Activate a license for this GHL Location ID.
    
    Returns:
        dict with keys: success, message, instance_id
    """
    result = {
        "success": False,
        "message": "",
        "instance_id": "",
        "activated_at": ""
    }
    
    if not license_key or not location_id:
        result["message"] = "License key and Location ID are required"
        return result
    
    instance_id = get_instance_id(location_id)
    instance_name = f"GHL-{location_id[:8]}"  # Friendly name for the instance
    
    try:
        response = requests.post(
            f"{LEMON_API_URL}/licenses/activate",
            json={
                "license_key": license_key,
                "instance_name": instance_name
            },
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json"
            },
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            
            if data.get("activated", False) or data.get("valid", False):
                result["success"] = True
                result["message"] = "License activated successfully"
                result["instance_id"] = data.get("instance", {}).get("id", instance_id)
                result["activated_at"] = datetime.now().isoformat()
            else:
                result["message"] = data.get("error", "Activation failed")
                
        elif response.status_code == 400:
            error_data = response.json()
            error_msg = error_data.get("error", "")
            
            # Handle specific errors
            if "activation limit" in error_msg.lower():
                result["message"] = "License activation limit reached. Deactivate another location first."
            elif "already activated" in error_msg.lower():
                result["success"] = True
                result["message"] = "License already activated for this location"
                result["instance_id"] = instance_id
            else:
                result["message"] = error_msg or "Activation failed"
        else:
            result["message"] = f"API error: {response.status_code}"
            
    except requests.exceptions.Timeout:
        result["message"] = "Connection timeout"
    except requests.exceptions.ConnectionError:
        result["message"] = "Connection failed"
    except Exception as e:
        result["message"] = f"Error: {str(e)}"
    
    return result

def deactivate_license(license_key: str, location_id: str, instance_id: str = "") -> dict:
    """
    Deactivate a license for this GHL Location ID.
    
    Returns:
        dict with keys: success, message
    """
    result = {
        "success": False,
        "message": ""
    }
    
    if not license_key:
        result["message"] = "License key is required"
        return result
    
    # Use provided instance_id or generate from location_id
    if not instance_id and location_id:
        instance_id = get_instance_id(location_id)
    
    try:
        response = requests.post(
            f"{LEMON_API_URL}/licenses/deactivate",
            json={
                "license_key": license_key,
                "instance_id": instance_id
            },
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json"
            },
            timeout=30
        )
        
        if response.status_code == 200:
            data = response.json()
            if data.get("deactivated", False):
                result["success"] = True
                result["message"] = "License deactivated successfully"
            else:
                result["message"] = data.get("error", "Deactivation failed")
        else:
            result["message"] = f"API error: {response.status_code}"
            
    except Exception as e:
        result["message"] = f"Error: {str(e)}"
    
    return result

def check_needs_validation(last_validated: str) -> dict:
    """
    Check if license needs re-validation (monthly requirement).
    
    Args:
        last_validated: ISO format datetime string of last validation
        
    Returns:
        dict with needs_validation (bool), days_since (int), message
    """
    result = {
        "needs_validation": True,
        "days_since": -1,
        "message": ""
    }
    
    if not last_validated or last_validated.strip() == "":
        result["message"] = "No previous validation - validation required"
        return result
    
    try:
        # Parse the last validation date
        last_date = datetime.fromisoformat(last_validated.replace("Z", "+00:00").replace(" ", "T"))
        if last_date.tzinfo:
            last_date = last_date.replace(tzinfo=None)
        
        now = datetime.now()
        days_since = (now - last_date).days
        
        result["days_since"] = days_since
        
        if days_since >= 30:
            result["needs_validation"] = True
            result["message"] = f"Last validated {days_since} days ago - monthly validation required"
        else:
            result["needs_validation"] = False
            days_until = 30 - days_since
            result["message"] = f"License valid. Next validation in {days_until} days"
            
    except Exception as e:
        result["message"] = f"Error parsing date: {str(e)} - validation required"
        result["needs_validation"] = True
    
    return result

def get_trial_info(location_id: str, trial_file: str | None = None) -> dict:
    """
    Get trial information for a Location ID.
    Trial is tied to Location ID hash to prevent reset by reinstall.
    Trial data is encrypted to prevent tampering.
    
    Args:
        location_id: The GHL Location ID
        trial_file: Optional path to trial data file (defaults to script dir)
        
    Returns:
        dict with trial_start, days_remaining, is_expired, location_hash
    """
    if not location_id:
        return {
            "success": False,
            "error": "Location ID required for trial",
            "message": "Please configure GHL Location ID first"
        }
    
    location_hash = get_instance_id(location_id)
    
    # Use encrypted trial data file in script directory
    if not trial_file:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        trial_file = os.path.join(script_dir, ".sidekick_trial.dat")
    
    trial_record = None
    
    # Load existing trial data (encrypted)
    if os.path.exists(trial_file):
        try:
            with open(trial_file, 'r') as f:
                encrypted_data = f.read().strip()
            # Decrypt using location hash
            trial_record = _decrypt_trial_data(encrypted_data, location_hash)
            # If decryption failed (wrong location or tampered), trial_record is None
        except:
            trial_record = None
    
    # Check if we have valid trial data for this location
    if trial_record and trial_record.get("location_hash") == location_hash:
        trial_start = trial_record["start"]
        trial_days = trial_record.get("days", 14)
    else:
        # Start new trial for this location (or data was tampered/wrong location)
        trial_start = datetime.now().strftime("%Y-%m-%d")
        trial_days = 14
        trial_record = {
            "start": trial_start,
            "days": trial_days,
            "location_hash": location_hash,
            "created": datetime.now().isoformat()
        }
        
        # Save encrypted trial data
        try:
            encrypted = _encrypt_trial_data(trial_record, location_hash)
            with open(trial_file, 'w') as f:
                f.write(encrypted)
        except Exception as e:
            return {
                "success": False,
                "error": f"Could not save trial data: {str(e)}"
            }
    
    # Calculate days remaining
    try:
        start_date = datetime.strptime(trial_start, "%Y-%m-%d")
        days_used = (datetime.now() - start_date).days
        days_remaining = max(0, trial_days - days_used)
        is_expired = days_remaining <= 0
    except:
        days_remaining = 0
        is_expired = True
    
    return {
        "success": True,
        "trial_start": trial_start,
        "trial_days": trial_days,
        "days_remaining": days_remaining,
        "is_expired": is_expired,
        "location_hash": location_hash,
        "message": f"Trial: {days_remaining} days remaining" if not is_expired else "Trial expired"
    }

def main():
    """
    CLI interface for license operations.
    
    Usage:
        python validate_license.py validate <license_key> <location_id>
        python validate_license.py activate <license_key> <location_id>
        python validate_license.py deactivate <license_key> <location_id> [instance_id]
        python validate_license.py check <last_validated_date>
        python validate_license.py trial <location_id>
    """
    if len(sys.argv) < 2:
        print(json.dumps({
            "error": "Usage: validate_license.py <action> [args...]",
            "actions": ["validate", "activate", "deactivate", "check", "trial"]
        }))
        sys.exit(1)
    
    action = sys.argv[1].lower()
    
    if action == "check":
        # Check if monthly validation is needed
        if len(sys.argv) < 3:
            print(json.dumps({
                "error": "Usage: validate_license.py check <last_validated_date>"
            }))
            sys.exit(1)
        last_validated = sys.argv[2]
        result = check_needs_validation(last_validated)
        print(json.dumps(result, indent=2))
        return
    
    if action == "trial":
        # Get/start trial for a location
        if len(sys.argv) < 3:
            print(json.dumps({
                "error": "Usage: validate_license.py trial <location_id>"
            }))
            sys.exit(1)
        location_id = sys.argv[2]
        result = get_trial_info(location_id)
        print(json.dumps(result, indent=2))
        return
    
    # All other actions require license_key and location_id
    if len(sys.argv) < 4:
        print(json.dumps({
            "error": "Usage: validate_license.py <action> <license_key> <location_id>",
            "actions": ["validate", "activate", "deactivate", "check", "trial"]
        }))
        sys.exit(1)
    
    license_key = sys.argv[2]
    location_id = sys.argv[3]
    instance_id = sys.argv[4] if len(sys.argv) > 4 else ""
    
    if action == "validate":
        result = validate_license(license_key, location_id)
    elif action == "activate":
        result = activate_license(license_key, location_id)
    elif action == "deactivate":
        result = deactivate_license(license_key, location_id, instance_id)
    else:
        result = {"error": f"Unknown action: {action}"}
    
    # Output JSON result
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
