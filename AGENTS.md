# Agent Ledger — Protocol & Header Template

> For company-wide rules, read `vaultwares-docs/AGENTS.md` first.

This repo is the Tier 2 Source of Truth for agent activity recording. All AI
Assistants working in VaultWares projects must record completed work here.

## When to Record

Record the ledger **after all work is done, as the last step before replying**.
The ledger is a record of completed work, not intent.

## Recording Command

```powershell
& "C:\Users\Administrator\Desktop\Github Repos\agent-ledger\scripts\record-agent-change.ps1" `
  -Project "<repo name or General Tasks>" `
  -Kind "<plan|commands|code-change|verification|handoff|general>" `
  -Summary "<1024-token max summary of work done>" `
  -Commands @("<important command 1>", "<important command 2>") `
  -Files @("<important file 1>", "<important file 2>")
```

## Rules

- Keep summaries under 1024 tokens.
- Do not log secrets, tokens, private keys, credentials, or sensitive data.
- Do not duplicate an existing event — the script deduplicates.
- If the ledger cannot be accessed, include a compact ledger entry in your reply.
- Consult `CHANGES.md` and the active project's roadmap/todo files for continuity.
- **Deep Search Protocol**: When analyzing work impact, changed files, or historical context, you **MUST** look in the `archive/` or `history/` directories if the information is not present in the 2-week active ledger window.

## Cloud / Restricted Environments

If you cannot run the PowerShell script but can write to `p-potvin/agent-ledger`:
create a JSON event file under `events/YYYY/MM/` using the existing schema.

If you cannot write the ledger at all, include a compact "Ledger entry" block
in your final reply for later capture.

## Agent Header Template

Include the agent header in the ledger entry (not in user-facing replies).
Write `unknown` for any field that is not knowable. Never include secrets.

```text
Agent: <your display name> (role: <main|subagent:<agent_type>>)
Model: <model id or 'unknown'>
Thinking: <low|medium|high|xhigh or 'unknown'>
Mode: <Default|Plan|other>
Permissions: <sandbox_mode> (network: <enabled|disabled>)
CWD: <path>  Branch: <branch or 'n/a'>
Tools used (this reply): <comma-separated tool names or 'none'>
MCP servers accessed (this reply): <comma-separated MCP namespaces or 'none'>
Time: <local date/time> (TZ: <timezone>)
```

- Include only tools and MCP servers used since the user's most recent message.
- Preserve first-seen order. Deduplicate before writing.
- If sub-agents are used, each should include its own header. The lead mentions
  which sub-agents were used in the final summary.

### Model name

**You know your own model name.** Do not write `unknown` for the `Model` field
unless you genuinely cannot determine it. Examples:

| AI Assistant | Model field example |
|---|---|
| Claude Sonnet 4.5 | `claude-sonnet-4.5` |
| Claude Opus 4 | `claude-opus-4` |
| GPT-4.1 | `gpt-4.1` |
| GPT-4o | `gpt-4o` |
| Gemini 2.5 Pro | `gemini-2.5-pro` |
| Codex (o3/o4) | `codex-o3` / `codex-o4-mini` |
| GitHub Copilot | `github-copilot` |

Use the model id that matches the version you are running. The model id is part
of your identity — always log it explicitly.

### Tools, MCP servers, and skills

List **every tool or MCP server you invoked** in the `Tools used` and
`MCP servers accessed` fields. Standard format:

```
Tools used (this reply): bash, view, edit, grep, glob, report_progress
MCP servers accessed (this reply): github-mcp-server, playwright-mcp
```

**Skills** (named capability packs) should be logged as `skill:<name>`, e.g.
`skill:customize-cloud-agent`. If you used no tools, write `none`.

This data is parsed by `update-work-impact-state.ps1` to populate the
Work Impact dashboard. Sparse or missing data will leave agent statistics
empty on that page.

## Project Aliases

`project-aliases.json` at the repo root is the single source of truth for renames. Every time a project is renamed (folder, remote, or manifest identity), append a new entry there **before** the rename. The intake, the work-impact aggregator, and the ledger renderer all normalize project names through this map so historical events keep bucketing under the canonical name. After editing the map, run `update-work-impact.ps1 -FullRebuild` once.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/record-agent-change.ps1` | Create an append-only event |
| `scripts/render-agent-ledger.ps1` | Regenerate CHANGES.md and CHANGES.html |
| `scripts/update-work-impact.ps1` | Refresh work impact report |
| `scripts/resolve-project-alias.ps1` | Helper module — normalizes a project name via `project-aliases.json` |
