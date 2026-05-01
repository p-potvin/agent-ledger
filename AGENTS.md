# Agent Ledger Repo Instructions

This repo is the shared source of truth for AI-agent activity.

Before answering the user, record what you did:

- Local agents should run `scripts/record-agent-change.ps1`.
- Cloud agents that cannot access the local script should create a unique JSON event file under `events/YYYY/MM/`.
- Use the schema already present in existing event files.
- Keep summaries under 1024 tokens.
- Do not log secrets.
- Run `scripts/render-agent-ledger.ps1` when local PowerShell is available to regenerate `CHANGES.md`.

If you cannot write the ledger, tell the user in your reply and include a compact `Ledger entry` for later capture.

