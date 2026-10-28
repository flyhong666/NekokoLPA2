# Open and standard builds

Current source/build comparison, 2026-10-28. **Open** means an app built entirely from the public NekokoLPA2 repository. **Standard/non-open** means the same app with Kasutera's private overlay and release settings. The 9eSIM-branded distribution is a further variant with its own branding and restrictions.

## Features

| Area | Open | Standard/non-open |
| --- | --- | --- |
| Download, enable, disable, rename and delete eSIM profiles | Shared core | Shared core |
| Reader transports, including TYBLE/B0 Plus, CCID, OMAPI, bridges, SE HAL and remote readers | Public implementation, subject to OS/hardware support | Same implementation |
| Plain-SIM probing | Included on eligible raw-APDU readers | Same |
| Experimental desktop IMS/SMS | Included with opt-in on Windows/macOS/Linux | Same in standard builds |
| Reader-backed iOS calling source | Public, with its source-built framework | Same source in the standard Apple build |
| Android/OMAPI VoWiFi restriction | Disabled, including rooted/bridge configurations | Same |
| OTBridge helper and full rooted app/module | Public source and builds | Same helper; vendor-signed full rooted build also retained |
| eSIM.cc profile extras | No private add-on | Rewards/card-bonus badge and portal action |
| eSIM.gg profile extras | No private add-on | Matching-profile number, balance and package/data status when returned by the service |
| 3HK profile extras | No private add-on | Matching-profile number/expiry/package status when returned by the service |
| Extra navigation | No private variant web tabs | Optional Discover tab for standard builds; provider/store tabs in the 9eSIM variant |
| Branding | Public community/platform assets | Standard, multi-signer, community, 9eSIM and other flavor assets |

Open can still install and manage eSIM.cc, eSIM.gg and 3HK profiles when the reader/card permits it. The omitted pieces are provider-specific UI/status integrations, not their basic profile operations. The eSIM.gg and 3HK add-ons perform service queries for matching profiles; those particular queries are absent from Open. Public plugins such as BeeSIM, eSTK and GM remain included.

Windows, macOS and Linux use the same core reader/IMS code in both distributions. OS limits still apply equally: for example, the app has no Linux BLE transport. Desktop IMS provides experimental SMS; the separate iOS implementation provides reader-backed calling. The 9eSIM-branded variant disables desktop IMS even though Open and standard builds include it.

## Android identity, signing and packaging

| Build | Android package | Signing/distribution |
| --- | --- | --- |
| Open community | `ee.nekoko.nlpa2.open` | Public community certificate; public GitHub APK is multi-ABI |
| Standard GitHub APK | `ee.nekoko.nlpa2.std` | 9eSIM certificate; current release APK targets ARM64 |
| Standard Google Play | `ee.nekoko.nlpa` | Store app identity and Play distribution |
| Multi-signer | `ee.nekoko.nlpa2.multi` | Multiple vendor/community certificates; ARM64 and ARMv7 APKs |
| Community/sekiu | `ee.nekoko.nlpa2.sekiu` | Community certificate with the private overlay |
| 9eSIM | `ee.nekoko.nlpa.flavor1` | 9eSIM branding/certificate and build restrictions |
| Full rooted app | `ee.nekoko.nlpa2` | Public rooted build uses the community certificate; private rooted build uses its vendor certificate |

Signing certificates can affect card access rules through OMAPI. A private build is not a guarantee of broader card access; the card and firmware must accept its certificate/permissions. Ordinary APK installation grants neither build root/system privileges. See [OTBridge and the rooted app](android-root.md).

The current private Android scripts pass `ENABLE_ZXING=false`, while public builds use the default `true`. Consequently, Open retains the extra ZXing fallback when imported QR-image analysis throws an error. Both still use the normal mobile scanner. This is a build setting, not a separate reader or LPA engine; desktop builds keep that decoder enabled.

## App data and desktop identity

Normal Open and standard Android builds have different package IDs and separate local app data. The rooted builds share the legacy rooted package ID; switching certificates can require uninstall/reinstallation. Profiles themselves reside on the connected eUICC, independently of the app's notes/settings/database.

Windows currently uses `%LOCALAPPDATA%/NekokoLPA2/databases/nekokolpa2.db` in both builds. The installers have different installer IDs but use the same default `%ProgramFiles%/NekokoLPA2` directory, so accepting both defaults can replace the other build's files. Different download filenames do not isolate the database. Other platform names, bundle IDs and store/signing arrangements vary with the platform project/flavor; avoid inferring app-data isolation from an `.open` filename alone. Database import/export is available in the shared app.

## Update delivery

The updater implementation is shared, but Android selects updates by detected variant and certificate; desktop selection can fall back to the `std` feed. The current public flavor asset says `store`, while the private Android scripts explicitly select their variants. A dedicated Open update channel is therefore not established simply by naming the download `.open`. The live update-feed response could not be inspected during this comparison because it returned HTTP 403; this comparison does not assert automatic-update parity. Store/TestFlight distribution is also separate from GitHub APK/desktop downloads.

The private overlay also contains signing credentials and release infrastructure. These are build/deployment material, not additional public reader or IMS features. The public [plugin registry](../lib/plugins/build_plugin_registry.dart), [capability policy](../lib/settings/build_capabilities.dart) and [build workflow](../.github/workflows/build.yml) show what Open includes.
