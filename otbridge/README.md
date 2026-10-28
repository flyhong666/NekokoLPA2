# OTBridge

The small privileged OMAPI/TMAPI helper for NekokoLPA. Development and releases now live inside **NekokoLPA2**. See [source provenance](UPSTREAM.md), the original [MIT license](LICENSE), and the [comparison with the full rooted app](../docs/android-root.md).

The helper keeps package `ee.nekoko.nbridge` and provider `content://ee.nekoko.nbridge.provider`. It exposes `listSlots`, `listActiveConnections`, `connectLogicalChannel`, `transmitLogical`, `transmitBasic` and `closeLogicalChannel`. OMAPI slots use names such as `O-SIM1`; Telephony slots use `T-SIM1` or multi-port `T-SIM1p1`.

## Install

Use the `otbridge-magisk-kernelsu-v*.zip` asset from [NekokoLPA2 releases](https://github.com/iebb/NekokoLPA2/releases), install it through Magisk/KernelSU and reboot. The normal NekokoLPA app can then use the helper. An APK installed normally does not acquire privileged permissions.

The optional LSPosed hook and its access-control scope are explained in [the Android root guide](../docs/android-root.md). Android VoWiFi remains disabled.

## Build

From this directory, with Java 17 and the Android SDK installed:

```sh
./gradlew :app:assembleRelease
./scripts/build.sh
```

The APK is `app/build/outputs/apk/release/app-release.apk`; the module is `build/otbridge-magisk-kernelsu-v<helper-version>.zip`. The helper version is independent of the Flutter app version. Release builds use NekokoLPA2's already-public community signing key, so clean builds retain a stable certificate. Older installations signed by a different key may need removal before reinstalling.

The root [Build NekokoLPA2 workflow](../.github/workflows/build.yml) builds both artifacts, uploads them for inspection and attaches them to app releases. `android_tools_only` runs just the rooted app and helper builds. The old standalone repository remains available for historical source/releases.
