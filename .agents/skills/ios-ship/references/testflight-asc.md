# TestFlight / App Store Connect

App: **Deuces With Friends** · SKU `deuces-imessage-2` · bundle `com.deuces.deuces.imessage`  
(Find the app in [App Store Connect](https://appstoreconnect.apple.com/apps) — old host+extension TestFlight apps were deleted.)

## Product type

This record is a **standalone iMessage app**. Builds must be `application.messages` + Messages appex. Do not upload a containing-app (`application` + extension) binary to this SKU.

Install path for testers: **Messages → Apps → Deuces With Friends** (no Home Screen icon).

## Internal vs External

| Path | Review? | When |
|------|---------|------|
| **Internal Testing** | No | Team members in Users and Access |
| **External Testing** | Beta App Review | Outside testers |
| **Distribution → Submit** | App Review | Public App Store |

For “no review” shipping: **Internal only**. Never add the build to External and never submit the version for App Store review.

## Expected Internal flow

1. Build finishes processing → **Ready to Test** / **Testing**
2. Create an **Internal** group if needed (current ASC requires a group)
3. Add testers from **Users and Access** (Admin / App Manager / Developer / Marketing) — not free-typed emails alone
4. Group → Builds → add the new build
5. Tester opens invite email on device (same Apple ID) → TestFlight → install → open in **Messages**

Internal does **not** require Distribution App Information, screenshots, or age rating.

## Upload warnings (safe to ignore)

- *Apple Vision Pro / Macs with Apple silicon support issue* because `LSApplicationLaunchProhibited` is true — expected for standalone iMessage.

## Upload failures

### Invalid Bundle OS Type code (`CFBundlePackageType` must be `APPL`)

Standalone container Info.plist omitted `CFBundlePackageType`. Fix in `project.yml`, regenerate, re-archive. See [standalone-packaging.md](standalone-packaging.md).

### Missing iMessage icons

See [imessage-icons.md](imessage-icons.md).

## Stuck states

### Waiting for Review

Build or version was submitted for App Store or External beta. Cancel / Remove from Review. Attach build only to Internal.

### No Builds Available (group has the build)

1. Confirm tester is listed under Users and Access
2. Remove tester from group → re-add as App Store Connect user
3. Remove build from group → re-add
4. Fill TestFlight → Test Information (contact email + one-line notes)
5. Still stuck → ship a new build number

### Invited but not in TestFlight app

Accept the **email** invite on device. Wrong Apple ID / spam folder are common.

### Couldn't Load App / This app isn't available

Invite accepted but build not actually available (often after cancel/review mess). Ship a fresh build, attach only that build to Internal, resend invite. Do not reuse old invite links.

### Add Existing Testers to Build errors

Skip that dialog. Attach the **group** to the build (or build to the group) instead.

### Installed but “no app” on Home Screen

Expected. Open **Messages → Apps** drawer.

## Encryption

`ITSAppUsesNonExemptEncryption = false` is in both Info.plists. If ASC still asks, answer No (HTTPS only / exempt).
