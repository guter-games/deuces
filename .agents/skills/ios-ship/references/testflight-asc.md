# TestFlight / App Store Connect

ASC app: https://appstoreconnect.apple.com/apps/6799698932/testflight/ios

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
5. Tester opens invite email on device (same Apple ID) → TestFlight

Internal does **not** require Distribution App Information, screenshots, or age rating.

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

## Encryption

`ITSAppUsesNonExemptEncryption = false` is in both Info.plists. If ASC still asks, answer No (HTTPS only / exempt).
