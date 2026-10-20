# DSH-WB

**把 WorkBuddy 的模型接进 DeepSeek Harness（DSH）。**

[English](./README.en.md) | 中文

`dsh-workbuddy-connect` 是一个社区 DSH 插件（MIT，上游 [`corrinehu/dsh-workbuddy-connect`](https://github.com/corrinehu/dsh-workbuddy-connect)）。它把已登录的 WorkBuddy 桌面端里可用的模型（GLM-5.x、DeepSeek-V4、Kimi-K3、MiniMax-M3、Hy3/Hy4 等）注册成 DSH 的模型提供方：复用桌面端登录态，不需要 API key，国内版显示为「WorkBuddy」分组，国际版显示为「WorkBuddy AI」分组。

本仓库是一个 **Agent Skill**：把「网页版」和「桌面端」两条接入路径、版本匹配规则、以及我们踩过的坑固化成可复用的操作手册。

## 两条路径

| | 网页版 / TUI | 桌面端（官方 Electron App） |
|---|---|---|
| 适用 | `npx @deepseek-ai/dsh web`、自装 `dsh` CLI、TUI | 官方 DSH 桌面应用 |
| profile | `~/.dsh/profiles/web`，普通 CLI 管理 | `~/.dsh/profiles/desktop`，**由 App 独占管理** |
| 安装方式 | `dsh plugin --profile web add …` | App 自带 CLI：`<app>\resources\runtime\cli\bin\dsh.cmd plugin --profile desktop add …` |
| 难点 | pnpm 缺失、bundles 未注册 | 版本必须匹配、`DSH_HOME` 污染、pnpm 构建批准 |
| 详细步骤 | [`references/web.md`](./references/web.md) | [`references/desktop.md`](./references/desktop.md) |

## 快速开始

### 网页版

```sh
# 依赖：Node 22.19+ / 24+、pnpm 11+、已登录的 WorkBuddy 桌面端
npx @deepseek-ai/dsh@0.2.1-rc.2 web
dsh plugin --profile web add dsh-workbuddy-connect@0.7.9
# 重启 dsh web，在模型下拉里找「WorkBuddy」分组
```

### 桌面端

```bat
:: 版本必须与 App 内置内核一致（读 <app>\resources\runtime\primary-runtime\runtime.json 的 desktopVersion）
set WORKBUDDY_ELECTRON_BIN=C:\path\to\WorkBuddy.exe   :: WorkBuddy 装在非默认路径时才需要
"<app>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop add dsh-workbuddy-connect@0.7.9
:: 完全退出 App（含托盘）再启动
```

装完用 `doctor` 验证：

```bat
"<app>\resources\runtime\cli\bin\dsh.cmd" plugin --profile desktop exec dsh-workbuddy-connect doctor
```

看到 `Sign-in state: signed-in`，并且重启后 `%USERPROFILE%\.dsh\.workbuddy-host-heartbeat.json` 被 App 的活进程重写，才算真的接通。

### 更新后自愈（Windows）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\repair-desktop.ps1
```

自动完成：读内核版本 → 找匹配插件版本（内置表 + npm peerDependencies）→ 用 App 自带 CLI 重装 → 补回 `dsh.profile.bundles` 与 pnpm `allowBuilds` → doctor 验证。

## 版本匹配（硬规则）

| DSH 内核 | 插件版本 |
|---|---|
| 0.2.1-rc.2 | 0.7.9 |
| 0.2.1-rc.1 | 0.7.7 |
| 0.2.0-rc.2 | 0.7.6 |
| 0.2.0-rc.1 | 0.7.0 |
| 0.1.5 – 0.1.7 | 0.6.5 |
| 0.1.2-rc.1 | 0.3.1 |
| 0.1.1-rc.2 | 0.2.6 |

不匹配的组合可能导致 DSH 直接起不来。表里没有你当前的内核时，去 npm 找一个 `peerDependencies["@deepseek-ai/dsh-llm"]` 等于该内核的插件版本；找不到就停下，不要硬装。

## 安装为技能

```sh
# WorkBuddy
git clone <this-repo> ~/.workbuddy/skills/dsh-wb
# Claude Code / 其他 Agent Skills 兼容运行时
git clone <this-repo> ~/.claude/skills/dsh-wb
```

技能入口是 `SKILL.md`；两条路径的完整步骤在 `references/` 下，按需加载。

## 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 模型下拉没有 WorkBuddy 分组 | 插件没被加载 | 桌面端看心跳文件；网页版看 bundles 是否注册 |
| `doctor` 报 `signed-out` | WorkBuddy 没登录 / 装在非默认路径 | 登录桌面端；设置 `WORKBUDDY_ELECTRON_BIN` |
| `ERR_PNPM_IGNORED_BUILDS` | pnpm 拦了 postinstall | 在 profile 的 `pnpm-workspace.yaml` 加 `allowBuilds`（见 references） |
| 报 `'pnpm' is not recognized` | 插件管理器依赖 pnpm | 装 pnpm 11+ 并加入 PATH |
| App 打开的是空 profile | 用户级 `DSH_HOME` 把它带偏了 | 删除用户级 `DSH_HOME` |
| 更新后 DSH 起不来 | 内核/插件版本不匹配 | 跑 `scripts/repair-desktop.ps1` |

## 边界

- 不增加 WorkBuddy 没有的模型，不绕过 WorkBuddy 的额度与计费。
- 内核还没有匹配插件版本时，本技能只会如实报告并指向 releases，不会硬装。
- 上游是社区项目，非 DeepSeek / 腾讯官方；请遵守 WorkBuddy 服务条款，仅用于个人合理使用。

## 致谢

- [`corrinehu/dsh-workbuddy-connect`](https://github.com/corrinehu/dsh-workbuddy-connect)：插件本体（MIT）。
- [`Sliverkiss/workbuddy2api`](https://github.com/Sliverkiss/workbuddy2api)、[`franksong2702/dsh-codex-connect`](https://github.com/franksong2702/dsh-codex-connect)：上游参考实现。
- DeepSeek Harness：Cordis 插件内核与桌面运行时。
