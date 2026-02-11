"""
SideKick License Validation Module
Copyright (c) 2026 GuyMayer. All rights reserved.
Unauthorized use, modification, or distribution is prohibited.
"""

import base64
import hashlib
import json
import os
import sys
from datetime import datetime

import requests

# LemonSqueezy API Configuration
LEMON_API_URL = "https://api.lemonsqueezy.com/v1"
STORE_ID = "zoomphoto"
PRODUCT_ID = "077d6b76-ca2a-42df-a653-86f7aa186895"


def _get_data_dir():
    """Get a writable directory for data files (trial data, etc.)."""
    appdata = os.environ.get('APPDATA')
    if appdata:
        sidekick_dir = os.path.join(appdata, 'SideKick_PS')
        try:
            os.makedirs(sidekick_dir, exist_ok=True)
            return sidekick_dir
        except OSError:
            pass
    return os.environ.get('TEMP', os.path.dirname(os.path.abspath(__file__)))


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


def _init_validation_result(license_key: str, location_id: str) -> dict:
    """Initialize a validation result dictionary.

    Args:
        license_key: License key.
        location_id: GHL Location ID.

    Returns:
        dict: Initial result with default values.
    """
    return {
        "valid": False,
        "status": "invalid",
        "message": "",
        "customer_name": "",
        "customer_email": "",
        "expires_at": "",
        "license_key": license_key,
        "location_id": location_id
    }


def _extract_license_data(data: dict, result: dict) -> None:
    """Extract license data from API response into result.

    Args:
        data: API response data.
        result: Result dict to update in place.
    """
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


def _handle_validation_error(response, result: dict) -> None:
    """Handle non-200 validation responses.

    Args:
        response: HTTP response object.
        result: Result dict to update in place.
    """
    if response.status_code == 404:
        result["message"] = "License key not found"
        result["status"] = "not_found"
    elif response.status_code == 400:
        error_data = response.json()
        result["message"] = error_data.get("error", "Invalid license key format")
        result["status"] = "invalid"
    else:
        result["message"] = f"API error: {response.status_code}"
        result["status"] = "error"


def _handle_request_exception(exception: Exception, result: dict) -> None:
    """Handle exceptions during API requests.

    Args:
        exception: The exception that occurred.
        result: Result dict to update.
    """
    if isinstance(exception, requests.exceptions.Timeout):
        result["message"] = "Connection timeout - check internet"
        result["status"] = "timeout"
    elif isinstance(exception, requests.exceptions.ConnectionError):
        result["message"] = "Connection failed - check internet"
        result["status"] = "connection_error"
    else:
        result["message"] = f"Error: {str(exception)}"
        result["status"] = "error"


def validate_license(license_key: str, location_id: str) -> dict:
    """
    Validate a license key with LemonSqueezy.
    The license is bound to the GHL Location ID.

    Returns:
        dict with keys: valid, status, message, customer_name, customer_email, expires_at
    """
    result = _init_validation_result(license_key, location_id)

    if not license_key or not location_id:
        result["message"] = "License key and Location ID are required"
        return result

    instance_id = get_instance_id(location_id)

    try:
        response = requests.post(
            f"{LEMON_API_URL}/licenses/validate",
            data={"license_key": license_key, "instance_name": instance_id},
            headers={"Accept": "application/json"},
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            is_valid = data.get("valid", False) or data.get("license_key", {}).get("status") == "active"
            if is_valid:
                _extract_license_data(data, result)
            else:
                result["message"] = data.get("error", "License validation failed")
                result["status"] = "invalid"
        else:
            _handle_validation_error(response, result)
    except Exception as e:
        _handle_request_exception(e, result)

    return result

def _handle_activation_400(error_msg: str, instance_id: str, result: dict) -> None:
    """Handle 400 response for activation.

    Args:
        error_msg: Error message from API.
        instance_id: Instance ID.
        result: Result dict to update.
    """
    if "activation limit" in error_msg.lower():
        result["message"] = "License activation limit reached. Deactivate another location first."
    elif "already activated" in error_msg.lower():
        result["success"] = True
        result["message"] = "License already activated for this location"
        result["instance_id"] = instance_id
    else:
        result["message"] = error_msg or "Activation failed"


def _handle_activation_success(data: dict, instance_id: str, result: dict) -> None:
    """Handle successful activation response.

    Args:
        data: Response data from API.
        instance_id: Default instance ID.
        result: Result dict to update.
    """
    if data.get("activated", False) or data.get("valid", False):
        result["success"] = True
        result["message"] = "License activated successfully"
        result["instance_id"] = data.get("instance", {}).get("id", instance_id)
        result["activated_at"] = datetime.now().isoformat()
    else:
        result["message"] = data.get("error", "Activation failed")


def activate_license(license_key: str, location_id: str) -> dict:
    """
    Activate a license for this GHL Location ID.

    Returns:
        dict with keys: success, message, instance_id
    """
    result = {"success": False, "message": "", "instance_id": "", "activated_at": ""}

    if not license_key or not location_id:
        result["message"] = "License key and Location ID are required"
        return result

    instance_id = get_instance_id(location_id)
    instance_name = f"GHL-{location_id[:8]}"

    try:
        response = requests.post(
            f"{LEMON_API_URL}/licenses/activate",
            data={"license_key": license_key, "instance_name": instance_name},
            headers={"Accept": "application/json"},
            timeout=30
        )

        if response.status_code == 200:
            _handle_activation_success(response.json(), instance_id, result)
        elif response.status_code == 400:
            _handle_activation_400(response.json().get("error", ""), instance_id, result)
        else:
            result["message"] = f"API error: {response.status_code}"
    except Exception as e:
        _handle_request_exception(e, result)

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
        # LemonSqueezy requires form data, not JSON
        response = requests.post(
            f"{LEMON_API_URL}/licenses/deactivate",
            data={
                "license_key": license_key,
                "instance_id": instance_id
            },
            headers={
                "Accept": "application/json"
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

def _load_trial_record(trial_file: str, location_hash: str) -> dict | None:
    """Load and decrypt trial record from file.

    Args:
        trial_file: Path to trial data file.
        location_hash: Hash to use for decryption.

    Returns:
        dict or None: Trial record if successful.
    """
    if not os.path.exists(trial_file):
        return None
    try:
        with open(trial_file, 'r', encoding='utf-8') as f:
            encrypted_data = f.read().strip()
        return _decrypt_trial_data(encrypted_data, location_hash)
    except Exception:
        return None


def _create_new_trial(location_hash: str, trial_file: str) -> tuple[dict | None, str]:
    """Create and save a new trial record.

    Args:
        location_hash: Hash for encryption.
        trial_file: Path to save trial data.

    Returns:
        tuple: (error_dict or None, trial_start date string)
    """
    trial_start = datetime.now().strftime("%Y-%m-%d")
    trial_record = {
        "start": trial_start,
        "days": 14,
        "location_hash": location_hash,
        "created": datetime.now().isoformat()
    }

    try:
        encrypted = _encrypt_trial_data(trial_record, location_hash)
        with open(trial_file, 'w', encoding='utf-8') as f:
            f.write(encrypted)
        return None, trial_start
    except Exception as e:
        return {"success": False, "error": f"Could not save trial data: {str(e)}"}, ""


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
        return {"success": False, "error": "Location ID required for trial", "message": "Please configure GHL Location ID first"}

    location_hash = get_instance_id(location_id)

    if not trial_file:
        trial_file = os.path.join(_get_data_dir(), ".sidekick_trial.dat")

    trial_record = _load_trial_record(trial_file, location_hash)

    if trial_record and trial_record.get("location_hash") == location_hash:
        trial_start = trial_record["start"]
        trial_days = trial_record.get("days", 14)
    else:
        error, trial_start = _create_new_trial(location_hash, trial_file)
        if error:
            return error
        trial_days = 14

    try:
        start_date = datetime.strptime(trial_start, "%Y-%m-%d")
        days_used = (datetime.now() - start_date).days
        days_remaining = max(0, trial_days - days_used)
        is_expired = days_remaining <= 0
    except Exception:
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

def _print_usage_error(message: str) -> None:
    """Print usage error and exit.

    Args:
        message: Error message to print.
    """
    print(json.dumps({"error": message, "actions": ["validate", "activate", "deactivate", "check", "trial"]}))
    sys.exit(1)


def _handle_check_action() -> dict:
    """Handle 'check' CLI action."""
    if len(sys.argv) < 3:
        _print_usage_error("Usage: validate_license.py check <last_validated_date>")
    return check_needs_validation(sys.argv[2])


def _handle_trial_action() -> dict:
    """Handle 'trial' CLI action."""
    if len(sys.argv) < 3:
        _print_usage_error("Usage: validate_license.py trial <location_id>")
    return get_trial_info(sys.argv[2])


def _handle_license_action(action: str) -> dict:
    """Handle license-based CLI actions.

    Args:
        action: Action name (validate, activate, deactivate).

    Returns:
        dict: Result of the action.
    """
    if len(sys.argv) < 4:
        _print_usage_error("Invalid arguments")

    license_key = sys.argv[2]
    location_id = sys.argv[3]
    instance_id = sys.argv[4] if len(sys.argv) > 4 else ""

    actions = {
        "validate": lambda: validate_license(license_key, location_id),
        "activate": lambda: activate_license(license_key, location_id),
        "deactivate": lambda: deactivate_license(license_key, location_id, instance_id),
    }
    return actions.get(action, lambda: {"error": f"Unknown action: {action}"})()


def main():
    """CLI interface for license operations."""
    if len(sys.argv) < 2:
        _print_usage_error("Invalid arguments")

    action = sys.argv[1].lower()

    if action == "check":
        result = _handle_check_action()
    elif action == "trial":
        result = _handle_trial_action()
    else:
        result = _handle_license_action(action)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
