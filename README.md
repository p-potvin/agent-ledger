# agent-ledger

This repo is the append-only ledger for AI-agent activity across local and cloud work. It records code changes, commands, plans, verification, handoffs, and other useful activity that may not appear in a git diff.

## Layout

- `events/YYYY/MM/*.json` - source-of-truth event records. These are conflict-resistant because every entry gets its own file.
- `CHANGES.md` - generated readable ledger for this repo.
- `CHANGES.html` - generated browser-ready ledger with expandable sections.
- `..\CHANGES.md` - generated mirror at the parent workspace root for local agents.
- `..\CHANGES.html` - generated browser-ready mirror at the parent workspace root.
- `scripts/record-agent-change.ps1` - local intake command for agents and hooks.
- `scripts/render-agent-ledger.ps1` - rebuilds readable ledgers from event files.
- `scripts/sync-agent-ledger.ps1` - pulls, renders, commits, and pushes queued ledger changes.
- `scripts/setup-agent-ledger-scheduler.ps1` - registers a Windows scheduled task for automatic sync.
- `AGENT_LEDGER_INSTRUCTIONS.md` - reusable instruction block for agent environments.

## Record an event

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\record-agent-change.ps1" `
  -Project "vault-flows" `
  -Kind "code-change" `
  -Summary "Updated workflow validation and ran node --test." `
  -Commands @("node --test") `
  -Files @("src/validation.js", "test/validation.test.js")
```

The script deduplicates matching content, writes an event file, and regenerates both readable ledgers.

## Sync to GitHub

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\sync-agent-ledger.ps1"
```

To automate sync every five minutes:

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\setup-agent-ledger-scheduler.ps1"
```

The sync script pulls with rebase, renders `CHANGES.md`, commits queued ledger files, and pushes to `main`.

## View the ledger

Open `C:\Users\Administrator\Desktop\Github Repos\CHANGES.html` in Firefox for a quick-glance ledger with clickable expandable entries. Use `CHANGES.md` when viewing on GitHub or in a Markdown previewer such as VS Code.
