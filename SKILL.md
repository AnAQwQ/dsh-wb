---
name: dsh-wb
description: Install, verify, and repair the WorkBuddy model provider inside DeepSeek Harness (DSH) — both the Web/TUI install and the official Electron desktop app. Use when the user wants WorkBuddy models (GLM-5.x, DeepSeek-V4, Kimi-K3, MiniMax-M3, Hy3/Hy4, …) to appear in DSH's model picker, or when the "WorkBuddy" model group disappears after a DSH or WorkBuddy update.
agent_created: true
---

# DSH-WB — WorkBuddy models inside DeepSeek Harness

`dsh-workbuddy-connect` is a community DSH plugin (MIT, upstream `github.com/corrinehu/dsh-workbuddy-connect`). It registers the models already available in a logged-in WorkBuddy desktop app as a DSH model provider. It reuses the desktop app's session — no API key, no separate OAuth. The CN and international builds of WorkBuddy each surface their own group: `WorkBuddy` and `WorkBuddy AI`.

## Pick the path first

| What the user runs | Read | Why |
|---|---|---|
| Official DSH **desktop** app (Electron) | `references/desktop.md` | The `desktop` profile is exclusively managed by the app. Only its bundled CLI may touch it; the independent `dsh` CLI refuses with `profile "desktop" is managed exclusively by the Electron application`. |
| `npx @deepseek-ai/dsh web`, a `dsh` CLI install, or TUI | `references/web.md` | Simplest, no app-managed profile. TUI notes included. |
| Worked before, broke after an update | `scripts/repair-desktop.ps1` (Windows) or `references/web.md` § Repair | Re-match plugin ↔ kernel, restore bundle registration. |

## Non-negotiables

1. **Version match or nothing.** Plugin and kernel are locked in pairs; a mismatch can stop DSH from starting at all.
   | DSH kernel | Plugin |
   |---|---|
   | 0.2.1-rc.2 | 0.7.9 |
   | 0.2.1-rc.1 | 0.7.7 |
   | 0.2.0-rc.2 | 0.7.6 |
   | 0.2.0-rc.1 | 0.7.0 |
   | 0.1.5 – 0.1.7 | 0.6.5 |
   | 0.1.2-rc.1 | 0.3.1 |
   | 0.1.1-rc.2 | 0.2.6 |

   Read the kernel from the installed runtime: desktop app → `<app>/resources/runtime/primary-runtime/runtime.json` → `desktopVersion`; CLI/web → `dsh --version`. If the kernel is not in this table, query npm for a plugin version whose `peerDependencies["@deepseek-ai/dsh-llm"]` equals the kernel. If none exists, **stop and report** — never force-install an unverified pair.
2. **Upstream only.** `corrinehu/dsh-workbuddy-connect`. A same-named `masknull/…` repository is a downstream fork that lags the kernel line.
3. **Never hand-edit an app-managed desktop profile as the primary method.** Use the app's bundled CLI (it runs `runCli({ manageDesktopProfile: true })`, the sanctioned "reserved-profile plugin access"). File edits are a fallback for repair only.
4. **Verify by behavior.** Success = `doctor` reports `signed-in` **and** the WorkBuddy group appears in the model picker **and** one short reply comes back. Exit codes alone prove nothing.

## Verify (both paths)

```sh
# web
dsh plugin --profile web exec dsh-workbuddy-connect doctor
# desktop (Windows; the app's bundled CLI)
"<app>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop exec dsh-workbuddy-connect doctor
```

Expect `Desktop auth file: present … encrypted` and `Sign-in state: signed-in`. In the desktop app, `Host bundle: running (pid …)` plus a freshly rewritten `<DSH_HOME>/.workbuddy-host-heartbeat.json` is the hard proof the provider is live. Then: model picker (input-box dropdown or `/model`) → group `WorkBuddy` (CN) / `WorkBuddy AI` (international) → pick a model → send one message.

## Common failures → fixes

| Symptom | Cause | Fix |
|---|---|---|
| No WorkBuddy group in the picker | plugin not loaded | desktop: check the heartbeat (references/desktop.md § Verification); web: check the `dsh web` process is the patched install |
| `doctor` says `signed-out` | WorkBuddy not logged in, or its install path is non-default | log in to the desktop app; set `WORKBUDDY_ELECTRON_BIN` to the real `WorkBuddy.exe` |
| `ERR_PNPM_IGNORED_BUILDS` | pnpm blocks postinstall scripts | add `allowBuilds: { '@google/genai': true, protobufjs: true }` to the profile's `pnpm-workspace.yaml` |
| `'pnpm' is not recognized` | the plugin manager shells out to pnpm | install pnpm 11+ and put it on PATH |
| App opens a fresh, empty profile | a **user-level** `DSH_HOME` env var redirects it | remove the user-level `DSH_HOME` |
| DSH won't start after an update | kernel/plugin mismatch | run `scripts/repair-desktop.ps1` |
| Plugin loads but models fail at chat time | WorkBuddy API/credentials changed upstream | update the plugin to the version matching the current kernel; if none, wait for the upstream release |

## What this skill is not

It cannot add models WorkBuddy does not offer, cannot bypass WorkBuddy billing/quota, and cannot fix a kernel with no published matching plugin. In those cases, report honestly and point at `github.com/corrinehu/dsh-workbuddy-connect/releases`.
