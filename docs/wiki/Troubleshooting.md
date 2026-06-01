# Troubleshooting

## No Reader Appears

Check **Settings > Reader Types** and enable the connector you want to use. Then return to the Manage screen and press refresh.

For Bluetooth readers, press the Bluetooth scan button. For remote readers, configure at least one server under **Remote Server Configuration** and press the remote-reader button.

## Bluetooth Reader Will Not Connect

Make sure Bluetooth is enabled and the reader is powered on. If the app shows a Bluetooth connection error, use **Connect** or scan again. Removing and re-adding the reader can clear a stale saved device.

## Remote Reader Connection Failed

Open **Settings > Reader Types > Remote Server Configuration** and verify:

- host or full URL
- port, usually `33777` for RemoCard
- HTTP versus HTTPS
- per-server password or default password
- network reachability between the app and remote reader

The app validates a server by calling the remote reader list endpoint before saving it.

## Android OMAPI Shows Access Denied

This usually means the Android secure-element access policy does not allow the app to open the required channel. On rooted Android setups, OTBridge may provide Telephony support or help with OMAPI ARA-M restrictions. The settings page shows an OTBridge status hint when root is detected.

## Card Unsupported or Empty

`Card Unsupported` can mean the expected eUICC application or AID is unavailable. If the card is an eSTK card with multiple slots, try the eSTK slot switch action when it is shown.

`No Profiles on Card` means the profile list succeeded but returned no installed profiles.

## Download Profile Fails

Check the activation code first:

- full code should start with `LPA:1$`
- SM-DP+ address must be a valid domain name
- matching ID may contain uppercase letters, digits, and hyphens
- confirmation code is required only when the carrier requires one

If the preview succeeds but installation fails, check remaining eUICC storage, network access to the SM-DP+ server, and whether the card is busy refreshing from a previous operation.

## Batch Download Stops Early

Batch download stops on likely storage or memory errors. Delete unused disabled profiles, refresh the profile list, then retry the remaining activation codes that were left in the batch input field.

## Delete Is Disabled

The delete action is only enabled for disabled profiles. Disable the profile first, wait for the refreshed profile list, then open the profile menu again.

## Tags Do Not Save

Tags are saved by renaming the profile nickname on the eUICC, then mirroring the parsed tags into the local metadata database. If saving fails, reconnect the reader and try again. On date-tag changes, the app may also ask whether to schedule, reschedule, or remove a reminder.

## Notifications Do Not Appear

Open **Settings > Tags & Reminders** and check notification permission. Use the test notification action to verify delivery. Linux notification permission checking is currently treated as unsupported in this settings flow.

For eUICC notifications, check notification processing settings. Developer mode exposes more controls for when install, enable, disable, and delete notifications are sent or removed.

## Sensitive Data Is Visible

Open **Settings > Redaction** to hide or partially redact EID, ICCID, nickname, operator, tags, icons, and flags. The Manage screen also has a quick visibility toggle when identifier data is present.
