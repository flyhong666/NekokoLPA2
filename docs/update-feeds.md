# Update delivery

NekokoLPA2 is the public application. Its updater, channel selection, release metadata publisher and release-triggered workflow are maintained here. Kasutera contributes only optional provider integrations, branding, signing and release configuration; generic update code does not belong in its private overlay.

## Channels

| Channel | Artifact |
| --- | --- |
| Android `open` | Public community APK, including the universal APK for ARMv7 clients |
| Android `open-rooted` | Public full rooted APK, with the existing rooted package identity |
| Windows `open` / `open-portable` | Public installer / portable ZIP |
| Linux `open` / `open-appimage` / `open-tgz` | Public AppImage / AppImage / tarball |

Android selects its exact variant and signing certificate, then the highest build newer than the installed version. Normal Open and rooted Open cannot match each other's channels. Public desktop clients require their own channel and do not fall back to a vendor build. macOS/iOS use Store/TestFlight delivery rather than this in-app updater.

## Legacy Open builds

The original 2.4.0+600 public artifacts embedded `store`. Compatibility feed entries keep those installations updateable. Windows/Linux `store` entries point to the public artifacts.

Both old public Android flavors embedded `store` and used the same signing certificate. Their old updater cannot distinguish the normal package from the rooted package. Its compatibility entry therefore opens the release chooser: choose the **Open Android APK** for `ee.nekoko.nlpa2.open`, or the **Open rooted APK/module** for `ee.nekoko.nlpa2`. Do not install a vendor APK over the Open app. Future public builds carry `open` or `open-rooted` explicitly.

## Publishing

[Publish Open update feeds](../.github/workflows/publish_update_feeds.yml) runs after a stable release or successful public release build. It can also be dispatched manually with a published release tag. The publisher:

1. Requires the latest published stable app release and all expected uploaded assets.
2. Downloads and verifies the Android APKs' community signing certificate.
3. Writes the correct artifact URLs, sizes, version and build to each channel.
4. Refuses to overwrite a newer feed build and fails CI if a write is rejected.

A manual dispatch can explicitly enable `migrate_standard_desktop` to offer Open artifacts to legacy Windows/Linux `std` users. Its feed note explains that private provider status add-ons are omitted. From 2.4.1+601, eSIM.cc and eSIM.gg are public and included; only the 3HK status add-on remains private. This migration is separate from maintaining the Open channels, so publishing Open does not silently replace a vendor distribution.

`UPDATE_WORKER_URL` and `UPDATE_WORKER_KEY` are encrypted GitHub Actions secrets. They are never committed to this repository. Authentication is sent in a header, not a URL query string. The shared [metadata writer](../scripts/update_config_json.py) also supports vendor release callers, which keep their credentials and flavor settings separately.

The public [feed row mapper](../tools/update_feed_entry.ts) preserves direct artifact downloads separately from release-page links. The deployment wrapper keeps only its D1 binding/cache infrastructure outside this repository.

The feed is served at <https://updates.lpa.ee/nlpa2.json>. Edge caching can take up to five minutes to expose a newly published entry. The update button opens the selected download externally; it does not silently install software.
