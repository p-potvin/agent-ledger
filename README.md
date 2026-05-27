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
- `AGENTS.md` / `CLAUDE.md` - reusable instruction blocks for agent environments.

## Record an event

```powershell
# Single kind
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\record-agent-change.ps1" `
  -Project "vault-flows" `
  -Kind "code-change" `
  -Summary "Updated workflow validation and ran node --test." `
  -Commands @("node --test") `
  -Files @("src/validation.js", "test/validation.test.js")

# Multi-kind (comma-separated — counted under both buckets in dashboards)
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\record-agent-change.ps1" `
  -Project "vault-flows" `
  -Kind "code-change,verification" `
  -Summary "Added helper and confirmed tests pass." `
  -Commands @("node --test") `
  -Files @("src/helper.js")
```

The `kind` field accepts a comma-separated string of canonical values: `plan`, `commands`, `code-change`, `verification`, `handoff`, `general`. Unknown values are accepted but aggregate under `general` in charts. See `vaultwares-docs/docs-content/operations/agent-ledger-schema.mdx` for the full schema.

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

## Project aliases (rename continuity)

`project-aliases.json` at the repo root maps each canonical project name to its historical aliases. When a project is renamed (folder, GitHub remote, or `package.json` identity), append an entry there **before** the rename so existing ledger events keep bucketing under the new canonical name.

The intake (`record-agent-change.ps1`) normalizes the `-Project` argument through the map, so callers using an old name automatically get the new one in fresh events. The work-impact aggregator (`update-work-impact-state.ps1`) and the ledger renderer (`render-agent-ledger.ps1`) apply the same resolver when iterating events, so the dashboard and `CHANGES.md` always group activity under the canonical name even though the historical event JSON files remain frozen with their original `project` field.

After editing `project-aliases.json`, run once to rebuild the cached buckets:

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\update-work-impact.ps1" -FullRebuild
```

The renderer groups activity under the canonical name. Historical aliases are stored for continuity but not displayed in the UI.

## Work impact visualization

Generate a non-technical, bilingual (EN/FR) work-impact report from the ledger events:

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\render-work-impact.ps1"
```

This writes:

- `C:\Users\Administrator\Desktop\Github Repos\agent-ledger\WORK_IMPACT.html`
- `C:\Users\Administrator\Desktop\Github Repos\WORK_IMPACT.html`

## Deployment (protected)

This repo is deployed to ledger.vaultwares.ca for internal use only. It serves `WORK_IMPACT.html` and `CHANGES.html` on the tailnet only for historical and statistical purposes.
**Read DEPLOY.md** to know more details.
