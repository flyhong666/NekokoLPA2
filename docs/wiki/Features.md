# Features

## Profile Management

NekokoLPA2 can list profiles from a selected eUICC and perform common ES10 operations through the active reader:

- load installed profiles
- enable and disable profiles
- delete disabled profiles
- rename profile nicknames
- show EID and eUICC information
- copy ICCID and EID values
- switch eSTK slots on supported cards

The UI stores per-reader state, so switching between readers preserves loaded profile lists, EIDs, errors, and loading state where possible.

## Profile Download

The download flow supports activation-code entry, QR scanning, image decoding, metadata preview, confirmation-code handling, download progress, and post-install profile-size tracking.

Supported input methods include:

- full `LPA:1$SM-DP+$MATCHING-ID` strings
- split SM-DP+ and matching ID fields
- optional SM-DP+ OID display when present
- carrier confirmation code input when required
- clipboard paste
- QR camera scan on supported platforms
- QR image import and drag-and-drop

After installation, NekokoLPA2 records measured storage consumption when the eUICC exposes enough before/after data.

## Batch Download

Batch download accepts multiple activation-code lines and installs them sequentially. The current implementation caps parsing at 20 valid activation codes per batch and keeps unfinished or failed codes in the input field for retry.

The batch flow also exports results and stops on likely insufficient-space errors.

## Tags and Reminders

Profiles can have text tags and one date tag. Tags are encoded into the profile nickname and also mirrored into the local metadata database.

Date tags can schedule local reminders when reminders are enabled. The app can:

- prompt to schedule a reminder when a date tag is added
- prompt to reschedule when a date tag changes
- prompt to remove a reminder when a date tag is removed
- show scheduled reminders
- test local notification delivery
- show notification history

Linux notification permission checking is treated as unsupported in the current settings page.

## Profile Icons and Metadata

Profile cards can show:

- eSIM-provided profile icons
- local custom icons
- remote operator icons
- country flags derived from MCC/MNC and ICCID data
- operator summaries
- phone number, balance, line expiry, and package usage when plugin or cached data provides it

Icon loading can be disabled in settings.

## Redaction and Privacy Display

The redaction settings page controls what the app reveals on screen. It supports EID and ICCID segment redaction plus profile-content redaction for:

- nickname
- operator display
- tags
- icons
- flags

The profile screen has a quick visibility toggle when identifiers are visible or a card error state exposes related data.

## Reader Configuration

The reader settings page lets users enable or disable connector families:

- USB CCID
- Bluetooth
- Remote readers
- Android OMAPI
- Telephony/TMAPI where supported by the build and platform

Remote reader settings support HTTP or HTTPS host/port entries, per-server passwords, a default password, auto-load behavior, and a link to RemoCard releases.

## Notifications

NekokoLPA2 can process pending eUICC notifications around profile lifecycle actions. Settings include processing before download, after install, after switch, after deletion, and during initial load. Developer mode exposes more notification-processing controls.

## Display and Developer Tools

Display settings include:

- theme mode
- profile search visibility
- profile sort mode and sort direction
- waterfall layout
- size units
- profile-size estimation
- phone-number formatting
- browser tab enablement where supported

Developer mode exposes debug-oriented controls such as ASN.1 decoding, logs, database reset, and APDU transport settings.
