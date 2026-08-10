# Release invariants

Do not violate these when editing `ios/project.yml` or Info.plist files.

## Product types

- `DeucesMessages` type: **`app-extension.messages`**
- Generic `app-extension` skips `ASSETCATALOG_COMPILER_TARGET_STICKERS_ICON_ROLE=extension`, so iMessage icon PNGs never land in the appex and ASC validation fails.

## Embedding

- Host embeds `DeucesCore` (`embed: true`)
- Messages **links** Core only (`embed: false`) — Messages forbids nested Frameworks / duplicate `com.deuces.deuces.core`

## Info.plist keys (both host + Messages)

| Key | Value |
|-----|-------|
| `CFBundleShortVersionString` | `$(MARKETING_VERSION)` |
| `CFBundleVersion` | `$(CURRENT_PROJECT_VERSION)` |
| `ITSAppUsesNonExemptEncryption` | `false` |

Messages also needs:

- `MSMessagesExtensionStoreIconName`: `iMessage App Icon`
- `ASSETCATALOG_COMPILER_APPICON_NAME`: `iMessage App Icon`

Host:

- `ASSETCATALOG_COMPILER_APPICON_NAME`: `AppIcon`
- All four `UISupportedInterfaceOrientations`

## Team / signing

- `DEVELOPMENT_TEAM`: `U253FJED45`
- `CODE_SIGN_STYLE`: Automatic
- `ENABLE_DEBUG_DYLIB`: `NO` (breaks Messages on iPadOS 16)

## Bundle IDs

- Host: `com.deuces.deuces`
- Extension: `com.deuces.deuces.imessage` (`.messages` is globally taken)
- Core: `com.deuces.deuces.core`

## xcodegen

After editing `project.yml`, always `xcodegen generate`. xcodegen rewrites Info.plist from `info.properties` — keep version keys as `$(...)` in both yaml and plist.
