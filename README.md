# Radical Candor website — one-command setup

**macOS or Linux** — paste this into a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/Radical-Candor-LLC/website-setup/main/setup.sh | bash
```

**Windows 11** — paste this into PowerShell:

```powershell
irm https://raw.githubusercontent.com/Radical-Candor-LLC/website-setup/main/setup.ps1 | iex
```

It signs you in to GitHub in your browser (no SSH keys), clones the website repo
to `~/radicalcandorwebsite`, installs the tooling, and launches Claude Code.

> Source of truth for `setup.sh` / `setup.ps1` is `scripts/setup/` in
> `Radical-Candor-LLC/radicalcandorwebsite`. Re-publish from there on change.
