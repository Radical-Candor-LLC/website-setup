<#
.SYNOPSIS
  Windows 11 one-command onboarding loader for the Radical Candor website repo.

.DESCRIPTION
  Hosted publicly (Radical-Candor-LLC/website-setup). Contains NO secrets: it
  installs git + the GitHub CLI via winget, signs you in to GitHub in your
  browser (no SSH keys), clones the PRIVATE repo to %USERPROFILE%\radicalcandorwebsite,
  and hands off to that repo's bootstrap.ps1 — which installs the rest and
  launches Claude Code.

      irm https://raw.githubusercontent.com/Radical-Candor-LLC/website-setup/main/setup.ps1 | iex
#>
#Requires -Version 5.1

# Deliberately NOT 'Stop' — gh / git / winget write progress and status to
# stderr (e.g. `gh auth status` prints "You are not logged in…" on exit 1), and
# under EAP='Stop' Windows PowerShell turns those stderr lines into terminating
# NativeCommandErrors that a `*> $null` redirect won't suppress, aborting setup.
# Fatal conditions are handled explicitly via Have / $LASTEXITCODE + `exit 1`.
$ErrorActionPreference = 'Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$RepoSlug = 'Radical-Candor-LLC/radicalcandorwebsite'
$Dest = if ($env:RC_DIR) { $env:RC_DIR } else { Join-Path $HOME 'radicalcandorwebsite' }

function Step($m) { Write-Host "`n→ $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "  ✓ $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  ⚠ $m" -ForegroundColor Yellow }
function Err($m)  { Write-Host "  ✗ $m" -ForegroundColor Red }
function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# winget updates persisted PATH but not the live process; re-read after installs.
function Update-SessionPath {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

if (-not (Have winget)) {
  Err "winget (App Installer) not found. On Windows 11 it ships by default —"
  Err "update 'App Installer' from the Microsoft Store, then re-run this command."
  exit 1
}

if (-not (Have git)) {
  Step "Installing git"
  winget install --id Git.Git -e --source winget `
    --accept-source-agreements --accept-package-agreements --silent
  Update-SessionPath
}
if (-not (Have git)) { Err "Couldn't install git. Install it, then re-run."; exit 1 }

if (-not (Have gh)) {
  Step "Installing GitHub CLI (gh)"
  winget install --id GitHub.cli -e --source winget `
    --accept-source-agreements --accept-package-agreements --silent
  Update-SessionPath
}
if (-not (Have gh)) { Err "Couldn't install the GitHub CLI. Install gh, then re-run."; exit 1 }

# GitHub sign-in (browser; no SSH keys). Configures git's HTTPS credential helper.
gh auth status *> $null
if ($LASTEXITCODE -eq 0) {
  Ok "GitHub already signed in"
} else {
  Step "Sign in to GitHub (a browser window will open)"
  gh auth login --hostname github.com --git-protocol https --web
  if ($LASTEXITCODE -ne 0) { Err "GitHub sign-in didn't complete. Re-run this command to retry."; exit 1 }
}

# Clone (or update) the private repo.
if (Test-Path (Join-Path $Dest '.git')) {
  Step "Updating existing checkout at $Dest"
  git -C $Dest pull --ff-only
  if ($LASTEXITCODE -ne 0) { Warn "couldn't fast-forward $Dest — continuing with what's there" }
} else {
  Step "Cloning $RepoSlug → $Dest"
  gh repo clone $RepoSlug $Dest
  if ($LASTEXITCODE -ne 0) {
    Err "Couldn't clone $RepoSlug."
    Err "If you just created your GitHub account, ask Jason to grant it access to"
    Err "the repo, then re-run this command."
    exit 1
  }
}
Ok "Code is at $Dest"

# Hand off to the repo's bootstrap (installs the rest, launches Claude Code).
# Use -ExecutionPolicy Bypass so the downloaded .ps1 runs regardless of the
# machine's policy.
Step "Running setup"
$boot = Join-Path $Dest 'bootstrap.ps1'
$ps = if (Have pwsh) { 'pwsh' } else { 'powershell' }
& $ps -NoProfile -ExecutionPolicy Bypass -File $boot
