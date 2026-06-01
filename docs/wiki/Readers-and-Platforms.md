# Readers and Platforms

## Reader Types

NekokoLPA2 discovers readers through a composite adapter. The reader types available in the UI depend on platform, build flags, installed providers, and settings.

### USB CCID

USB CCID readers are available on non-web platforms where the CCID connector is enabled. Desktop platforms can use supported smart-card reader paths, and mobile platforms can use compatible USB readers when the OS grants access.

### Bluetooth

Bluetooth readers are available when the Bluetooth connector is enabled. Linux hides the Bluetooth connector in the current reader-type settings page.

On web builds, Bluetooth scanning uses the browser path. On native builds, the app opens a Bluetooth scan dialog.

### Remote Readers

Remote readers use the RemoCard adapter. Enable **Remote Readers** in **Settings > Reader Types**, then configure servers in **Remote Server Configuration**.

The remote configuration page supports:

- HTTP and HTTPS
- host and port input
- optional per-server password
- default password for URLs without embedded passwords
- auto-load remote devices
- copy and remove configured URLs

### Android OMAPI

OMAPI is available on Android when the connector is enabled and the OS/security policy allows APDU access. If the card or OS denies access, the app can show an access-denied or ARA-M-related state.

### Telephony/TMAPI and OTBridge

Telephony/TMAPI is Android-specific. In public builds, users normally rely on supported providers such as OTBridge when available. The settings page shows an OTBridge hint on rooted Android devices and reports whether the provider is available.

### Browser WebUSB Paths

The web build supports browser-side reader paths such as WebUSB SCRP or WebCard when the browser exposes the required APIs. Chrome or Chromium-based browsers are the intended target.

## Platform Notes

| Platform | Notes |
| --- | --- |
| Android | Supports OMAPI and OTBridge-style Android reader paths. Bluetooth and USB availability depends on device permissions and hardware. |
| iOS | Supports app-level reader paths such as BLE, USB CCID where available, and remote readers. |
| macOS | Supports desktop flows including CCID, BLE, remote readers, QR/image import, and database folder access. |
| Linux | Supports CCID and remote readers. Bluetooth and local notifications are limited in the current UI. |
| Windows | Supports CCID, BLE, and remote readers. QR camera scanning is hidden, but QR image decoding is available through the image path. |
| Web/Chrome | Supports browser reader paths and remote readers where enabled. Native-only settings and camera/image capabilities vary by browser. |

## Common Reader States

NekokoLPA2 uses dedicated states for common reader conditions:

- **Not connected**: the reader exists but profiles have not been loaded yet.
- **No card detected**: the secure element is absent or the reader reports no card.
- **Card unsupported**: the selected AID or eUICC application is not available.
- **Access denied**: Android OMAPI or access-control policy denied APDU access.
- **Bluetooth connection failed**: a BLE reader is saved or selected but not currently connected.
- **Remote reader connection failed**: the remote server cannot be reached or authenticated.

Use refresh, reconnect, reader settings, or remote settings depending on the state shown.
