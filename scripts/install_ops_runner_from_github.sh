#!/usr/bin/env bash
set -euo pipefail

# Clone or fast-forward update ops-runner plugin from GitHub into the workspace extensions root.
#
# This script does NOT restart the OpenClaw gateway (that is typically a privileged/L3 action in many deployments).
# After updating, enable the plugin (if needed) and restart the gateway using your environment's auth procedure.

REPO_URL_DEFAULT="git@github.com:fkjs000/ops-runner.git"
WORKSPACE_DEFAULT="$HOME/.openclaw/workspace"

REPO_URL="$REPO_URL_DEFAULT"
WORKSPACE="${OPENCLAW_WORKSPACE:-$WORKSPACE_DEFAULT}"
BACKUP_AND_REPLACE=0

usage() {
  cat <<'USAGE'
Usage:
  install_ops_runner_from_github.sh [--repo GIT_URL] [--workspace PATH] [--backup-and-replace]

Notes:
  - Default dest is: <workspace>/.openclaw/extensions/ops-runner
  - If dest exists and is NOT a git repo:
      - default behavior: refuse to overwrite
      - with --backup-and-replace: move dest to ops-runner.bak.<timestamp> then clone
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO_URL="$2"; shift 2 ;;
    --workspace)
      WORKSPACE="$2"; shift 2 ;;
    --backup-and-replace)
      BACKUP_AND_REPLACE=1; shift 1 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      # backward-compat: allow first arg to be repo url
      if [ "$1" != "" ] && [[ "$1" == git@* || "$1" == https://* ]]; then
        REPO_URL="$1"; shift 1
      else
        echo "Unknown arg: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

DEST="$WORKSPACE/.openclaw/extensions/ops-runner"
PARENT_DIR="$(dirname "$DEST")"

mkdir -p "$PARENT_DIR"

if [ -e "$DEST" ] && [ ! -d "$DEST" ]; then
  echo "ERROR: DEST exists and is not a directory: $DEST" >&2
  exit 2
fi

if [ -d "$DEST" ] && [ ! -d "$DEST/.git" ]; then
  # existing non-git directory
  if [ "$BACKUP_AND_REPLACE" -ne 1 ]; then
    echo "ERROR: DEST exists but is not a git repo: $DEST" >&2
    echo "Refusing to overwrite. Re-run with --backup-and-replace if you want to replace it." >&2
    exit 3
  fi
  TS="$(date +%Y%m%d_%H%M%S)"
  BAK="$PARENT_DIR/ops-runner.bak.$TS"
  echo "Backing up existing $DEST -> $BAK" >&2
  mv "$DEST" "$BAK"
fi

if [ ! -d "$DEST/.git" ]; then
  echo "Cloning $REPO_URL -> $DEST" >&2
  git clone --depth 1 "$REPO_URL" "$DEST"
else
  echo "Updating existing repo in $DEST" >&2
  git -C "$DEST" remote set-url origin "$REPO_URL" >/dev/null 2>&1 || true
  git -C "$DEST" fetch --prune origin
  git -C "$DEST" pull --ff-only
fi

echo "---" >&2
echo "Installed/updated ops-runner at:" >&2
echo "  $DEST" >&2

git -C "$DEST" log -n 1 --oneline --decorate >&2

# Basic sanity check
if [ ! -f "$DEST/openclaw.plugin.json" ] || [ ! -f "$DEST/index.ts" ]; then
  echo "ERROR: plugin files missing after clone/update (openclaw.plugin.json/index.ts)" >&2
  exit 4
fi

echo "OK" >&2
