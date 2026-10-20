# Troubleshooting

Everything here was hit for real while running this setup. Each entry: symptom,
cause, what to do.

## Screenshots are white / empty, but the checks passed

The app exposes its accessibility tree before the first frame is painted, so Maestro
finds the elements while the screen is still blank. `waitForAnimationToEnd` does not
help: two identical white frames look "animation ended".

Do: `- runFlow: ../subflows/settle.yaml` right before `takeScreenshot` after a launch
or navigation. `run` flags PNGs under `BLANK_PNG_KB` (kit.env) as possibly blank.
A white screenshot is a reason to recheck, never a pass.

## A flow "passed" but tested nothing

A flow that ends with a screenshot asserts nothing. End every flow with
`assertVisible` or `extendedWaitUntil: visible`.

## First screen never appears / `launchApp` then nothing

- Debug builds start slowly: wait up to 30 s (`launch.yaml` does).
- Some emulators (LDPlayer's task manager) kill the freshly launched process.
  `launch.yaml` relaunches once.
- Expo **debug** build without Metro shows "Could not connect to development server".
  `build-install` builds the release variant for this reason.

## `maestro` hangs after the last step

Kill the java process (`run` does it automatically before each run). Do not kill the
MCP server (`maestro mcp`) — it belongs to Claude Code. Two Maestro runs at once
(script + MCP `run`) is the usual cause: never do that.

## MCP `inspect_screen` → `Device server died`

Happens after a scripted run. Use `maestro hierarchy` in the terminal: same data.
The MCP server recovers after restarting Claude Code.

## `adb` stopped answering

`adb kill-server`, then `adb devices`. If the device is gone after airplane mode on
LDPlayer: adb on LDPlayer runs over the emulator's own network, airplane mode cuts
it. Turn airplane mode off manually in the emulator. Offline flows: AVD only.

## `More than one device connected`

Two emulators (or an emulator plus a phone) are visible. Keep one, or set
`ANDROID_SERIAL=<serial>` before running the scripts.

## `INSTALL_FAILED_UPDATE_INCOMPATIBLE` / `signatures do not match`

A build signed with another key (store build, teammate's machine) is installed.
`build-install` uninstalls it and installs yours. App data on the emulator is wiped:
log in again.

## `install -r` did not reset the app state

Reinstalling keeps local storage. For a true fresh install:
`adb uninstall <app id>`, then `build-install --skip-build`.

## Flow name crashes the run on Windows (`InvalidPathException`)

Maestro uses `name:` as a folder name. `: / \ * ? " < > |` are forbidden on Windows.
Use `smoke-00-app-launches` style names. `run` rejects bad names before starting.

## Tags are not picked up

Write tags as a list, one per line:

```yaml
tags:
  - smoke
```

not `tags: [smoke]` — the scripts grep for the list form.

## `text:` selector does not match a tab like "Orders ·4"

Composite elements are one node with a line break (`Orders\n·4`). `.` does not match
the break; use `"(?s).*·[1-9][0-9]*"`.

## Something appears "sometimes"

Banners, counters, badges arrive after network calls, in varying order. Use
`extendedWaitUntil` with a timeout, not `assertVisible`.

## An Android system dialog covers the app ("X keeps stopping")

Another app crashed (Bluetooth after airplane mode on some AVD images). Call
`- runFlow: ../subflows/dismiss_system_dialog.yaml` after the action that caused it.

## `WARNING: sun.misc.Unsafe ...` on Maestro start

Harmless with newer Java versions.

## Gradle build is slow / machine swaps

Project `gradle.properties` often sets `-Xmx8G` for strong machines. On an 8 GB PC
override it in `~/.gradle/gradle.properties` (`org.gradle.jvmargs=-Xmx3G`). A build
went from 14 minutes to 4 after this.

## Disk fills up

Every run copies the APK into `%TEMP%` / `/tmp` and Maestro keeps debug copies in
`~/.maestro/tests`. `cleanup` runs before every `run` and removes old run folders,
Maestro debug copies and leftover `tmp*.apk`. 52 GB were recovered on one machine.

## Emulator notes

- **LDPlayer** (Windows): fast, Health Connect available, no Google Play account, no
  root. Airplane mode kills adb. Good default for everything except offline flows.
- **Android Studio AVD**: needed for airplane mode, root (`adb root` on Google APIs
  images, not Google Play images), clock changes. If the AVD boots from a snapshot
  with a dead `adbd`, start it with `-no-snapshot-load` or Cold Boot Now.
- Only one emulator at a time on an 8 GB machine.
