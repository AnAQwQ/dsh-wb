# DSH-WB

**WorkBuddy models inside DeepSeek Harness (DSH).**

English | [中文](./README.md)

`dsh-workbuddy-connect` is a community DSH plugin (MIT, upstream [`corrinehu/dsh-workbuddy-connect`](https://github.com/corrinehu/dsh-workbuddy-connect)). It registers the models already available in a logged-in WorkBuddy desktop app (GLM-5.x, DeepSeek-V4, Kimi-K3, MiniMax-M3, Hy3/Hy4, …) as a DSH model provider. It reuses the desktop app's session — no API key. The CN build surfaces a `WorkBuddy` group; the international build surfaces `WorkBuddy AI`.

This repository is an **Agent Skill**: it packages both integration paths (web and desktop), the version-matching rules, and the pitfalls we actually hit into a reusable runbook.

## Two paths

| | Web / TUI | Desktop (official Electron app) |
|---|---|---|
| Applies to | `npx @deepseek-ai/dsh web`, a self-installed `dsh` CLI, TUI | The official DSH desktop app |
| Profile | `~/.dsh/profiles/web`, ordinary CLI | `~/.dsh/profiles/desktop`, **exclusively app-managed** |
| Install | `dsh plugin --profile web add …` | The app's bundled CLI: `<app>\resources\runtime\cli\bin\dsh.cmd plugin --profile desktop add …` |
| Gotchas | missing pnpm, bundle not registered | exact version match, `DSH_HOME` leaks, pnpm build approvals |
| Details | [`references/web.md`](./references/web.md) | [`references/desktop.md`](./references/desktop.md) |

## Quick start

### Web

```sh
# Requires Node 22.19+ / 24+, pnpm 11+, a logged-in WorkBuddy desktop app
npx @deepseek-ai/dsh@0.2.1-rc.2 web
dsh plugin --profile web add dsh-workbuddy-connect@0.7.9
# restart `dsh web`, then pick the "WorkBuddy" group in the model dropdown
```

### Desktop

```bat
:: The version must match the kernel inside the app (<app>\resources\runtime\primary-runtime\runtime.json -> desktopVersion)
set WORKBUDDY_ELECTRON_BIN=C:\path\to\WorkBuddy.exe   :: only when WorkBuddy lives outside its default path
"<app>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop add dsh-workbuddy-connect@0.7.9
:: quit the app completely (tray included) and relaunch
```

Verify:

```bat
"<app>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop exec dsh-workbuddy-connect doctor
```

`Sign-in state: signed-in` matters; after the relaunch, `%USERPROFILE%\.dsh\.workbuddy-host-heartbeat.json` must be rewritten with the app's live PID. That is the hard proof the provider is running.

### Repair after an update (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File scripts\repair-desktop.ps1
```

It resolves kernel → plugin version (built-in table, then npm `peerDependencies` discovery), installs through the app's bundled CLI, restores `dsh.profile.bundles` and pnpm `allowBuilds`, and verifies with `doctor`.

## Version matrix (hard rule)

| DSH kernel | Plugin |
|---|---|
| 0.2.1-rc.2 | 0.7.9 |
| 0.2.1-rc.1 | 0.7.7 |
| 0.2.0-rc.2 | 0.7.6 |
| 0.2.0-rc.1 | 0.7.0 |
| 0.1.5 – 0.1.7 | 0.6.5 |
| 0.1.2-rc.1 | 0.3.1 |
| 0.1.1-rc.2 | 0.2.6 |

A mismatched pair can stop DSH from starting at all. If your kernel is not listed, look for a plugin version whose `peerDependencies["@deepseek-ai/dsh-llm"]` equals it; if none exists, stop — do not force-install.

## Install as a skill

```sh
# WorkBuddy
git clone <this-repo> ~/.workbuddy/skills/dsh-wb
# Claude Code / other Agent Skills runtimes
git clone <this-repo> ~/.claude/skills/dsh-wb
```

`SKILL.md` is the entry point; the detailed procedures live in `references/` and are loaded on demand.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| No WorkBuddy group in the picker | plugin not loaded | desktop: check the heartbeat; web: check `dsh.profile.bundles` |
| `doctor` says `signed-out` | WorkBuddy not logged in, or installed elsewhere | log in; set `WORKBUDDY_ELECTRON_BIN` |
| `ERR_PNPM_IGNORED_BUILDS` | pnpm blocked postinstall | add `allowBuilds` to the profile's `pnpm-workspace.yaml` (see references) |
| `'pnpm' is not recognized` | the plugin manager needs pnpm | install pnpm 11+ on PATH |
| App opens an empty profile | a user-level `DSH_HOME` redirects it | remove the user-level `DSH_HOME` |
| DSH won't start after an update | kernel/plugin mismatch | run `scripts/repair-desktop.ps1` |

## Boundaries

- It cannot add models WorkBuddy does not offer, and cannot bypass WorkBuddy billing or quota.
- When no plugin release matches the kernel yet, the skill reports it and points at the releases page instead of forcing an install.
- The upstream plugin is a community project, not affiliated with DeepSeek or Tencent. Respect WorkBuddy's terms of service and use it for personal, reasonable use only.

## Credits

- [`corrinehu/dsh-workbuddy-connect`](https://github.com/corrinehu/dsh-workbuddy-connect) — the plugin itself (MIT).
- [`Sliverkiss/workbuddy2api`](https://github.com/Sliverkiss/workbuddy2api), [`franksong2702/dsh-codex-connect`](https://github.com/franksong2702/dsh-codex-connect) — upstream references.
- DeepSeek Harness — the Cordis plugin kernel and desktop runtime.
