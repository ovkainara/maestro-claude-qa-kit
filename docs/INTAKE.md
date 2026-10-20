# Before the setup: what I need from you

Answer in a message or a short doc. Everything marked **required** blocks the setup.

## 1. The app (required)

- Repository access (read is enough; I deliver a PR / patch) **or** the source as a zip.
- Framework: Flutter / Expo / React Native bare / native Android.
- Android application id (e.g. `com.mycompany.myapp`).
- How to build a dev build, if it is anything beyond `flutter build apk` /
  `npx expo run:android` / `./gradlew assembleDebug` (flavors, env files, secrets).
- Or a ready **debug / staging APK** if you prefer not to share the source.

## 2. A test backend (required)

- The build must talk to a **dev or staging** backend, never production.
- One test account per role / subscription tier you care about. Data on these
  accounts may be changed or deleted by the tests.
- Any OTP / email verification on login? Then either a test account that skips it, a
  fixed test code, or a test inbox (Mailpit, Mailosaur) I can read from.

## 3. What to check first (required)

- 3-10 screens or flows in priority order ("login → home → create order → pay").
- Known weak spots: "the list sometimes shows stale data", "rotation breaks the form".
- Supported UI languages, and the default one.

## 4. Store context (optional, but it shapes the checks)

- Rejected before? Paste the rejection text (Apple guideline number / Google policy).
- Target stores: Google Play, App Store, both.

## 5. Your machine (optional)

- OS: Windows / macOS / Linux. RAM.
- Emulator already installed? (Android Studio AVD, LDPlayer, Genymotion, none)
- Claude Code installed and logged in? Maestro CLI installed?

If you want the setup to run on **your** machine, we do a 30-60 min screen-share call
after the PR is ready. Otherwise everything runs on my side and you receive the PR,
the first report and the screenshots.

## What you get back

- `.maestro/` in your repo: scripts, subflows, smoke flows, first cases for your screens.
- `CLAUDE.md` section that turns Claude Code into the tester for your app.
- Test ids added to your screens (as a separate commit, easy to review).
- First full run: report + screenshots.
- A 30-minute call to hand it over (Standard and Premium).
