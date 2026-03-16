# ops-runner-manager (OpenClaw skill)

A skill that teaches an OpenClaw agent how to manage **ops-runner** jobs using natural language.

This repo contains only the **skill documentation** (SKILL.md + README). It is designed to be portable.

---

## What it does

- job registry CRUD (list/add/update/remove)
- kickoff a job
- inspect status and journal
- (optional) enable/disable monitor
- provides a recommended migration pattern: **cron kickoff-only → ops-runner job**

---

## Local deployment hooks (optional)

Different deployments may have different:

- CLI install locations (systemd PATH can be minimal)
- authorization model for privileged actions
- secrets storage and non-interactive auth needs

Recommended optional local helpers (kept outside the portable skill):

- `scripts/bin/openclaw`: CLI wrapper that resolves the OpenClaw binary reliably in systemd.
- `scripts/ops-runner/_job_wrapper.sh`: centralized handling of `MANUAL_TEST`, `DRY_RUN`, `NO_PUSH`, plus a reusable notify/hook pattern.

---

## Security / authorization

Treat gateway restarts, config edits, systemd unit edits, and cache-clears as privileged actions.

The exact mechanism is environment-specific (TOTP, sudo, approvals, etc.).

---

## License

TBD
