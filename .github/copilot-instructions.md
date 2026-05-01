# GitHub Copilot Instructions

This repository stores the shared AI-agent ledger.

Before answering the user, record a summary of what you did:

- Prefer `scripts/record-agent-change.ps1` when running locally.
- In cloud contexts, add a unique event JSON file under `events/YYYY/MM/`.
- Keep summaries under 1024 tokens.
- Include project, kind, commands, files, plan path, and git context when known.
- Do not log secrets.

If the ledger cannot be written, state that in the reply and include a compact `Ledger entry`.

