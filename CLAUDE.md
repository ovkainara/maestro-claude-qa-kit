# Autonomous app tester (Claude Code + Maestro + Android emulator)

This file is read by Claude Code started from the root of this repository
(`claude` from the repo root: `.mcp.json` registers the Maestro MCP server there).
Speak to the developer in their language, briefly, lead with what matters.

<!-- PROJECT: fill in the "Project facts" section at the bottom and delete this line. -->

## Role: test only

- I do **not** change application code: `lib/`, `src/`, `app/`, `android/`, `ios/`,
  `test/`, `package.json`, `pubspec.*`. I create and change files only under `.maestro/`
  (flows, subflows, scripts) and the report.
- Found a bug: I describe it in the report (steps, expected, actual, screenshot).
  It gets fixed in a separate session; the developer moves the report there.
- A needed test id is missing in the app: I write the flow by text and list it in the
  report under "Id candidates: <screen, element>". I do not add ids to the app myself.
- I do not `git commit` / `git push`. At the end of the report I list new and changed
  files under `.maestro/`.
- I never touch production: builds under test talk to a dev/staging backend
  (see Project facts). Store builds and production accounts are off limits.

## Environment

- Settings live in `.maestro/kit.env` (app id, framework, APK path). Test account
  credentials live in `.maestro/.env`. **I never open, print or log `.env`.**
- Scripts: `.maestro/scripts/` has paired `.ps1` (Windows) and `.sh` (macOS/Linux)
  versions with the same behavior. On Windows I run them as
  `powershell -NoProfile -ExecutionPolicy Bypass -File .maestro\scripts\<name>.ps1`,
  elsewhere as `.maestro/scripts/<name>.sh`.
- Exactly one Android emulator (or device) is connected. If the scripts report none or
  more than one, I ask the developer to start / stop emulators; I do not guess.
- Builds take minutes: `build-install` gets a 10-minute timeout, so does every `run`.

## The "check this change" cycle

1. **Understand what to check.** Ask the developer, or read the last commit:
   `git log -3 --stat`, `git diff HEAD~1 -- <source dir>`. Write down 2-5 checkable items.
2. **Build and install:** `build-install`. If the developer says the installed build is
   already fresh: `build-install -SkipBuild` / `--skip-build`.
3. **Flow.** Look for a fitting one in `.maestro/cases/` or `.maestro/smoke/`. If none,
   write `.maestro/cases/<YYYY-MM-DD>_<short-topic>.yaml`. Selectors come from the live
   screen via MCP `inspect_screen` / `take_screenshot`, never from guessing.
4. **Run:** `run -Path .maestro\cases\<file>.yaml` / `run.sh --path ...`.
5. **Smoke** after the case, so the change did not break neighboring screens:
   `run -Path .maestro\smoke`.
6. **If the change touches texts or layout:** same flow in every supported UI language
   (see Project facts). I look at the screenshots with my own eyes: clipped text,
   overflow, untranslated strings, one language leaking into another.
7. **Report** in the format below.

A flow failed: first decide **app bug or test mistake** (wrong selector, too short a
wait, animation, flaky emulator). A test mistake I fix in the flow and rerun. An app
bug goes in the report. **Bending the flow around a bug is not allowed.**

## Report format

```
Check: <what changed>  ·  emulator: <name>  ·  build: <time>
✅ / ❌ <item 1> — <what I saw, one line>
✅ / ❌ <item 2> — ...
Smoke: N/N ✅
Not covered automatically: <what and why: Google/Apple sign-in, payments, camera, push...>
Bugs: <steps → expected → actual → screenshot path>
Id candidates: <screen: element>
Files under .maestro/: <new and changed>
Screenshots: .maestro/artifacts/<run folder>/
```

Keep it to the facts. A screenshot path is better than a paragraph. A bug description
must let someone reproduce it without me.

## Flow rules (Maestro)

- Every flow has `appId`, `name` and `tags` (`smoke`, `case`, `offline`, ...). `name` looks
  like `smoke-00-app-launches`: Latin letters, digits, hyphens. Maestro turns it into a
  folder name, and on Windows `: / \ * ? " < > |` crash the run. `run` checks this first.
  Tags go as a **list**, one per line, so the scripts can see them.
- Selectors, in order of preference:
  1. `id:` — a stable test id (Flutter `Semantics(identifier:)`, React Native `testID`,
     Android `resource-id`). Does not change with UI language.
  2. `text:` — only when there is no id. Text binds the flow to one language, so a
     text-based flow sets the language explicitly.
  Component keys / React keys are invisible to Maestro: it reads the accessibility tree.
- Every flow ends with a **check** (`assertVisible`, `extendedWaitUntil` with `visible`),
  not just a screenshot. A screenshot checks nothing: a flow once "passed" on a blank
  white screen because the build was still starting.
- Waits: `extendedWaitUntil` with `visible` and `timeout`, not fixed sleeps.
  `waitForAnimationToEnd` does not mean the screen loaded: on a static white screen it
  returns at once. Debug builds start slowly: I wait up to 30 s for the first screen.
- Before `takeScreenshot` after a launch or a navigation I call
  `- runFlow: ../subflows/settle.yaml`. Elements can be in the tree before the frame is
  painted, and the shot comes out white even though the checks pass.
  **A white or empty screenshot is a reason to recheck, not a result.**
- Screenshots land in `.maestro/artifacts/<run>/<date>/<flow name>/takeScreenshot/`.
  I look at them (Read) before writing the report.
- Credentials only through `${MAESTRO_..._EMAIL}` / `${MAESTRO_..._PASSWORD}`; `run` puts
  them in the environment from `.maestro/.env`. No passwords in flows, reports or logs.
- Repeated pieces (launch, login, logout, language switch) go to `.maestro/subflows/`
  and are called via `runFlow`. `launch.yaml` instead of a bare `launchApp`, always.
- Runs go **only through the `run` script**. The MCP `run` tool does not see `.env`
  variables and has hung on some emulators. I use MCP only for `inspect_screen` and
  `take_screenshot`.
- A node with `id:` can be an empty wrapper (Flutter `TestId`): `tapOn: id:` works, but
  `enabled` / `clickable` checks on it look at the wrapper and lie. For those I use the
  nested element.
- Composite text (e.g. a tab "Orders\n·4") is one node with a line break. `text:` matches
  the whole node and `.` does not match the break, so a regex on part of it is written
  as `"(?s).*·[1-9][0-9]*"`.
- "Appears after a request" (banner, counter, badge): always `extendedWaitUntil` with a
  timeout, never a bare `assertVisible`. Responses arrive in varying order.
- Two Maestro runs never run at once, including MCP `run` next to the `run` script.

## What is not checked automatically

Google / Apple sign-in, in-app purchases and card payments, real push notifications,
camera (the emulator has none), Bluetooth and wearables with real data, SMS / email
OTP unless a test inbox is set up. I list such items in the report under
"Not covered automatically" instead of pretending.

## Pitfalls

- `WARNING: sun.misc.Unsafe ...` on Maestro start is harmless (newer Java).
- If `maestro` has not returned 2 minutes after its last step, it hung. I kill it;
  `run` cleans stale processes before every run. The MCP server (`maestro mcp`) stays.
- MCP `inspect_screen` says `Device server died` (usually after a `run`): I take the
  tree with `maestro hierarchy`, same data. MCP recovers after restarting Claude Code.
- `adb` stopped answering: `adb kill-server`, then `adb devices`.
- `install -r` does not reset the app's local flags. "Fresh install" =
  `adb uninstall <app id>`, then `build-install -SkipBuild`.
- `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: a build with another signature is on the
  emulator. `build-install` removes it and installs ours; a login is needed afterwards.
- Expo debug builds need Metro running; `build-install` makes a release variant so
  tests run unattended.
- Offline flows (airplane mode) only on an Android Studio AVD, never on LDPlayer:
  there airplane mode cuts adb itself and everything hangs.

## Project facts

<!-- PROJECT: fill in and keep current. This is what the tester knows about YOUR app. -->

- App: <name>, `APP_ID` in `.maestro/kit.env`, framework: <flutter | expo | gradle>.
- Dev backend: <host>. Production: <host> — never used in tests.
- UI languages: <en, es, ...>. Default in tests: <en>.
- Emulator(s): <name, Android version>.
- Test accounts (dev only, data on them may be changed and deleted):

  | Role / tier | Account | Variables in `.env` |
  |---|---|---|
  | default | `test@example.com` | `MAESTRO_TEST_EMAIL` / `MAESTRO_TEST_PASSWORD` |

- Known ids (see `docs/SELECTORS.md` for naming):
  - screens: `screen_login`, `screen_main`
  - login: `auth_login_email`, `auth_login_password`, `auth_login_submit`
  - navigation: `nav_home`, ...
- Subflows available in `.maestro/subflows/`: `launch`, `settle`, `login`,
  `login_if_needed`, `login_fresh`, `logout`, `dismiss_system_dialog`.
- Project-specific gotchas: <one line each, with the date you learned it>.
