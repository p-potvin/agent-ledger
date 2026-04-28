# Agent Ledger

Generated from `agent-ledger/events`. Do not edit by hand; use `agent-ledger/scripts/record-agent-change.ps1`.

## 2026-04-28 01:07 - agent-ledger

- Kind: verification
- Actor: AI Agent
- Summary: Verified ledger recording and rendering, added repo-local agent instructions for cloud workers in agent-ledger, and registered the AgentLedgerSync Windows scheduled task to run the sync script every five minutes.
- Commands:
  - `record-agent-change.ps1 smoke test`
  - `render-agent-ledger.ps1 smoke test`
  - `setup-agent-ledger-scheduler.ps1`
- Files:
  - `agent-ledger/AGENTS.md`
  - `agent-ledger/.github/copilot-instructions.md`
  - `agent-ledger/events/2026/04/20260428-010627-414-agent-ledger-b72267df.json`
  - `agent-ledger/CHANGES.md`
  - `CHANGES.md`

## 2026-04-28 01:06 - agent-ledger

- Kind: code-change
- Actor: AI Agent
- Summary: Implemented the local-first agent ledger: append-only JSON event capture, generated CHANGES.md rendering, GitHub sync script, Windows scheduler helper, workspace/provider instruction files, and global Codex/Gemini/Claude/OpenClaw instruction hooks.
- Commands:
  - `gh repo clone p-potvin/agent-ledger agent-ledger`
  - `apply_patch added ledger scripts and instruction files`
- Files:
  - `agent-ledger/scripts/record-agent-change.ps1`
  - `agent-ledger/scripts/render-agent-ledger.ps1`
  - `agent-ledger/scripts/sync-agent-ledger.ps1`
  - `agent-ledger/scripts/setup-agent-ledger-scheduler.ps1`
  - `agent-ledger/AGENT_LEDGER_INSTRUCTIONS.md`
  - `AGENTS.md`
  - `GEMINI.md`
  - `CLAUDE.md`
  - `.github/copilot-instructions.md`
  - `.github/instructions/agent-ledger.instructions.md`
  - `.vscode/settings.json`
  - `C:/Users/Administrator/.codex/AGENTS.md`
  - `C:/Users/Administrator/.gemini/GEMINI.md`
  - `C:/Users/Administrator/.claude/CLAUDE.md`
  - `C:/Users/Administrator/.openclaw/workspace/AGENTS.md`


