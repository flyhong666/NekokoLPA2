# NekokoLPA2
[![Crowdin](https://badges.crowdin.net/nekokolpa2/localized.svg)](https://crowdin.com/project/nekokolpa2)


[![Download on the App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?logo=appstore&logoColor=white&style=for-the-badge)](https://apps.apple.com/en/app/nekokolpa-2/id6757540723)
[![Get it on Google Play](https://img.shields.io/badge/Google%20Play-Download-34A853?logo=googleplay&logoColor=white&style=for-the-badge)](https://play.google.com/store/apps/details?id=ee.nekoko.nlpa)


**Language:** **English** | [日本語](./README_ja-JP.md)


NekokoLPA2 is a cross-platform eSIM management app for working with local eUICCs, external readers, and remote reader endpoints. It is designed for users who need more control over profile operations, transport choices, and card visibility than a typical carrier app exposes.

## Highlights

- Works across Android, iOS, macOS, Linux, Windows, and Chrome
- Supports BLE readers, USB CCID readers, OMAPI, Telephony/TMAPI, remote readers, and browser-side WebUSB paths
- Includes profile organization tools such as custom icons, notes, tags, and scheduled notifications
- On rooted Android devices, `OTBridge` can enable Telephony support and help bypass OMAPI ARA-M restrictions without requiring NekokoLPA2 itself to be installed as a privileged app

## Platform Support

| Connection Type | Android | iOS | macOS | Linux | Windows | Chrome |
| --- | --- | --- | --- | --- | --- | --- |
| BLE readers | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| USB CCID readers | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Remote readers | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| OMAPI | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Telephony / TMAPI | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `OTBridge` provider | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| WebUSB SCRP / WebCard | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

Notes:
- `Telephony / TMAPI` and `OTBridge` are Android-only paths.
- `OTBridge` is intended for rooted Android setups where Telephony access or OMAPI policy bypass is needed.
- Chrome support refers to the web build running in a Chromium browser with the required browser APIs available.

## Translation

Translations are managed on [Crowdin](https://crowdin.com/project/nekokolpa2).


## Features

- **Multi-reader support**: BLE, USB CCID, OMAPI, Telephony API, remote readers, and browser-based transports
- **Rooted Android path**: `OTBridge` can enable Telephony support and bypass OMAPI ARA-M restrictions while keeping the main app unprivileged
- **Profile organization**: Custom icons, notes, tags, and compact management tools
- **Scheduled notifications**: Reminders for expiry and other profile-related events
- **Cross-platform UI**: Responsive layout with platform-aware reader flows

## Android Notes

- NekokoLPA2 prefers the external `OTBridge` provider on Android when it is installed.
- On rooted Android devices, `OTBridge` can expose Telephony/TMAPI access and help bypass OMAPI ARA-M restrictions while keeping NekokoLPA2 itself on the normal app path.
- `OTBridge` releases are available at: [iebb/OTBridge](https://github.com/iebb/OTBridge/releases)

## Download

- [![Download on the App Store](https://img.shields.io/badge/App%20Store-Download-0D96F6?logo=appstore&logoColor=white&style=for-the-badge)](https://apps.apple.com/en/app/nekokolpa-2/id6757540723)
- [![Get it on Google Play](https://img.shields.io/badge/Google%20Play-Download-34A853?logo=googleplay&logoColor=white&style=for-the-badge)](https://play.google.com/store/apps/details?id=ee.nekoko.nlpa)
- **GitHub Releases**: [iebb/NekokoLPA2 releases](https://github.com/iebb/NekokoLPA2/releases)
- **TestFlight**: [Join TestFlight](https://testflight.apple.com/join/bP38fzC4)
- **Web**: [web.lpa.ee](https://web.lpa.ee)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history and user-facing changes.

## Support

For issues, feature requests, or questions, please visit our [GitHub Issues](https://github.com/iebb/NekokoLPA2/issues).

## License

Proprietary - Source code not publicly available at the moment, due to the complexity of the codebase and the fact that it is a work in progress. It's planned to switch to open source in the coming months.

---

© 2026 Nekoko. All rights reserved.
