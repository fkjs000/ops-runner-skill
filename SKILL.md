---
name: ops-runner-manager
description: "Install/enable the local ops-runner plugin and manage ops-runner jobs (kickoff/status/journal) + convert cron jobs to kickoff-only. Triggers: kickoff, ops-runner, 產生報告, 定期報告. Use when user asks to install ops-runner, add/modify/delete ops-runner tasks, or migrate a long cron job to systemd-run via ops-runner."
---

# ops-runner manager

This skill is for operating the **ops-runner** OpenClaw plugin (systemd-run kickoff + shared status file), and migrating cron jobs to **kickoff-only**.

## Safety / authorization

- Any action that **restarts the Gateway**, modifies `~/.openclaw/openclaw.json`, edits systemd units/drop-ins, or clears `/tmp/jiti` is **L3**.

### Environment-specific note (Taiwan deployment)
This workspace uses an L3 + TOTP gate (via `$VAULT/vault_manager.py verify_env`) for high-impact system actions.

When publishing/sharing this skill:
- Keep the **concept**: “treat restarts/config edits as privileged and require explicit user confirmation”.
- Make the **mechanism** pluggable: the exact TOTP tool/command may differ per deployment.

In this deployment, before L3 actions: ask the user for a 6-digit TOTP and verify:
- `python3 $VAULT/vault_manager.py verify_env <code>`
Proceed only if `True`.

## Install / enable ops-runner (local)

### Step 0 — Install / update plugin source (non-L3)
Choose ONE:

A) From GitHub (recommended for stable updates)
- Script: `skills/ops-runner-manager/scripts/install_ops_runner_from_github.sh`
- Example:
  - `./skills/ops-runner-manager/scripts/install_ops_runner_from_github.sh --repo git@github.com:fkjs000/ops-runner.git --backup-and-replace`

B) From local path (recommended for development / offline)
- Script: `skills/ops-runner-manager/scripts/install_ops_runner_from_local.sh`
- Example (copy):
  - `./skills/ops-runner-manager/scripts/install_ops_runner_from_local.sh --src /path/to/ops-runner --backup-and-replace`
- Example (link):
  - `./skills/ops-runner-manager/scripts/install_ops_runner_from_local.sh --src /path/to/ops-runner --backup-and-replace --link`

Safety behavior (both scripts):
- If dest exists but is NOT a git repo → **refuse** by default
  - Use `--backup-and-replace` to move it to `ops-runner.bak.<timestamp>` then install

### Step 1 — Confirm plugin files exist
- `~/.openclaw/workspace/.openclaw/extensions/ops-runner/openclaw.plugin.json`
- `~/.openclaw/workspace/.openclaw/extensions/ops-runner/index.ts`

### Step 2 — Enable plugin (config write; treat as L3)
- `openclaw plugins enable ops-runner`

### Step 3 — Allow tools for agent `main` (config write; treat as L3)
- ensure `agents.list[id=main].tools.allow` contains `"ops-runner"`

### Step 4 — (Optional) Create workspace scripts directory (auditable)
- `$HOME/.openclaw/workspace/scripts/ops-runner/`

### Step 5 — Restart Gateway (L3)
- `rm -rf /tmp/jiti/`
- `systemctl --user restart openclaw-gateway.service`

## Local deployment hooks (optional)
- Build workplace helpers under `$HOME/.openclaw/workspace/scripts/` to keep deployment-specific details out of the shared skill text:
  - `scripts/bin/openclaw` (wrapper that probes `command -v` and common install paths) keeps systemd jobs working even when PATH is minimal.
  - `scripts/ops-runner/_job_wrapper.sh` centralizes `MANUAL_TEST`, `DRY_RUN`, `NO_PUSH`, `--notify`, and `--post-run` semantics so each job only has to pass the payload (and can reuse the same notification logic).

### ⭐ Field tips learned in production
- **systemd PATH is minimal**: user units often can't find CLIs installed under `~/.npm-global/bin`.
  - Fix pattern inside job scripts:
    - `export PATH="$HOME/.npm-global/bin:$PATH"`
    - and/or set `AGENT_BROWSER_BIN="$HOME/.npm-global/bin/agent-browser"` as a fallback.
  - Symptom when missing: job logs show `❌ 找不到 agent-browser 執行檔` even though it works interactively.

- **Cron should be kickoff-only for browser jobs**: long-running browser automation is more stable under systemd (ops-runner) than the Gateway cron worker.

- **Rate limits happen** (Yahoo/Telegram/etc): keep external fallbacks best-effort, and prefer a stable primary source (e.g. TWSE) with a secondary (e.g. Yahoo) rather than calling Yahoo every day.

- **TWSE STOCK_DAY query date gotcha**: the `afterTrading/STOCK_DAY` endpoint expects the **first day of the month** (`YYYYMM01`) as `date=...` (it returns the whole month), not the trading day (`YYYYMMDD`).
  - Symptom when wrong: `{"stat":"查詢日期小於99年1月4日，請重新查詢!"}` or missing rows → close price becomes `N/A`.
  - Fix pattern: if NAV date is `2026/03/13` then query `date=20260301` and match row `115/03/13`.

- **Timezones**: Always set `TZ=Asia/Taipei` in scripts and cron schedule `tz` to avoid date mismatches.

- Secrets loader: make each job source `.config/openclaw/secrets.env` (encrypted, workspace only) when it needs `GOG_KEYRING_PASSWORD` or other tokens; keep the wrapper/script agnostic so the skill remains generic.
- When you document future jobs, mention these helpers under a “local hooks” subsection rather than baking the specifics into SKILL.md. That keeps the skill portable while still giving you a repeatable recipe for this deployment.

## Natural-language intents (examples)

When the user says something like:
- "列出 ops-runner jobs" → call `ops_runner_job_list`
- "新增一個 ops-runner job：<jobKey> 跑 <script>" → call `ops_runner_job_add`
- "把 <jobKey> 的 command 改成 <script>" → call `ops_runner_job_update`
- "刪除 <jobKey>" → call `ops_runner_job_remove`
- "啟動 <jobKey>" → call `ops_runner_kickoff`
- "看 <jobKey> 狀態" → call `ops_runner_status`
- "看 <jobKey> 日誌" → call `ops_runner_journal`
- "監控 <jobKey>" → call `ops_runner_monitor`

## Common operations

### Kickoff / observe a job
- Kickoff: `ops_runner_kickoff({"jobKey":"<jobKey>"})`
- Status: `ops_runner_status({"jobKey":"<jobKey>"})`
- Journal: `ops_runner_journal({"jobKey":"<jobKey>","lines":200})`
- Monitor heartbeat: `ops_runner_monitor({"jobKey":"<jobKey>","enabled":true,"intervalSec":30})`

### Migrate an existing cron job → ops-runner (recommended)

**Goal:** cron finishes quickly (no hangs), while the real work runs in **systemd** via ops-runner.

#### Step 1 — Create an ops-runner job (registry)
Add a jobKey that represents the work previously done by cron.

Tool: `ops_runner_job_add`

Minimal fields:
- `jobKey` (string)
- `unitBase` (string) — usually same as jobKey
- `mode` — `singleton` for daily/serial jobs
- `command` — argv array; **command[0] must be an absolute path under the allowed prefix**
  - default allowed prefix is: `$HOME/.openclaw/workspace/scripts/ops-runner/`

Example (auto-update):
```json
{
  "jobKey": "openclaw-auto-update",
  "unitBase": "openclaw-auto-update",
  "mode": "singleton",
  "command": ["$HOME/.openclaw/workspace/scripts/ops-runner/auto_update_openclaw.sh"],
  "maxRuntimeSec": 1800,
  "heartbeatTtlSec": 240,
  "staleGraceSec": 30,
  "restartPolicy": "safe"
}
```

Example (guardian healthcheck):
```json
{
  "jobKey": "openclaw-guardian-check",
  "unitBase": "openclaw-guardian-check",
  "mode": "singleton",
  "command": ["$HOME/.openclaw/workspace/scripts/ops-runner/guardian_system.sh"],
  "maxRuntimeSec": 600,
  "heartbeatTtlSec": 180,
  "staleGraceSec": 30,
  "restartPolicy": "safe"
}
```

#### Step 2 — Patch cron payload to kickoff-only
Update the cron job payload so it **only** calls:
- `ops_runner_kickoff({"jobKey":"<jobKey>"})`

Keep cron delivery either:
- `announce` (short: unitName + alreadyRunning), or
- `none` (recommended if the systemd job already sends its own Telegram report).

#### Step 3 — Verify
- Run cron manually once: `cron(action="run", jobId="<cronJobId>")`
- Confirm cron run finishes (no stuck `runningAtMs`)
- Confirm systemd unit runs:
  - `ops_runner_status({"jobKey":"<jobKey>"})`
  - `ops_runner_journal({"jobKey":"<jobKey>","lines":200})`

### Convert a cron job to kickoff-only (when jobKey already exists)
- Patch cron payload to call `ops_runner_kickoff` only.
- Verify with a manual cron run.

### Delete / disable a cron job that keeps getting stuck

- Prefer `cron(action="update", patch={enabled:false})`.
- If a job is stuck due to `runningAtMs`:
  - Prefer diagnosing first (logs + runs jsonl).
  - As a last resort, clear only the job’s `state.runningAtMs` field (do not change schedule/payload).

## Notes about portability

- ops-runner is Linux + systemd user-service based.
- For portability, avoid hardcoding usernames/absolute home paths; prefer deriving paths from `$HOME`.
