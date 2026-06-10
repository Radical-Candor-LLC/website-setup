# Radical Candor website — one-command setup

Paste this into a terminal on macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/Radical-Candor-LLC/website-setup/main/setup.sh | bash
```

It signs you in to GitHub in your browser (no SSH keys), clones the website repo
to `~/radicalcandorwebsite`, installs the tooling, and launches Claude Code.

> Source of truth for `setup.sh` is `scripts/setup/setup.sh` in
> `Radical-Candor-LLC/radicalcandorwebsite`. Re-publish from there on change.
