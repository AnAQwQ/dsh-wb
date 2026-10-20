# Desktop path — official DSH Electron app

Applies to: the official **DeepSeek Harness** desktop app (Electron; `app-update.yml` → `download.deepseek.com/dsh-desk/feeds/win-x64/`, nightly channel). Everything below is about the app-managed `desktop` profile.

## 1. Facts you need before touching anything

| Fact | Where it comes from |
|---|---|
| Kernel version | `<app>\resources\runtime\primary-runtime\runtime.json` → `desktopVersion` (e.g. `0.2.1-rc.2`). This is the number that must match the plugin — **not** the app version in `version` (e.g. `44.7.0`). |
| Profile directory | `<DSH_HOME>\profiles\desktop`, default `DSH_HOME = %USERPROFILE%\.dsh`. Confirm by reading the host process command line: the third argument after `dsh-desktop-host\lib\index.js` is the profile path. |
| Host HTTP port | **Dynamic.** It changes between launches (9701, 7317, …). Never use the port to decide whether the app is healthy; use the heartbeat file. |
| Profile ownership | The `desktop` profile is **exclusively managed by the app**. The independent `dsh` CLI refuses: `error: profile "desktop" is managed exclusively by the Electron application`. |
| Sanctioned tool | The app's own bundled CLI: `<app>\resources\runtime\cli\bin\dsh.cmd` (Windows). Internally it calls `runCli({ manageDesktopProfile: true, packageManager: <bundled pnpm> })`. The `plugin` subcommand is allowed on the desktop profile; boot-style commands (`--dump-config`, `--profile desktop` to run) are not. |
| App argument whitelist | Unknown flags are rejected (`bad option: --user-data-dir=…`, exit code 9). Do not invent flags. |

## 2. Prerequisites

- App installed and **logged in** (first launch creates the profile).
- **WorkBuddy desktop app installed and logged in** — the plugin reuses its session; CN and international builds give separate groups.
- The app bundles its own Node (24.x) and pnpm (11.x) under `<app>\resources\runtime\primary-runtime\dependencies\`; nothing else is needed.

## 3. Install the plugin (the sanctioned way)

```bat
set WORKBUDDY_ELECTRON_BIN=C:\path\to\WorkBuddy.exe
"<app>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop add dsh-workbuddy-connect@0.7.9
```

Notes:

- `WORKBUDDY_ELECTRON_BIN` is only needed when WorkBuddy is **not** at its default Windows location (`%LOCALAPPDATA%\Programs\WorkBuddy\WorkBuddy.exe`). The plugin otherwise falls back to uninstall registry records — which fail in environments that block `reg.exe`.
- The command may stop with `ERR_PNPM_IGNORED_BUILDS` (`@google/genai`, `protobufjs`). pnpm ≥10 blocks their postinstall scripts; the install is incomplete until you approve them. Add to `<profile>\pnpm-workspace.yaml`:

  ```yaml
  allowBuilds:
    '@google/genai': true
    protobufjs: true
  ```

  then re-run the same `add` command. A clean run ends with exit code 0 and `Done in … using pnpm v11…`.
- The plugin version must match `desktopVersion`. Mismatch can keep the whole backend from starting.

## 4. Verify

```bat
"<app>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop exec dsh-workbuddy-connect doctor
```

Expect:

```
Desktop auth file: present — encrypted (<%LOCALAPPDATA%\…\workbuddy-desktop.info>)
Sign-in state: signed-in
```

`Host bundle: not started` in this CLI context is **normal** — the host bundle runs inside the app process, not inside the CLI.

Then **fully quit the app** (window close may only hide it to the tray) and relaunch. Hard proof the provider is live:

1. `<DSH_HOME>\.workbuddy-host-heartbeat.json` is rewritten with the app's live PID:

   ```json
   {"version":1,"package":"dsh-workbuddy-connect","pluginVersion":"0.7.9","registeredAt":…,"pid":1234}
   ```

   The heartbeat is written **once per registration** (not periodically) — a fresh mtime after a relaunch is the signal. If the file still points at a dead PID, the plugin did **not** load in the running app.
2. `<DSH_HOME>\.workbuddy-catalog.json` refresh timestamp moves.
3. Model picker (input-box dropdown or `/model`) shows **WorkBuddy** / **WorkBuddy AI**; pick a model, send one message, credits appear next to the picker.

## 5. Why "install succeeded but no group"

The three failure modes seen in the field, in order of likelihood:

1. **The app is using a different profile home.** A user-level `DSH_HOME` environment variable (e.g. pointing at another install's home) makes the app boot a *fresh, empty* `desktop` profile somewhere else. The window looks normal, the model picker is just missing the group. Check the host process command line — it prints the profile path it actually uses. Fix: remove the user-level `DSH_HOME`.
2. **The plugin is installed but not enabled.** `dsh.profile.bundles` in `<profile>\package.json` must contain `dsh-workbuddy-connect`. The app's own plugin manager normally does this; a hand-installed plugin often does not.
3. **`node_modules` is incomplete.** A hand-run pnpm can miss packages the app's manager expects (`Packages: +2` on its next run). Let the bundled CLI (`plugin --profile desktop add …`) finish instead of copying files by hand.

## 6. After DSH updates (nightly!) or WorkBuddy updates

The app updates itself on the nightly channel; the kernel version changes and the plugin must follow. The profile itself survives app updates (it lives in `DSH_HOME`, not in the install directory), but:

- **Kernel moved** → install the matching plugin version with the command in § 3.
- **The app's recovery flow disabled third-party bundles** (after repeated failed boots) → re-add `dsh-workbuddy-connect` to `dsh.profile.bundles`.
- **WorkBuddy changed its credential location/format** → `doctor` reports `signed-out` while the desktop app is logged in. Check for a newer plugin release; as a stop-gap, point `WORKBUDDY_AUTH_FILE` (CN) / `WORKBUDDY_AI_AUTH_FILE` (international) at the real auth file.

`scripts/repair-desktop.ps1` automates all of the above on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\repair-desktop.ps1            # check + repair
powershell -ExecutionPolicy Bypass -File scripts\repair-desktop.ps1 -CheckOnly # read-only
```

It resolves kernel → plugin version (built-in table, then npm `peerDependencies` discovery), installs via the bundled CLI, re-adds the bundle and `allowBuilds`, and verifies with `doctor`.

## 7. Failure signatures worth knowing

| Signature | Meaning |
|---|---|
| Window opens, backend never listens, no heartbeat | the app booted a different (empty) profile — see § 5.1; or the backend failed before starting the host |
| App exits ~1 s after launch with code 0, silently | single-instance lock could not be acquired (`requestSingleInstanceLock()` failed → `app.quit()`). Typical when the app is launched from a heavily sandboxed shell; launch it from Explorer / the Start menu instead |
| `bad option: --user-data-dir=…`, exit code 9 | the app validates its command line; it accepts only its own flags |
| `error: profile "desktop" is managed exclusively by the Electron application` | you used an independent `dsh` CLI; use the bundled one |
| `Host bundle: stale heartbeat (process exited)` | the heartbeat's PID is dead — the last writer is gone, the current app never registered |
