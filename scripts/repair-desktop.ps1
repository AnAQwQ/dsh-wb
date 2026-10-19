# DSH-WB · desktop repair (Windows)
# Re-matches dsh-workbuddy-connect to the kernel built into the official DSH desktop app,
# restores bundle registration and pnpm build approvals, then verifies with the plugin's doctor.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File repair-desktop.ps1
#   powershell -ExecutionPolicy Bypass -File repair-desktop.ps1 -CheckOnly
#   powershell -ExecutionPolicy Bypass -File repair-desktop.ps1 -Restore
#   powershell -ExecutionPolicy Bypass -File repair-desktop.ps1 -AppDir "D:\DSH" -WorkBuddyExe "D:\WorkBuddy\WorkBuddy.exe"
param(
  [string]$AppDir,
  [string]$ProfileDir = (Join-Path $env:USERPROFILE '.dsh\profiles\desktop'),
  [string]$WorkBuddyExe,
  [string]$BackupRoot = (Join-Path $env:USERPROFILE '.dsh\backups'),
  [switch]$CheckOnly,
  [switch]$Restore
)

$ErrorActionPreference = 'Stop'
$PluginName = 'dsh-workbuddy-connect'

function Step($m) { Write-Host "[*] $m" }
function Ok($m)   { Write-Host "[OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "[X] $m" -ForegroundColor Red }
function WriteText($path, $text) { [System.IO.File]::WriteAllText($path, $text) }

function Find-AppDir {
  $cands = @(
    'D:\DSH',
    (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeek Harness'),
    (Join-Path $env:ProgramFiles 'DeepSeek Harness'),
    (Join-Path ${env:ProgramFiles(x86)} 'DeepSeek Harness')
  )
  foreach ($c in $cands) {
    if ($c -and (Test-Path (Join-Path $c 'DeepSeek Harness.exe'))) { return $c }
  }
  return $null
}

function Find-WorkBuddy {
  if ($WorkBuddyExe -and (Test-Path $WorkBuddyExe)) { return $WorkBuddyExe }
  $envv = [Environment]::GetEnvironmentVariable('WORKBUDDY_ELECTRON_BIN', 'Process')
  if ($envv -and (Test-Path $envv)) { return $envv }
  $def = Join-Path $env:LOCALAPPDATA 'Programs\WorkBuddy\WorkBuddy.exe'
  if (Test-Path $def) { return $def }
  return $null
}

function Find-Npm {
  $c = Get-Command npm.cmd -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  return $null
}

# Known kernel -> plugin pairs (source: corrinehu/dsh-workbuddy-connect README)
$known = @{
  '0.2.1-rc.2' = '0.7.8'
  '0.2.1-rc.1' = '0.7.7'
  '0.2.0-rc.2' = '0.7.6'
  '0.2.0-rc.1' = '0.7.0'
  '0.1.7-rc.2' = '0.6.5'; '0.1.7-rc.1' = '0.6.5'
  '0.1.6' = '0.6.5'; '0.1.5' = '0.6.5'
}

# Unknown kernel: ask npm for a plugin whose peerDependency on the kernel matches.
function Resolve-PluginVersion($kv) {
  if ($known.ContainsKey($kv)) { return @{ version = $known[$kv]; source = 'built-in table' } }
  $npm = Find-Npm
  if (-not $npm) { return $null }
  try {
    $vers = & $npm view $PluginName versions --json 2>$null | ConvertFrom-Json
    $sorted = @($vers | Sort-Object { try { [version]$_ } catch { [version]'0.0.0' } } -Descending)
    foreach ($v in ($sorted | Select-Object -First 8)) {
      $peer = & $npm view "$PluginName@$v" peerDependencies --json 2>$null | ConvertFrom-Json
      if ($peer.'@deepseek-ai/dsh-llm' -eq $kv) { return @{ version = "$v"; source = 'npm peerDependencies' } }
    }
  } catch { }
  return $null
}

# A user-level DSH_HOME redirects the app to another (empty) profile. Remove it.
$userHome = [Environment]::GetEnvironmentVariable('DSH_HOME', 'User')
if ($userHome) {
  Warn "user-level DSH_HOME=$userHome can make the app open an empty profile"
  if (-not $CheckOnly) {
    [Environment]::SetEnvironmentVariable('DSH_HOME', $null, 'User')
    Ok 'removed user-level DSH_HOME'
  }
}
Remove-Item Env:DSH_HOME -ErrorAction SilentlyContinue

if (-not $AppDir) { $AppDir = Find-AppDir }
if (-not $AppDir) { Bad 'DSH desktop app not found; pass -AppDir <install dir>'; exit 3 }

$Cli         = Join-Path $AppDir 'resources\runtime\cli\bin\dsh.cmd'
$RuntimeJson = Join-Path $AppDir 'resources\runtime\primary-runtime\runtime.json'
$PkgPath     = Join-Path $ProfileDir 'package.json'
$WsPath      = Join-Path $ProfileDir 'pnpm-workspace.yaml'

if (-not (Test-Path $Cli))         { Bad "bundled CLI not found: $Cli"; exit 3 }
if (-not (Test-Path $RuntimeJson)) { Bad "runtime manifest not found: $RuntimeJson"; exit 3 }

$wb = Find-WorkBuddy
if ($wb) { $env:WORKBUDDY_ELECTRON_BIN = $wb; Step "WorkBuddy: $wb" }
else { Warn 'WorkBuddy.exe not found automatically; credential probing may rely on the registry' }

$kernel = (Get-Content $RuntimeJson -Raw | ConvertFrom-Json).desktopVersion
Step "DSH kernel: $kernel"

$want = Resolve-PluginVersion $kernel
if ($null -eq $want) {
  Bad "no plugin release matches kernel $kernel yet. Check https://github.com/corrinehu/dsh-workbuddy-connect/releases before upgrading DSH."
  exit 2
}
Step "plugin version: $($want.version) (source: $($want.source))"

if ($Restore) {
  $bk = Get-ChildItem $BackupRoot -Directory -Filter 'dsh-desktop-*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
  if ($bk) {
    if ($CheckOnly) {
      Step "(-CheckOnly) would restore from $($bk.FullName)"
    } else {
      foreach ($f in @('package.json','pnpm-workspace.yaml','cordis.patch.yml','pnpm-lock.yaml')) {
        $src = Join-Path $bk.FullName $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $ProfileDir $f) -Force }
      }
      Ok "restored from $($bk.FullName)"
    }
  } else { Warn "no dsh-desktop-* backup under $BackupRoot" }
}

if (-not (Test-Path $PkgPath)) { Bad "profile not found: $PkgPath (launch the app once to create it)"; exit 3 }
$pkg  = Get-Content $PkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$have = $null
if ($pkg.dependencies.PSObject.Properties.Name -contains $PluginName) { $have = $pkg.dependencies.$PluginName }
$nmPkg = Join-Path $ProfileDir "node_modules\$PluginName\package.json"
$onDisk = $null
if (Test-Path $nmPkg) { $onDisk = (Get-Content $nmPkg -Raw -Encoding UTF8 | ConvertFrom-Json).version }
$bundles = @($pkg.dsh.profile.bundles)
$needsInstall = ($have -ne $want.version) -or ($onDisk -ne $want.version)
$needsBundle  = ($bundles -notcontains $PluginName)
$wsText = if (Test-Path $WsPath) { Get-Content $WsPath -Raw -Encoding UTF8 } else { '' }
$needsBuilds = ($wsText -notmatch "'@google/genai'\s*:\s*true") -or ($wsText -notmatch "protobufjs\s*:\s*true")

if (-not $needsInstall -and -not $needsBundle -and -not $needsBuilds) {
  Ok "plugin in place ($($want.version)); bundle list and build approvals are fine"
} elseif ($CheckOnly) {
  if ($needsInstall) { Warn "version mismatch: installed $(if($have){$have}else{'none'}), expected $($want.version)" }
  if ($needsBundle)  { Warn "dsh.profile.bundles is missing $PluginName" }
  if ($needsBuilds)  { Warn "pnpm-workspace.yaml lacks the allowBuilds approvals" }
  Warn 'CheckOnly: nothing changed'
} else {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $bkDir = Join-Path $BackupRoot "dsh-desktop-$stamp"
  New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
  Copy-Item $PkgPath, $WsPath -Destination $bkDir -Force -ErrorAction SilentlyContinue
  Step "backed up to $bkDir"

  if ($needsInstall) {
    Step "installing $PluginName@$($want.version) via the app's bundled CLI ..."
    $out = & $Cli plugin --profile desktop add "$PluginName@$($want.version)" 2>&1
    if ($LASTEXITCODE -ne 0) {
      Bad "install failed (exit $LASTEXITCODE); tail:"
      $out | Select-Object -Last 12 | ForEach-Object { Write-Host "    $_" }
      exit 3
    }
    Ok 'installed'
  }

  $pkg = Get-Content $PkgPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $bundles = @($pkg.dsh.profile.bundles)
  if ($bundles -notcontains $PluginName) {
    $pkg.dsh.profile.bundles = @($bundles + $PluginName)
    WriteText $PkgPath (($pkg | ConvertTo-Json -Depth 10) + "`n")
    Ok "appended $PluginName to dsh.profile.bundles"
  }
  $wsText = if (Test-Path $WsPath) { Get-Content $WsPath -Raw -Encoding UTF8 } else { "packages:`n  - .`n`nnodeLinker: hoisted`nautoInstallPeers: false`n" }
  if ($wsText -notmatch "'@google/genai'\s*:\s*true" -or $wsText -notmatch "protobufjs\s*:\s*true") {
    if ($wsText -match 'allowBuilds\s*:') {
      $wsText = $wsText -replace "'@google/genai'\s*:\s*(true|false|set this to true or false)", "'@google/genai': true"
      $wsText = $wsText -replace "protobufjs\s*:\s*(true|false|set this to true or false)", 'protobufjs: true'
    } else {
      $wsText = $wsText.TrimEnd() + "`nallowBuilds:`n  '@google/genai': true`n  protobufjs: true`n"
    }
    WriteText $WsPath $wsText
    Ok 'allowBuilds written'
  }
}

Step 'running plugin doctor ...'
$doc = & $Cli plugin --profile desktop exec $PluginName doctor 2>&1
$docText = ($doc | Out-String)
if ($docText -match 'Sign-in state:\s*signed-in') { Ok 'WorkBuddy sign-in: signed-in' }
elseif ($docText -match 'Sign-in state:\s*signed-out') {
  Warn 'installed but signed-out. If WorkBuddy just updated: confirm the desktop app is logged in; otherwise check for a newer plugin release.'
}
if ($docText -match 'Host bundle:\s*running') { Ok 'host bundle: running' }
else { Warn 'host bundle not running in this CLI context (expected); confirm via the model picker after restarting the app' }

$hb = Join-Path (Split-Path (Split-Path $ProfileDir -Parent) -Parent) '.workbuddy-host-heartbeat.json'
if (Test-Path $hb) {
  $j = Get-Content $hb -Raw | ConvertFrom-Json
  $alive = [bool](Get-Process -Id $j.pid -ErrorAction SilentlyContinue)
  Step ("heartbeat: {0}  pid={1} alive={2}" -f (Get-Item $hb).LastWriteTime, $j.pid, $alive)
}

Warn 'If anything was repaired: quit DSH completely (including the tray) and relaunch.'
Ok 'done'
