#!/usr/bin/env bash
set -euo pipefail

# Install ops-runner plugin from a LOCAL path into the workspace extensions root.
#
# By default it COPIES files (rsync) into:
#   <workspace>/.openclaw/extensions/ops-runner
#
# With --link, it will replace the dest with a symlink to the local source path.
# This is convenient for development (edits apply immediately), but still requires
# a gateway restart to reload the plugin.
#
# This script does NOT restart the gateway.

WORKSPACE_DEFAULT="$HOME/.openclaw/workspace"
WORKSPACE="${OPENCLAW_WORKSPACE:-$WORKSPACE_DEFAULT}"

SRC=""
LINK=0
BACKUP_AND_REPLACE=0

usage() {
  cat <<'USAGE'
Usage:
  install_ops_runner_from_local.sh --src PATH [--workspace PATH] [--backup-and-replace] [--link]

Notes:
  - Default dest is: <workspace>/.openclaw/extensions/ops-runner
  - If dest exists and is NOT a git repo:
      - default behavior: refuse to overwrite
      - with --backup-and-replace: move dest to ops-runner.bak.<timestamp> then install
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --src)
      SRC="$2"; shift 2 ;;
    --workspace)
      WORKSPACE="$2"; shift 2 ;;
    --backup-and-replace)
      BACKUP_AND_REPLACE=1; shift 1 ;;
    --link)
      LINK=1; shift 1 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$SRC" ]; then
  echo "ERROR: --src is required" >&2
  usage
  exit 1
fi

if [ ! -d "$SRC" ]; then
  echo "ERROR: SRC is not a directory: $SRC" >&2
  exit 2
fi

# basic sanity
if [ ! -f "$SRC/openclaw.plugin.json" ] || [ ! -f "$SRC/index.ts" ]; then
  echo "ERROR: SRC does not look like an ops-runner plugin folder (missing openclaw.plugin.json/index.ts)" >&2
  echo "SRC: $SRC" >&2
  exit 3
fi

DEST="$WORKSPACE/.openclaw/extensions/ops-runner"
PARENT_DIR="$(dirname "$DEST")"
mkdir -p "$PARENT_DIR"

if [ -e "$DEST" ] && [ ! -d "$DEST" ] && [ ! -L "$DEST" ]; then
  echo "ERROR: DEST exists and is not a directory/symlink: $DEST" >&2
  exit 4
fi

# If dest exists and isn't a git repo, protect by default.
if [ -e "$DEST" ]; then
  # resolve if symlink
  if [ -L "$DEST" ]; then
    if [ "$BACKUP_AND_REPLACE" -ne 1 ]; then
      echo "ERROR: DEST is a symlink already: $DEST" >&2
      echo "Refusing to overwrite. Re-run with --backup-and-replace if you want to replace it." >&2
      exit 5
    fi
  elif [ -d "$DEST" ] && [ ! -d "$DEST/.git" ]; then
    if [ "$BACKUP_AND_REPLACE" -ne 1 ]; then
      echo "ERROR: DEST exists but is not a git repo: $DEST" >&2
      echo "Refusing to overwrite. Re-run with --backup-and-replace if you want to replace it." >&2
      exit 6
    fi
  fi

  TS="$(date +%Y%m%d_%H%M%S)"
  BAK="$PARENT_DIR/ops-runner.bak.$TS"
  echo "Backing up existing $DEST -> $BAK" >&2
  mv "$DEST" "$BAK"
fi

if [ "$LINK" -eq 1 ]; then
  echo "Linking $DEST -> $SRC" >&2
  ln -s "$SRC" "$DEST"
else
  echo "Copying $SRC -> $DEST" >&2
  rsync -a --delete --exclude='.git/' --exclude='node_modules/' "$SRC/" "$DEST/"
fi

# final sanity
if [ ! -f "$DEST/openclaw.plugin.json" ] || [ ! -f "$DEST/index.ts" ]; then
  echo "ERROR: DEST plugin files missing after install" >&2
  exit 7
fi

echo "OK" >&2
