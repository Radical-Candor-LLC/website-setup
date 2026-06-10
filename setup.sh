#!/usr/bin/env bash
#
# setup.sh — one-command onboarding loader for the Radical Candor website repo.
#
# Hosted publicly (Radical-Candor-LLC/website-setup). Contains NO secrets: it
# installs git + the GitHub CLI, signs you in to GitHub in your browser (no SSH
# keys), clones the PRIVATE repo to ~/radicalcandorwebsite, and hands off to that
# repo's bootstrap.sh — which installs the rest and launches Claude Code.
#
#   curl -fsSL https://raw.githubusercontent.com/Radical-Candor-LLC/website-setup/main/setup.sh | bash
#
set -euo pipefail

REPO_SLUG="Radical-Candor-LLC/radicalcandorwebsite"
DEST="${RC_DIR:-$HOME/radicalcandorwebsite}"

if [[ -t 1 ]]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; X=$'\033[0m'
else B=''; G=''; Y=''; R=''; X=''; fi
step() { printf '\n%s→ %s%s\n' "$B" "$*" "$X"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$X" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$Y" "$X" "$*"; }
err()  { printf '  %s✗%s %s\n' "$R" "$X" "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# We arrive via `curl | bash`, so our own stdin is the pipe. Every interactive
# step (gh sign-in, and the handed-off bootstrap) must read the terminal at
# /dev/tty. If there's no terminal at all, we can't prompt — bail clearly.
if ! { true 0</dev/tty; } 2>/dev/null; then
  err "No terminal available. Open Terminal and paste this command there."
  exit 1
fi

OS="$(uname -s)"

# Pick up a brew that's installed but not yet on PATH.
brew_into_path() {
  have brew && return 0
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && { eval "$("$b" shellenv)"; break; }
  done
  have brew
}

if [[ "$OS" == Darwin ]] && ! brew_into_path; then
  step "Installing Homebrew (needed for git + gh)"
  # Interactive installer reads /dev/tty so it can prompt for your password even
  # though our stdin is the curl pipe.
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty \
    || warn "Homebrew installer exited non-zero — see output above"
  brew_into_path || { err "Homebrew still not on PATH. Install it, then re-run."; exit 1; }
fi

install_pkg() {  # install_pkg <brew-formula> <apt-package>
  case "$OS" in
    Darwin) brew list --formula "$1" >/dev/null 2>&1 || brew install "$1" ;;
    Linux)  sudo apt-get update -qq && sudo apt-get install -y -qq "$2" ;;
  esac
}

have git || { step "Installing git"; install_pkg git git; }

if ! have gh; then
  step "Installing GitHub CLI (gh)"
  if [[ "$OS" == Darwin ]]; then
    install_pkg gh gh
  else
    sudo apt-get update -qq
    sudo apt-get install -y -qq curl
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq gh
  fi
fi
have gh || { err "Couldn't install the GitHub CLI. Install gh, then re-run."; exit 1; }

# GitHub sign-in (browser; no SSH keys). Configures git's HTTPS credential helper.
if gh auth status >/dev/null 2>&1; then
  ok "GitHub already signed in"
else
  step "Sign in to GitHub (a browser window will open)"
  gh auth login --hostname github.com --git-protocol https --web </dev/tty \
    || { err "GitHub sign-in didn't complete. Re-run this command to retry."; exit 1; }
fi

# Clone (or update) the private repo.
if [[ -d "$DEST/.git" ]]; then
  step "Updating existing checkout at $DEST"
  git -C "$DEST" pull --ff-only || warn "couldn't fast-forward $DEST — continuing with what's there"
else
  step "Cloning $REPO_SLUG → $DEST"
  if ! gh repo clone "$REPO_SLUG" "$DEST"; then
    err "Couldn't clone $REPO_SLUG."
    err "If you just created your GitHub account, ask Jason to grant it access to"
    err "the repo, then re-run this command."
    exit 1
  fi
fi
ok "Code is at $DEST"

# Hand off to the repo's bootstrap (installs the rest, launches Claude Code).
step "Running setup"
exec bash "$DEST/bootstrap.sh" </dev/tty
