# Getting Started

## 1. Connect a Reader

Open NekokoLPA2 and go to the main **Manage** screen. The app scans for enabled reader types and selects the first usable reader, or the last selected reader if it is still available.

Use the top-right controls to:

- refresh the reader list
- scan for Bluetooth readers
- connect a configured remote reader
- open settings
- toggle EID/ICCID redaction when profile data is shown

If no reader is found, check **Settings > Reader Types** and enable the reader paths you want to use.

## 2. Load Profiles

After selecting a reader, press **Connect** if profiles are not loaded automatically. NekokoLPA2 connects to the reader, opens an eUICC session, fetches the EID and card information, then lists installed profiles.

The profile list supports:

- profile name, nickname, ICCID, operator, class, and status display
- search by ICCID, name, nickname, service provider, MCC/MNC, or ISD-P AID
- sorting by ICCID, country, or nickname when configured in display settings
- waterfall or list-style layouts, depending on display settings

## 3. Enable or Disable a Profile

Use the switch on a profile card to enable or disable that profile. When enabling a profile, other enabled profiles on the same eUICC are treated as disabled in the refreshed app state.

The app waits for card refreshes and retries transient connection states during switching. Avoid unplugging the reader or closing the app until the profile list refreshes.

## 4. Install an eSIM Profile

Press **Download Profile** from the profile screen.

You can enter an activation code in several ways:

- paste a full `LPA:1$...` activation code
- type or edit the SM-DP+ address and matching ID fields
- scan a QR code on supported camera platforms
- select or drag an image containing a QR code

Press **Continue** to preview the profile metadata. The preview can show provider, ICCID, PLMN, storage information, and an estimated or returned profile size when available.

If the carrier requires a confirmation code, enter it when prompted. Press **Download** to install the profile. After installation, NekokoLPA2 can offer to enable the new profile immediately.

## 5. Batch Install Profiles

The app includes a batch download flow from the download menu. Paste up to 20 activation-code lines. NekokoLPA2 parses valid `LPA:1$...` lines, estimates total size when possible, installs each item in sequence, and leaves uncompleted items in the input field.

Batch processing stops early for likely storage or memory errors so you can free space or remove profiles before retrying.

## 6. Manage an Installed Profile

Open a profile's context menu by tapping, long-pressing, or right-clicking the profile card. Available actions include:

- view profile details
- rename the profile nickname
- change the icon from gallery, operator icon, or eSIM-provided icon when available
- manage text tags and date tags
- copy ICCID
- view usage data when locally cached usage exists
- delete the profile when it is disabled

Deletion is destructive and requires confirmation. Enabled profiles cannot be deleted from the menu until they are disabled.

## 7. Back Up Local App Data

NekokoLPA2 stores local metadata such as tags, custom icons, profile sizes, and cached status data in its database. Use **Settings > Database** to export or import this database. Desktop builds can also open the database folder directly.
