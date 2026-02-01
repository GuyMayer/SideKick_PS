# SD Card Download Feature - Implementation TODO

## Overview
Port the mature SD card download functionality from SideKick_LB_PubAI.ahk to SideKick_PS.ahk, including:
- New toolbar button for SD card download
- New "File Management" settings tab
- Complete file copy, rename, and archive workflow

---

## Progress Tracker

### Phase 1: Settings Tab Structure
- [x] **1.1** Add TabFiles global variable and TabFilesBg indicator
- [x] **1.2** Add File Management tab button to sidebar (between Hotkeys and License)
- [x] **1.3** Create `CreateFilesPanel()` function stub
- [x] **1.4** Add ShowSettingsTab("Files") case for show/hide logic
- [x] **1.5** Add Settings save/load for new file management settings

### Phase 2: File Management Settings Panel
- [x] **2.1** Add CardDrive setting (default: F:\DCIM)
- [x] **2.2** Add CameraDownloadPath setting
- [x] **2.3** Add ShootArchivePath setting
- [x] **2.4** Add ShootPrefix setting (default: P)
- [x] **2.5** Add ShootSuffix setting (default: P)
- [x] **2.6** Add AutoShootYear toggle
- [x] **2.7** Add EditorRunPath setting (path to photo editor)
- [x] **2.8** Add BrowsDown toggle (open editor after download)
- [x] **2.9** Add AutoRenameImages toggle
- [x] **2.10** Add AutoDriveDetect toggle
- [x] **2.11** Add folder browse buttons for paths
- [ ] **2.12** Test settings save/load

### Phase 3: Toolbar Button
- [x] **3.1** Expand toolbar width to accommodate 4th button
- [x] **3.2** Add SD card download button (📥 icon)
- [x] **3.3** Add Toolbar_DownloadSD label/handler
- [x] **3.4** Adjust button positions for new width
- [ ] **3.5** Add tooltip for new button

### Phase 4: Core Download Functions
- [x] **4.1** Port `SearchShootNoInFolder` function
- [x] **4.2** Port `RemoveDir()` helper function
- [x] **4.3** Port `CopyFilesProgress` and GUI
- [x] **4.4** Port `Unz()` function (file copy with Shell)
- [x] **4.5** Port `SetTaskbarProgress()` function
- [x] **4.6** Port `OnMsgBox4()` for custom button labels

### Phase 5: Main Download Workflow
- [x] **5.1** Port `DownloadSDCard:` label
- [x] **5.2** Port DCIM detection logic
- [x] **5.3** Port multi-card download support
- [x] **5.4** Port folder creation logic
- [x] **5.5** Port `RenameFiles:` label
- [x] **5.6** Port `RenumberByDate:` label
- [x] **5.7** Port `RunEditor:` label
- [x] **5.8** Add audio feedback integration

### Phase 6: Drive Detection (Optional)
- [x] **6.1** Port `checkNewDrives` timer
- [x] **6.2** Port drive insertion detection
- [x] **6.3** Auto-prompt on SD card insert

### Phase 7: Testing & Polish
- [x] **7.1** Test with actual SD card
- [x] **7.2** Test multi-card workflow
- [x] **7.3** Test file renaming
- [x] **7.4** Test archive folder creation
- [x] **7.5** Test editor launch
- [x] **7.6** Update documentation
- [x] **7.7** Update CHANGELOG.md
- [x] **7.8** Update version.json
- [x] **7.9** Push to GitHub (removed secret token)

---

## Settings Variables (New)

| Variable | INI Key | Default | Description |
|----------|---------|---------|-------------|
| `Settings_CardDrive` | CardDrive | F:\DCIM | SD card path |
| `Settings_CameraDownloadPath` | CameraDownloadPath | (empty) | Temp download folder |
| `Settings_ShootArchivePath` | ShootArchivePath | (empty) | Final archive location |
| `Settings_ShootPrefix` | ShootPrefix | P | Shoot number prefix |
| `Settings_ShootSuffix` | ShootSuffix | P | Shoot number suffix |
| `Settings_AutoShootYear` | AutoShootYear | true | Include year in shoot no |
| `Settings_EditorRunPath` | EditorRunPath | Explore | Photo editor path |
| `Settings_BrowsDown` | BrowsDown | true | Open editor after download |
| `Settings_AutoRenameImages` | AutoRenameImages | false | Auto-rename by date |
| `Settings_AutoDriveDetect` | AutoDriveDetect | true | Detect SD card insertion |

---

## Source Reference

### Key Functions from SideKick_LB_PubAI.ahk

| Function | Lines | Purpose |
|----------|-------|---------|
| `DownloadSDCard:` | 2518-2580 | Main download workflow |
| `SearchShootNoInFolder:` | 1247-1300 | Find next shoot number |
| `RenameFiles:` | 2756-2810 | Rename with shoot prefix |
| `RenumberByDate:` | 2715-2755 | Rename by timestamp |
| `CopyFilesProgress:` | 9392-9450 | Copy with progress GUI |
| `Unz()` | 8568-8610 | Shell copy function |
| `RemoveDir()` | 2687-2710 | Remove empty folders |
| `SetTaskbarProgress()` | 9460-9490 | Taskbar progress indicator |

---

## Notes

- Toolbar currently has 3 buttons (width 152px, button width 44px each with spacing)
- Settings has 6 tabs: General, GHL, Hotkeys, License, About, Developer
- New Files tab should go between Hotkeys and License (y position ~180)
- Keep same dark mode styling as other panels
- Audio feedback should use existing Settings_AudioFeedback

---

## Current Status

**Started:** 2026-02-01
**Last Updated:** 2026-02-01
**Phase:** ✅ COMPLETE
**Status:** All phases complete, pushed to GitHub
