"""
SideKick_PS — Unified Python package for ProSelect SideKick.
Copyright (c) 2026 GuyMayer. All rights reserved.
Unauthorized use, modification, or distribution is prohibited.

This package consolidates all Python scripts that SideKick_PS uses into
a single importable namespace.  When compiled with PyInstaller it produces
one exe (``SideKick_PS_CLI.exe``) with subcommands instead of 11 separate
executables.

Usage (dev):
    python -m sidekick_ps <command> [args...]

Usage (compiled):
    SideKick_PS_CLI.exe <command> [args...]
"""

__app_name__ = "SideKick_PS"
__version__ = "1.1.0"
