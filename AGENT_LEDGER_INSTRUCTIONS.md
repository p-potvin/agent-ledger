# Agent Ledger Instructions

Before answering the user, record what you just did in the shared agent ledger.

Preferred local command:

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\record-agent-change.ps1" `
  -Project "<repo name or General Tasks>" `
  -Kind "<plan|commands|code-change|verification|handoff|general>" `
  -Summary "<1024-token max summary of code changed, commands run, or plan made>" `
  -Commands @("<important command 1>", "<important command 2>") `
  -Files @("<important file 1>", "<important file 2>")
```

Rules:

- Use `yyyy-MM-dd HH:mm` local time; the script fills this automatically.
- Keep the summary under 1024 tokens.
- Do not log secrets, tokens, private keys, credentials, or sensitive personal data.
- Do not duplicate an existing event; the script deduplicates matching content.
- If the script or ledger cannot be accessed, tell the user in your reply.
- Use `agent-ledger\CHANGES.md`, the parent `CHANGES.md`, and project roadmaps/todo lists to stay on course when starting a task.
- For cloud agents that cannot access the local filesystem, create a unique event file in `p-potvin/agent-ledger` under `events/YYYY/MM/` when possible. If that is not possible, include a compact "Ledger entry" in the final reply so a local sync can capture it later.

