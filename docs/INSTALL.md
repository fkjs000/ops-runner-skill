# Installation notes (ops-runner-manager skill)

This repository contains a skill that helps an OpenClaw agent:
- install/update the `ops-runner` plugin (from GitHub or local path)
- manage jobs via ops-runner tools

## Install/update plugin source

Choose one:

### From GitHub
- `scripts/install_ops_runner_from_github.sh --repo git@github.com:fkjs000/ops-runner.git --backup-and-replace`

### From local path
- `scripts/install_ops_runner_from_local.sh --src /path/to/ops-runner --backup-and-replace`
- add `--link` if you want a symlink install for development

## Enable + restart
Enabling plugins and restarting the gateway is deployment-specific and often privileged.
Follow your environment’s authorization procedure.
