# Release invariants

Do not violate these when editing `ios/project.yml` or Info.plist files.

## Product types

- `Deuces` type: **`application.messages`** (standalone iMessage container — no home-screen UI)
- `DeucesMessages` type: **`app-extension.messages`**
- Generic `app-extension` skips `ASSETCATALOG_COMPILER_TARGET_STICKERS_ICON_ROLE=extension`, so iMessage icon PNGs never land in the appex and ASC validation fails.
- Do **not** change `Deuces` back to `application` without creating a new ASC app record (standalone ↔ containing-app is a new product).
- Do **not** add Swift sources to the `Deuces` container (Apple standalone template: no container code).

## Embedding

- Container embeds `DeucesCore` (`embed: true`)
- Messages **links** Core only (`embed: false`) — Messages forbids nested Frameworks / duplicate Core bundle id
- Container sources are **assets only** (`Deuces/` excluding `**/*.swift`)

## Info.plist keys (container + Messages)

| Key | Value |
|-----|-------|
| `CFBundleDisplayName` | `Deuces With Friends` |
| `CFBundleShortVersionString` | `$(MARKETING_VERSION)` |
| `CFBundleVersion` | `$(CURRENT_PROJECT_VERSION)` |
| `ITSAppUsesNonExemptEncryption` | `false` |

Messages also needs:

- `MSMessagesExtensionStoreIconName`: `iMessage App Icon`
- `ASSETCATALOG_COMPILER_APPICON_NAME`: `iMessage App Icon`

Container:

- `CFBundlePackageType`: **`APPL`** (ASC-required; `application.messages` does not inject it — see [standalone-packaging.md](standalone-packaging.md))
- `ASSETCATALOG_COMPILER_APPICON_NAME`: `AppIcon`
- All four `UISupportedInterfaceOrientations`

## Team / signing

- `DEVELOPMENT_TEAM`: `U253FJED45`
- `CODE_SIGN_STYLE`: Automatic
- `ENABLE_DEBUG_DYLIB`: `NO` (breaks Messages on iPadOS 16)

## Bundle IDs

- Container (ASC primary): `com.deuces.deuces.imessage`
- Extension: `com.deuces.deuces.imessage.extension`
- Core: `com.deuces.deuces.imessage.core`
- Screenshot harness (local only): `com.deuces.deuces.imessage.screenshot`

## Local-only targets

- `DeucesScreenshot` (`application`) is for `make ios-screenshots` only — never archive/upload it as the product.

## xcodegen

After editing `project.yml`, always `xcodegen generate`. xcodegen rewrites Info.plist from `info.properties` — keep version keys as `$(...)` in both yaml and plist.
