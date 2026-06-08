# agent-ledger

This repo is the append-only ledger for AI-agent activity across local and cloud work. It records code changes, commands, plans, verification, handoffs, and other useful activity that may not appear in a git diff.

## Layout

- `events/YYYY/MM/*.json` - source-of-truth event records. These are conflict-resistant because every entry gets its own file.
- `input-spool/YYYY-MM-DD.jsonl` - append-only fallback batches written only when `vaultwares-api` is unavailable.
- `CHANGES.md` - generated readable ledger for this repo.
- `CHANGES.html` - generated browser-ready ledger with expandable sections.
- `WORK_IMPACT.html` - generated work-impact dashboard. It combines ledger events, work-impact state, and `input-logs` when present.
- `..\CHANGES.md` - generated mirror at the parent workspace root for local agents.
- `..\CHANGES.html` - generated browser-ready mirror at the parent workspace root.
- `..\WORK_IMPACT.html` - generated browser-ready work-impact mirror at the parent workspace root.
- `site/` - React/Vite internal dashboard source for Work Impact, ledger, and `/input-tracker` views.
- `scripts/record-agent-change.ps1` - local intake command for agents and hooks.
- `scripts/render-agent-ledger.ps1` - rebuilds readable ledgers from event files.
- `scripts/render-work-impact.ps1` - rebuilds `WORK_IMPACT.html` from ledger state. Input tracker widgets now read normalized VaultWares API endpoints in the React site.
- `scripts/update-work-impact.ps1` / `scripts/update-work-impact-state.ps1` - rebuild the persisted aggregate state consumed by Work Impact.
- `scripts/track-input.py` - optional local input tracker for privacy-safe keystroke, pointer, focus, and command cadence metrics. It batches to `vaultwares-api`.
- `scripts/replay-input-spool.py` - replays append-only tracker spool files after API outages.
- `scripts/import-input-logs.py` - imports legacy `input-logs/YYYY-MM-DD.json` files into the API with stable idempotent batch/event ids.
- `scripts/import-agent-ledger-events.py` - backfills append-only ledger event files into the API/Postgres ledger tables.
- `scripts/setup-input-tracker.ps1` - installs tracker dependencies and registers the Windows input-tracker scheduled task.
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

The script deduplicates matching content, writes an event file, makes a best-effort POST to `POST /api/ledger/agent/events`, and regenerates both readable ledgers. Set `VW_AGENT_LEDGER_API_SYNC=0` for emergency local-only operation.

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

## Input tracker and dashboard widgets

The optional input tracker records local activity as privacy-safe minute rollups and posts batches to `vaultwares-api`:

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\setup-input-tracker.ps1" -StartNow
```

The tracker task is named `VaultWares-InputTracker`. It starts at logon and unlock, sends batches to `POST /api/telemetry/input/batches`, and records only aggregate metrics: WPM/CPM inputs, correction ratio, key latency buckets, click hotspots, scroll activity, focus category, context switches, micro-pauses, shortcuts, saves, and command cadence.

Set these environment variables for non-default deployments:

```powershell
$env:VW_API_URL = "http://127.0.0.1:9001"
$env:VW_TELEMETRY_API_KEY = "<local service key>"
```

Legacy hourly JSON can be imported through the API before restarting a stale tracker:

```powershell
python "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\import-input-logs.py" --since 2026-06-06 --dry-run
python "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\import-input-logs.py" --since 2026-06-06
```

If the API is unavailable, the tracker writes append-only JSONL batches under `input-spool/`. Replay them after the API recovers:

```powershell
python "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\replay-input-spool.py"
```

The React/Vite dashboard routes read API endpoints only:

- `/work-impact` -> `GET /monitor/work-impact`
- `/changes` -> `GET /monitor/changes`
- `/input-tracker` -> `GET /monitor/input-tracker`

The browser does not scan `events`, `input-logs`, open spool files, or connect to Postgres directly. Existing `input-logs/*.json` files are legacy import material; durable storage and rollups now belong behind `vaultwares-api`.

Backfill historical ledger events through the API:

```powershell
python "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\import-agent-ledger-events.py" --dry-run
python "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\import-agent-ledger-events.py"
```

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

This repo is deployed to `ledger.vaultwares.ca` and `stats.vaultwares.ca` for internal use only. The stats SPA serves work-impact, changes, and input-tracker pages on the tailnet; all live data comes through `vaultwares-api`.
**Read DEPLOY.md** to know more details.
