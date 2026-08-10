# Standalone iMessage packaging

Deuces With Friends is a **standalone** iMessage app, not an iOS app that happens to contain a Messages extension.

## Product types

| Target | Must be |
|--------|---------|
| `Deuces` | `application.messages` → `com.apple.product-type.application.messages` |
| `DeucesMessages` | `app-extension.messages` |

Xcode’s standalone template: the container **does not appear on the Home Screen** and **cannot have its own code** (assets / AppIcon only). All UI lives in `DeucesMessages`.

`LSApplicationLaunchProhibited=true` is injected by the product type. That is correct. ASC may warn that Vision/Mac don’t support it — ignore for iPhone/iPad Messages shipping.

## ASC app identity

- Primary bundle ID on the ASC record = **container** id: `com.deuces.deuces.imessage`
- Extension must be a **child** id: `com.deuces.deuces.imessage.extension`
- SKU: `deuces-imessage-2`
- Display name: **Deuces With Friends**

Standalone ↔ containing-app (`application` + extension) is a **new ASC app**, not a version update. Do not flip product types on this record.

## CFBundlePackageType = APPL (required)

`application.messages` does **not** inject `CFBundlePackageType`. Without it:

- Archived `PkgInfo` becomes `????????`
- ASC upload fails: *Invalid Bundle OS Type code … must be … [APPL]*

Keep in `ios/project.yml` → `Deuces.info.properties`:

```yaml
CFBundlePackageType: APPL
```

Preflight: `PlistBuddy … CFBundlePackageType` → `APPL` and `PkgInfo` starts with `APPL`.

## Screenshots

Do not `simctl launch` the container — it isn’t a Home Screen app. Use `DeucesScreenshot` (`make ios-screenshots`).

## Embedding

Same as before: container embeds `DeucesCore`; appex links only. Nested `Frameworks` inside the appex fails Messages rules / duplicate Core id.
