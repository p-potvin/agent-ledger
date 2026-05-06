# Workspace Agent Instructions (Canonical)

This workspace uses a shared AI-agent ledger and a common ledger-only agent runtime header.

Important precedence note:
- Multiple `AGENTS.md` files may exist. The one deeper in the directory tree overrides higher-level ones.
- In this workspace, `C:\Users\Administrator\Desktop\Github Repos\AGENTS.md` and `C:\Users\Administrator\Desktop\Github Repos\agent-ledger\AGENTS.md` are intentionally kept identical. If you edit one, edit the other.

## Agent Header (Ledger-Only Mandatory)

Do not print the Agent Header in user-facing replies. Instead, include the Agent Header in the ledger entry for the work you just performed.

If a field is not knowable, write `unknown` (do not guess).
Never include secrets (tokens, passwords, API keys, private URLs with embedded creds).

Template (required in the ledger entry):
```text
Agent: <your display name> (role: <main|subagent:<agent_type>>)
Model: <model id or 'unknown'>
Thinking: <low|medium|high|xhigh or 'unknown'>  # reasoning_effort / complexity
Mode: <Default|Plan|other>
Permissions: <sandbox_mode> (network: <enabled|disabled>)
CWD: <path>  Branch: <branch or 'n/a'>
Tools used (this reply): <comma-separated tool call names or 'none'>
MCP servers accessed (this reply): <comma-separated MCP namespaces/servers or 'none'>
Time: <local date/time> (TZ: <timezone>)
```

Tools and MCP logging rule:
- Include only tools and MCP servers used since the user's most recent message.
- Preserve first-seen order.
- Deduplicate repeated tool names and MCP server names before writing the ledger entry.

If sub-agents are used:
- Each sub-agent should include its own header in its own ledger/reporting surface when available.
- The lead agent should mention which sub-agents were used in the final summary.

Optional (recommended when relevant, but not required every time):
- Repo(s) touched:
- Web browsing used (yes/no):
- Artifacts generated:
- External services accessed (GitHub/Vercel/etc):

Note: I am slightly uncertain whether you want these optional fields always-on because it can get verbose. I included them as optional and recommend enabling them when relevant.

## Shared Agent Ledger (Mandatory)

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
- If the ledger script or `CHANGES.md` cannot be accessed, say so in your reply.
- When starting a task, consult `CHANGES.md`, `agent-ledger\CHANGES.md`, and the active project's roadmap/todo files to stay on course.

Cloud / restricted environments:
- If you cannot run the local PowerShell script but you can write to the `p-potvin/agent-ledger` repo, create a unique JSON event file under `events/YYYY/MM/` using the existing event schema.
- If you cannot write the ledger at all, include a compact "Ledger entry" in your final reply for later capture.

## Repo Note: agent-ledger

The `agent-ledger` repo is the shared source of truth for agent activity.

When local PowerShell is available:
- Run `agent-ledger/scripts/record-agent-change.ps1` to create the append-only event.
- Regenerate readable summaries by running `agent-ledger/scripts/render-agent-ledger.ps1` (required when you wrote new event files locally).
- Optionally refresh the work impact report by running `agent-ledger/scripts/update-work-impact.ps1` when relevant.

Note: I am slightly uncertain whether you want regeneration required on every single change vs only "when relevant". I set it to "required when you wrote new event files locally".
