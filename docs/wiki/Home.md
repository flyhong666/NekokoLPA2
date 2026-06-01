# NekokoLPA2 Wiki

This wiki describes the current NekokoLPA2 app behavior from the public Flutter codebase. It focuses on everyday use, supported reader paths, and the features exposed in the app UI.

## Pages

- [Getting Started](Getting-Started.md): connect a reader, load profiles, install an eSIM, and manage an installed profile.
- [Features](Features.md): profile management, downloads, tags, reminders, redaction, notifications, and database tools.
- [Readers and Platforms](Readers-and-Platforms.md): supported reader types and platform notes.
- [Troubleshooting](Troubleshooting.md): common connection, card, download, and notification problems.

## Quick Summary

NekokoLPA2 is a cross-platform eSIM management app for local and remote eUICC access. The main app screen lists available readers, loads profiles from the selected reader, and lets you enable, disable, rename, tag, install, and delete profiles.

The app supports multiple transport paths:

- USB CCID and PC/SC-style smart-card readers
- Bluetooth readers
- Remote readers through the RemoCard protocol
- Android OMAPI readers
- Android Telephony/TMAPI paths through privileged support or OTBridge-style providers
- Browser-side WebUSB paths for supported web environments

The app also keeps local metadata such as tags, custom icons, profile size estimates, notification history, and redaction settings in its local database.
