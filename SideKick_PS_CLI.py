#!/usr/bin/env python3
"""
Top-level launcher for PyInstaller single-exe builds.

Compile with::

    pyinstaller --onefile --console --name SideKick_PS_CLI ^
        --hidden-import=sync_ps_invoice    ^
        --hidden-import=validate_license   ^
        --hidden-import=create_ghl_contactsheet ^
        --hidden-import=upload_ghl_media   ^
        --hidden-import=gocardless_api     ^
        --hidden-import=cardly_preview_gui ^
        --hidden-import=cardly_send_card   ^
        --hidden-import=write_psa_payments ^
        --hidden-import=read_psa_payments  ^
        --hidden-import=read_psa_images    ^
        --hidden-import=stale_mandates_gui ^
        --hidden-import=PySide6.QtWidgets  ^
        --hidden-import=PySide6.QtCore     ^
        --hidden-import=PySide6.QtGui      ^
        SideKick_PS_CLI.py

Copyright (c) 2026 GuyMayer.  All rights reserved.
"""

from sidekick_ps.cli import main

if __name__ == "__main__":
    main()
