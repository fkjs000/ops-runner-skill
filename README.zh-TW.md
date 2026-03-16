# ops-runner-manager（OpenClaw skill）

`ops-runner-manager` 是一個 skill，目標是讓 OpenClaw agent 能用自然語言管理 `ops-runner`：

- job CRUD（list/add/update/remove）
- kickoff 執行
- 查 status / 看 journal
-（可選）monitor/heartbeat
- 提供標準遷移路線：**cron kickoff-only → ops-runner job（systemd 執行）**

此 repo 僅包含 skill 文件（SKILL.md + README），不包含任何個人化 jobs 或 secrets。

---

## Local deployment hooks（可選）

不同部署環境常見差異：
- systemd 的 PATH 很精簡
- privileged action 的授權機制（TOTP / sudo / approvals）各不相同
- 某些工具需要非互動環境的 secrets 供給

因此建議把環境特有的做法放在 workspace helper（而不是寫死在 skill）：

- `scripts/bin/openclaw`：openclaw CLI wrapper（systemd 也能找到）
- `scripts/ops-runner/_job_wrapper.sh`：統一 `MANUAL_TEST` / `DRY_RUN` / `NO_PUSH` + 可重用 notify/hook

---

## 安全 / 授權

像是重啟 gateway、修改設定、調整 systemd、清 cache 這類高影響操作，應視為 privileged actions。

授權方式依部署而定（本 repo 不綁定特定機制）。

---

## License

TBD
