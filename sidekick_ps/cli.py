"""
CLI dispatcher for SideKick_PS unified package.

Routes subcommands to individual script modules.  Each script remains as a
standalone ``.py`` file in the project root for backwards compatibility;
the dispatcher simply imports the module and calls its ``main()``.

Usage (dev)::

    python -m sidekick_ps <command> [args...]

Usage (compiled)::

    SideKick_PS_CLI.exe <command> [args...]

Copyright (c) 2026 GuyMayer.  All rights reserved.
"""

from __future__ import annotations

import importlib
import os
import sys

# ---------------------------------------------------------------------------
# Subcommand → module-name mapping
# ---------------------------------------------------------------------------
COMMANDS: dict[str, str] = {
    "sync-invoice":        "sync_ps_invoice",
    "validate-license":    "validate_license",
    "create-contactsheet": "create_ghl_contactsheet",
    "upload-media":        "upload_ghl_media",
    "cardly-preview":      "cardly_preview_gui",
    "cardly-send":         "cardly_send_card",
    "write-psa":           "write_psa_payments",
    "read-psa":            "read_psa_payments",
    "read-psa-images":     "read_psa_images",
}

# Commands that launch a GUI – the console window is hidden on startup so
# it doesn't flash behind the Qt/tkinter window.
_GUI_COMMANDS: set[str] = {"cardly-preview"}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _hide_console() -> None:
    """Hide the console window on Windows (for GUI sub-commands)."""
    try:
        import ctypes
        hwnd = ctypes.windll.kernel32.GetConsoleWindow()  # type: ignore[attr-defined]
        if hwnd:
            ctypes.windll.user32.ShowWindow(hwnd, 0)  # SW_HIDE
    except Exception:
        pass


def _ensure_script_path() -> None:
    """Make sure the directory containing the standalone ``.py`` scripts is
    importable.

    *  **Dev mode** — scripts live in the parent of ``sidekick_ps/``.
    *  **Frozen** (PyInstaller ``--onefile``) — scripts are bundled via
       ``--hidden-import`` and already importable.
    """
    if not getattr(sys, "frozen", False):
        scripts_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if scripts_dir not in sys.path:
            sys.path.insert(0, scripts_dir)


def _print_help() -> None:
    """Print usage information and the list of available commands."""
    from . import __app_name__, __version__

    print(f"{__app_name__} CLI  v{__version__}")
    print()
    print("Usage:  SideKick_PS_CLI <command> [args ...]")
    print()
    print("Commands:")
    for cmd in sorted(COMMANDS):
        print(f"  {cmd:<24s}  ({COMMANDS[cmd]}.py)")
    print()
    print("Pass '<command> --help' for command-specific options.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:                       # noqa: C901 – intentionally flat
    """Parse the first positional arg as a subcommand and dispatch."""
    _ensure_script_path()

    # -- No subcommand / help -------------------------------------------------
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        _print_help()
        sys.exit(0)

    if sys.argv[1] == "--version":
        from . import __version__
        print(__version__)
        sys.exit(0)

    command = sys.argv[1]

    # -- Unknown command -------------------------------------------------------
    if command not in COMMANDS:
        print(f"ERROR: Unknown command '{command}'", file=sys.stderr)
        print("Run with --help to see available commands.", file=sys.stderr)
        sys.exit(1)

    # -- Hide console for GUI commands ----------------------------------------
    if command in _GUI_COMMANDS:
        _hide_console()

    # -- Rewrite sys.argv so the target script sees only its own arguments ----
    #    ["SideKick_PS_CLI.exe", "sync-invoice", "--financials-only"]
    #  → ["sync_ps_invoice.py", "--financials-only"]
    module_name = COMMANDS[command]
    sys.argv = [module_name + ".py"] + sys.argv[2:]

    # -- Lazy-import the target module and call main() ------------------------
    module = importlib.import_module(module_name)
    result = module.main()

    # Some scripts (e.g. cardly_send_card) return an integer exit code.
    if isinstance(result, int):
        sys.exit(result)
