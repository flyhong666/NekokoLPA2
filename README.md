# NekokoLPA2 - Advanced eSIM Management
[![Crowdin](https://badges.crowdin.net/nekokolpa2/localized.svg)](https://crowdin.com/project/nekokolpa2)


**Language:** **English** | [日本語](./README_ja-JP.md)


NekokoLPA2 is a powerful, cross-platform eSIM management application supporting multiple card readers and advanced profile management features.

## For Translatore:

Translations is now managed with [Crowdin](https://crowdin.com/project/nekokolpa2).


## Features

- **Multi-Reader Support**: BLE, USB CCID, OMAPI, Telephony API, Remote readers
- **Rooted Android Path**: On rooted Android devices, OTBridge can be used to enable Telephony support and bypass OMAPI ARA-M restrictions without requiring the main app itself to be installed as a privileged app
- **Custom Profile Icons**: Set custom icons from gallery, remote sources, or eSIM card
- **Smart Tag System**: Organize profiles with date tags, notes, and custom labels
- **Scheduled Notifications**: Get reminders for profile expiry and important dates
- **Cross-Platform**: Android, iOS, macOS, Linux, Windows, and Web
- **Advanced UI**: Smart folding app bar, compact context menus, responsive design

## Android Notes

- NekokoLPA2 prefers the external `OTBridge` provider on Android when it is installed.
- On rooted Android devices, `OTBridge` can expose Telephony/TMAPI access and help bypass OMAPI ARA-M restrictions while keeping NekokoLPA2 itself on the normal app path.
- `OTBridge` releases are available at: [iebb/OTBridge](https://github.com/iebb/OTBridge/releases)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and release notes.

## Download

- **Android**: [GitHub Releases](https://github.com/iebb/NekokoLPA2/releases)
- **iOS/macOS**: [TestFlight](https://testflight.apple.com/join/bP38fzC4)
- **Windows**: [GitHub Releases](https://github.com/iebb/NekokoLPA2/releases)
- **Web**: [web.lpa.ee](https://web.lpa.ee) 

## Support

For issues, feature requests, or questions, please visit our [GitHub Issues](https://github.com/iebb/NekokoLPA2/issues).

## License

Proprietary - Source code not publicly available at the moment, due to the complexity of the codebase and the fact that it is a work in progress. It's planned to switch to open source in the coming months.

---

© 2026 Nekoko. All rights reserved.
