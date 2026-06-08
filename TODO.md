# agent-ledger TODO

## Completed (2026-05-31)

- [x] **VaultWares Daily Dashboard System Creation** — Implemented comprehensive activity tracking and analytics dashboard with `track-input.py` (silent background tracker using pynput), `setup-input-tracker.ps1` (dependency installation and Windows scheduled tasks), and `render-daily-dashboard.ps1` (HTML dashboard generator). Features: LED stat cards, hourly activity bar with range picker, activity heatmap, deep work score ring, focus blocks, daily trends, rhythm chart, AI model/kinds pie charts, project distribution, context-switch analysis.
- [x] **DAILY_DASHBOARD Theme Refinement** — Revised theme with muted accent colors, reduced LED dots (6px soft glow), removed glassmorphism/gradient backgrounds, removed scanline overlays, switched heatmap to violet color levels. Fixed scheduled task registration for `conhost.exe --headless`.
- [x] **Productivity System Sync** — Executed `/productivity:update` routine to scan 7 project TASKS.md files and last 20 ledger entries. Compiled active work summary across CodeQL enablement, Gemini smoke test, Dependabot webhooks, and tube-sites fixes.

## Completed (2026-06-02)

- [x] **Work Impact Page Fixes & Enhancements** — Fixed WorkImpactPage.tsx and update-work-impact-state.ps1. Resolved data loading on initial render; fixed work activity tooltip by decoding URI-encoded project names; reordered KPI row above focus blocks; added commit exclusion for outliers. Added missing modules: AI Model Usage, Tools Used, MCP Servers, Agent Activity by Day, Time-of-Day Rhythm. Verified activity-by-project accordions render correctly.

## Remaining

- [ ] Update `scripts/render-agent-ledger.ps1` to include archived entries from the `archive/` or `history/` directories in `CHANGES.html`.
- [ ] Update `scripts/render-work-impact.ps1` to support cross-referencing archived event files for historical trend visualization.
- [ ] Ensure `CHANGES.md` remains a "hot" view but provides links or instructions to view full archives.
