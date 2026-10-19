# Web / TUI path — `dsh web` + `dsh-workbuddy-connect`

Applies to: `npx @deepseek-ai/dsh web`, a self-installed `dsh` CLI, or the TUI. No Electron app manages this profile, so the ordinary CLI is the right tool.

## Prerequisites

- **Node 22.19+ or 24+** (`dsh` refuses older runtimes).
- **WorkBuddy desktop app** installed and logged in (CN build → `WorkBuddy` group; international build → `WorkBuddy AI`). The plugin reuses its session; no API key is involved.
- **pnpm 11+ on PATH.** `dsh plugin …` shells out to `pnpm`. On a machine without it the plugin manager fails with `'pnpm' is not recognized`. Install it locally and add its `node_modules/.bin` (or a global install) to PATH.
- Enough disk for the CLI install (~600 packages) and the plugin.

## 1. Install DSH and pin the kernel

```sh
npx @deepseek-ai/dsh@0.2.1-rc.2 --version      # verify the CLI runs
npx @deepseek-ai/dsh@0.2.1-rc.2 web            # start the web UI
```

If `npx` misbehaves on Windows (shim errors), do a normal local install and call the entry point directly:

```sh
npm install --prefix <dir> @deepseek-ai/dsh@0.2.1-rc.2
node <dir>/node_modules/@deepseek-ai/dsh/lib/bin.js web
```

The web profile lives under `$DSH_HOME/profiles/web` (default `$DSH_HOME` = `~/.dsh`).

## 2. Install the plugin

Use the plugin version that matches the kernel (`0.2.1-rc.2 → 0.7.8`; full table in `SKILL.md`).

```sh
dsh plugin --profile web add dsh-workbuddy-connect@0.7.8
```

What this does: adds the npm dependency to the profile, runs pnpm, and (per the plugin manager) should also register the bundle. **Verify both parts** — see § 3.

## 3. Verify the profile wiring

```sh
# a) the dependency must be exactly the matched version
cat ~/.dsh/profiles/web/package.json     # dependencies → "dsh-workbuddy-connect": "0.7.8"
# b) the bundle must be enabled (a bundle that is installed but not listed is never loaded)
#    dsh.profile.bundles must contain "dsh-workbuddy-connect"
```

If `dsh.profile.bundles` only lists `@deepseek-ai/dsh-base` and `@deepseek-ai/dsh-web-app`, append `"dsh-workbuddy-connect"` (this happens when an earlier `plugin add` failed midway and a retry short-circuits with "Already up to date"):

```json
"dsh": { "profile": { "bundles": [
  "@deepseek-ai/dsh-base",
  "@deepseek-ai/dsh-web-app",
  "dsh-workbuddy-connect"
] } }
```

Then restart `dsh web`. Startup prints a tokenized URL — the token changes on every boot.

## 4. Verify behavior

```sh
dsh plugin --profile web exec dsh-workbuddy-connect doctor
```

Expect `Desktop auth file: present … encrypted` and `Sign-in state: signed-in`. Then in the UI: model picker (input-box dropdown or `/model`) → group **WorkBuddy** / **WorkBuddy AI** → pick a model → send one short message. When a WorkBuddy model is selected, the remaining credit appears next to the picker (`WB.x,xxx（积分）`).

The host-side proof: `<DSH_HOME>/.workbuddy-host-heartbeat.json` is written by the running `dsh web` process (it records `pluginVersion` and `pid`); `<DSH_HOME>/.workbuddy-catalog.json` holds the fetched model catalog.

## 5. TUI notes

- Profile `dsh-tui`, installed with **pnpm 11** (older pnpm hits `ERR_PNPM_UNEXPECTED_STORE`).
- Terminal shell `@deepseek-harness-tui/dsh-tui` must be **0.10.0-beta.5+**, otherwise startup fails with `events is not iterable`.
- No reasoning-effort probing in TUI; everything else is the same.

## 6. Repair after an update

1. Read the new kernel: `dsh --version`.
2. Re-run `dsh plugin --profile web add dsh-workbuddy-connect@<matched>`.
3. Re-check § 3 (dependency + bundle list), then § 4.

## Pitfalls seen in the field

| Pitfall | Detail |
|---|---|
| `ERR_PNPM_IGNORED_BUILDS` | pnpm ≥10 blocks `@google/genai` / `protobufjs` postinstalls. Add to the profile's `pnpm-workspace.yaml`: `allowBuilds: { '@google/genai': true, protobufjs: true }`, then re-run the install. |
| Bundle installed but never loaded | `dsh plugin add` can leave `dsh.profile.bundles` untouched after a failed retry. Always check the list. |
| Token URL changes every boot | Never bookmark an old `?token=` URL; read the fresh one from the `dsh web` output. |
| Installing into a **desktop** profile from here | Don't. The desktop profile is app-managed — see `references/desktop.md`. |
| User-level `DSH_HOME` | If you set `DSH_HOME` globally, every DSH flavour (including the desktop app) will fight over it and open the wrong profile. Keep it inside the launch script only. |
