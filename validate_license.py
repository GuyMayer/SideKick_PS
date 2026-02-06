"""
SideKick_PS License Validation
Validates license keys against LemonSqueezy API with location ID binding.
"""

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


def get_instance_id(location_id: str) -> str:
    """
    Generate a unique instance identifier based on GHL Location ID.
    This ties the license to a specific GHL location.
    """
    # Hash the location ID to create a consistent instance identifier
    instance = hashlib.sha256(f"sidekick_ps_{location_id}".encode()).hexdigest()[:32]
    return instance


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

def _print_usage_error(message: str) -> None:
    """Print usage error and exit.

    Args:
        message: Error message to print.
    """
    print(json.dumps({"error": message, "actions": ["validate", "activate", "deactivate", "check"]}))
    sys.exit(1)


def _handle_check_action() -> dict:
    """Handle 'check' CLI action."""
    if len(sys.argv) < 3:
        _print_usage_error("Usage: validate_license.py check <last_validated_date>")
    return check_needs_validation(sys.argv[2])


def _handle_license_action(action: str) -> dict:
    """Handle license-based CLI actions.

    Args:
        action: Action name (validate, activate, deactivate).

    Returns:
        dict: Result of the action.
    """
    if len(sys.argv) < 4:
        _print_usage_error("Usage: validate_license.py <action> <license_key> <location_id>")

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
    """
    CLI interface for license operations.

    Usage:
        python validate_license.py validate <license_key> <location_id>
        python validate_license.py activate <license_key> <location_id>
        python validate_license.py deactivate <license_key> <location_id> [instance_id]
        python validate_license.py check <last_validated_date>
    """
    if len(sys.argv) < 2:
        _print_usage_error("Usage: validate_license.py <action> [args...]")

    action = sys.argv[1].lower()

    if action == "check":
        result = _handle_check_action()
    else:
        result = _handle_license_action(action)

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
