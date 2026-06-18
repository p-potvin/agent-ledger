# VaultWares Daily Recaps

## 2026-05-30 Daily Recap

### General Tasks
- **Security tooling rollout (09:32):** Analyzed GitHub CodeQL/GHAS pricing vs Copilot Pro, inventoried repo visibility (p-potvin public vs Prom-King private), and mapped Jira automation to existing vw-jira-sync webhook architecture. Identified next steps and approval gates for batch GitHub API enablement.
- **CodeQL enablement (10:16):** Enabled GitHub CodeQL default setup (Code Scanning) on 8 public repos: vault-explorer, vaultwares-docs, vaultwares-pipelines, vault-central, vault-guardian, vaultwares-themes, vaultwares-realtime. Skipped private repos (vaultwares-adk, vaultwares-toolkit). Added `dependabot_alert` → Jira support in vw-jira-sync and opened PR p-potvin/vw-jira-sync#3. Key files: `vw-jira-sync/scripts/deploy_webhooks.py`, `live_sync.py`.
- **Gemini Code Assist investigation (10:49):** Confirmed Dependabot alerts available on all GitHub plans. Validated custom GitHub App 'gemini-code-assist-for-vaultwares' — webhook_url is null, so proper setup requires Google Cloud/Developer Connect, not manual app creation.

### vw-jira-sync
- **Webhook update (10:48):** Updated all 41 GitHub repo webhooks to subscribe to `dependabot_alert` events using `deploy_webhooks.py` in `--events-only` mode. Added `--events-only` flag and delay control to the script. Pushed to branch `vw-codex-dependabot-alerts`.

### vault-explorer
- **Smoke-test PR (11:24):** Created draft PR #34 to smoke-test Gemini Code Assist for GitHub. Posted `/gemini review` comment. CodeQL check was in-progress at time of logging; no Gemini bot response observed yet. Branch: `vw-codex-gemini-test`.

### tube-sites
- **Plugin/theme fixes (15:47) — Actor: Claude (claude-opus-4-6, thinking: medium):** Fixed duplicate header/footer via `fxv_plugin_template` flag in `template_loader.php`. Added unified `fxv_render_footer()` helper in `helpers.php`, wired into all 5 FXV templates. Fixed search form SVG icon as proper `button[type=submit]` tap target, updated `base.css`. Removed stale `template_redirect 2257` hook from theme `functions.php`. All 10 PHP files pass `php -l`.

---

## 2026-05-31 Daily Recap

### agent-ledger
- **VaultWares Daily Dashboard system creation (00:56):** Created comprehensive activity tracking and analytics dashboard. Implemented: (1) `track-input.py` — silent Python background tracker using pynput to monitor keystrokes, mouse distance, Ctrl+S/C/V events, chars typed/pasted; writes hourly JSON to input-logs/YYYY-MM-DD.json. (2) `setup-input-tracker.ps1` — installs dependencies and registers two Windows scheduled tasks for tracking. (3) `render-daily-dashboard.ps1` — reads input-logs and ledger, generates interactive DAILY_DASHBOARD.html. Dashboard features: LED stat cards, hourly activity bar with range picker, activity heatmap, deep work score ring, focus blocks, daily trends, rhythm chart, AI model/kinds pie charts, project distribution bar, context-switch analysis, and fun facts. Styled in full VaultWares console theme.
- **DAILY_DASHBOARD theme refinement (02:35):** Revised theme per user feedback. Removed all cyan accents; muted accent colors (gold #b8882e, violet #8a62c0, green #4e9954, amber #c49840, orange #a86840, red #a84e5a). Reduced LED dots to 6px with single soft glow and slower fade-only animation; removed glassmorphism/gradient backgrounds from all cards (solid surface2 only); removed scanline overlays; switched heatmap to violet color levels. Fixed `setup-input-tracker.ps1` scheduled task registration to use `conhost.exe --headless` as executable per spec. Updated files: `render-daily-dashboard.ps1`, `setup-input-tracker.ps1`, `DAILY_DASHBOARD.html`.

### General Tasks
- **Productivity system sync (00:42):** Executed `/productivity:update` routine to scan 7 project TASKS.md files and last 20 ledger entries. Compiled active work summary across: CodeQL enablement on 8 repos, Gemini smoke test (vault-explorer PR#34), vw-jira-sync Dependabot webhooks (41 repos), tube-sites punch-list tasks (duplicate footer fixes, unified nav, search button accessibility).

---

**[PROCESSED: 2026-06-02 — Midnight sync completed]**
- Updated `vault-explorer/TASKS.md` — added Gemini Code Assist smoke-test note to section 3
- Updated `agent-ledger/TODO.md` — marked 3 dashboard/sync tasks as completed (2026-05-31)
- All project task files verified current with ledger entries
- Files synchronized: vw-jira-sync/TASKS.md ✓, vault-explorer/TASKS.md ✓, vault-explorer/ROADMAP.md ✓, vault-explorer/TODO.md ✓, tube-sites/TASKS.md ✓, agent-ledger/TODO.md ✓

## 2026-06-02 Daily Recap

### vaultwares-docs
- **Tailnet DNS resolver configuration (17:51):** Configured greencloud-vps as exact-host tailnet DNS resolver using dnsmasq. Set up host-record answers for docs.vaultwares.ca, api.vaultwares.ca, hooks.vaultwares.ca, secrets.vaultwares.ca, and warden.vaultwares.ca to 100.73.93.84. Enabled DNS on tailscale0 via UFW. Updated docs-content/operations/tailscale.mdx with Restricted/Split DNS documentation and compliance warnings.
- **Tailnet access verification (09:14):** Verified client-side tailnet override for vaultwares docs and secrets. Confirmed docs returns 200 with valid TLS and HTML content; secrets redirects to warden (200); warden returns 200 with valid TLS and VaultWarden JSON payload. Disabled unnecessary dnsmasq configuration on vaultwares-1 and cleaned up UFW rules.

### python-scripts
- **Telegram scraper pipeline cleanup & refactor (08:02–17:29):** Organized telegram/ directory structure: removed ~15 deprecated/intermediate scripts, migrated all test scripts to telegram/tests/, all documentation to telegram/docs/, created comprehensive README.md. Refactored telethon_link_resolver.py to: (1) create .env and requirements.txt with environment-based configuration via dotenv; (2) extract all rentry link types and save to all_extracted_links.txt; (3) process unrestriction through Real-Debrid browser extension via Persistent Context instead of RealDebrid API; (4) removed Playwright security restrictions (--disable-extensions, --enable-automation, --no-sandbox) to allow Real-Debrid extension to load.

### agent-ledger
- **Work impact page fixes & enhancements (07:01):** Fixed WorkImpactPage.tsx and update-work-impact-state.ps1. Resolved data loading on initial render; fixed work activity tooltip by decoding URI-encoded project names; reordered KPI row above focus blocks; added commit exclusion for outliers. Added missing modules: AI Model Usage, Tools Used, MCP Servers, Agent Activity by Day, Time-of-Day Rhythm. Verified activity-by-project accordions render correctly.

---

**[PROCESSED: 2026-06-03 — Midnight sync completed]**
- Updated `agent-ledger/TODO.md` — added Work Impact Page Fixes (2026-06-02) to Completed section
- Created `vaultwares-docs/TASKS.md` — logged Tailnet DNS configuration and verification work
- Created `python-scripts/TASKS.md` — logged Telegram scraper pipeline cleanup and refactor
- All project task files synced with ledger entries
- Files synchronized: agent-ledger/TODO.md ✓, vaultwares-docs/TASKS.md ✓, python-scripts/TASKS.md ✓

---

**[PROCESSED: 2026-06-04 — Midnight sync completed]**
- No new Daily Recap entries since 2026-06-03 sync
- All project task files remain current with prior sync
- No changes required

---

**[PROCESSED: 2026-06-05 — Midnight sync completed]**
- Verified 2026-06-02 Daily Recap entries against project task files
- All 3 projects have current TASKS.md files:
  - `vaultwares-docs/TASKS.md` — Tailnet DNS resolver configuration and verification tasks marked complete ✓
  - `python-scripts/TASKS.md` — Telegram scraper pipeline cleanup and refactor marked complete ✓
  - `agent-ledger/TODO.md` — Work Impact Page fixes marked complete ✓
- No discrepancies between recap and project files
- Sync complete — all projects current

---

**[PROCESSED: 2026-06-09 � Midnight sync completed]**
- No new Daily Recap entries since 2026-06-05 sync
- All project task files remain current
- No changes required


---

**[PROCESSED: 2026-06-10 — Midnight sync completed]**
- Processed 2026-06-09 Daily Recap entries
- Projects updated:
  - `vaultwares-studio/TODO.md` — Marked M0 Remote Execution Foundation as complete (Live verification & Docker Hub push tasks) ✓
  - `health-ledger/TASKS.md` — Created new task file, logged PostgreSQL Health Check work as complete ✓
- Note: Prom-King project not found in Github Repos directory (not included in sync)
- All accessible projects current with ledger entries
- Sync complete

---

**[PROCESSED: 2026-06-11 — Midnight sync completed]**
- Processed 2026-06-11 Daily Ledger entries (no Daily Recap section; entries pulled from ledger_get_recent)
- Projects updated:
  - `vaultwares-studio/TODO.md` — Added M2 viewport features (Blender-style axis gizmo, SuperSplat infinite zoom, embedded-viewport fix, camera authoring), M3 slice 1 shipped (robot_lab), COLMAP mapper non-determinism fix ✓
  - `vaultwares-api/TASKS.md` — Replaced generic template with actual work: PostgreSQL migration to OVH, API cutover to OVH with telemetry ✓
  - `vaultwares-mcp/TASKS.md` — Created new task file, logged MCP installation and deployment on OVH ✓
  - `health-ledger/TASKS.md` — Added pg-watchdog recovery entries from 2026-06-11 ✓
- All accessible projects current with ledger entries
- Sync complete
## 2026-06-11 Daily Recap

### vaultwares-studio
- M2 camera staging workflow: Renamed usd_cameras ? camera_staging with NEEDS_USER_INPUT flow, backwards-compatible job manifest migration, guided-mode pause logic for zero captured cameras, fixed handler metadata race condition, and validated all 4 existing job manifests load without manual edit (71/71 tests pass).
- Viewer.js navigation fixes: Added pointer-leave synthetic pointerup to fix OrbitControls hang on cursor exit from QtWebEngine, implemented real WASD fly (forward/back along look vector, strafe via right, E/Q for vertical with Shift speed multiplier, camera+pivot move together), status text updated.
- Camera behavior post-alignment: Fixed gimbal pole crossing by clamping minPolarAngle/maxPolarAngle to [0.05, p-0.05], added camera rewriting in gravity_align to rotate captured poses to aligned frame, retroactively rotated 7 Spiral captures from local-run-20260610-165858 (backed up pre-alignment).
- Gravity alignment implementation: New gravity_align.py with PCA scene-up detection, Rodrigues rotation, idempotent application to cloud.ply + quaternions + summary.json, fixed Windows mmap lock in plyfile via detach+gc, 27/27 focused tests pass, verified on local-run-20260610-165858.
- Walk patterns library: Added parametric paths (orbit, dolly_in/out, crane_up, figure_8, doorway_reveal, retrace_steps) + SceneBounds + registry, diagnosed Y-axis camera bug (scene up = 87.5� off +Y), 13/13 walk pattern tests + 20/20 camera path tests pass.
- Dashboard-viewport sync regression fix: _load_existing_job was not emitting manifest_changed signal, breaking viewport set_job path for "Open Job Manifest" button (worked only from job-runner path). Two-line fix + emit signal. 67/67 full tests pass.
- Black-screen viewer diagnosis: PLY integrity confirmed (477731 splats, 112.7 MB, no NaN/inf, geometry-only changes post-alignment), URL framing validated, narrowed hypotheses to HTTP disk cache vs. quaternion order convention.

### vps-ovhcloud media stack
- Docker Compose v2 deployment: Installed on OVH, deployed pyload-ng + hotio qBittorrent/Sonarr/Radarr/Lidarr/Prowlarr/Whisparr under /opt/vw-media-stack with persistent data in /srv/vw-media, preserved native Jackett, added nginx tailnet listeners for hotio UIs, documented services. Host-side response checks: qBittorrent 401, arr apps 200, pyLoad 200, Jackett 400 (setup response).
- Network reachability repairs: Added dnsmasq host-records for media hostnames (pyload, jackett, qbittorrent, sonarr, radarr, lidarr, prowlarr, whisparr) pointing to Greencloud 100.73.93.84, added nginx tailnet-only HTTP proxy vhosts, fixed dnsmasq backup parse failure after restart, verified direct DNS and forced tailnet proxy status codes. Local Windows DNS still needs NRPT entries or Tailscale suffix route for new media names.

### vaultwares-api
- PostgreSQL 18?16 migration to OVH: Dumped local Clopeux-Desktop vaultwares/promking DBs, migrated to remote apidb PG16 cluster on 100.67.25.118:5433, restored PG16-compatible SQL snapshots, verified /healthz db=up, row counts matched (vaultwares live telemetry had +1 row due to writes during migration).
- API cutover to OVH: Updated OVH API env to include telemetry key and bind 0.0.0.0:9001, restricted direct 9001 UFW ingress to this workstation over tailscale0, restarted vaultwares-api.service, verified /healthz and https://api.vaultwares.ca, paused InputTracker during migration, updated User VW_API_URL env var to http://100.67.25.118:9001, restarted tracker, verified post-restart telemetry batches reached OVH Postgres.

### vaultwares-mcp
- FastMCP deployment on OVH: Installed vaultwares-mcp at /opt/vaultwares-mcp with isolated Python venv, systemd service bound to 127.0.0.1:9020, streamable HTTP at /mcp. Added OVH nginx vhost for local MCP service, Greencloud as TLS edge with Let's Encrypt cert, dnsmasq routing via Greencloud tailnet IP 100.73.93.84. Verified 23 tools via https://mcp.vaultwares.ca/mcp, updated vaultwares-docs service inventory + tailscale hostname list + network map.

### health-ledger
- pg-watchdog recovery: PostgreSQL 18 on Clopeux-Desktop recovered after 2 consecutive probe failures; pg_isready now accepting connections on 127.0.0.1:5432. One restart attempt failed but subsequent probe succeeded.

---

**[PROCESSED: 2026-06-12 — Midnight sync completed]**
- Processed 2026-06-09 and 2026-06-10 Daily Recap entries
- Projects updated:
  - `vaultwares-studio/TODO.md` — Added Quality Gating on Input policy note (2026-06-10, frame selection, capture guidelines) ✓
  - `health-ledger/TASKS.md` — Added PostgreSQL Monitoring entry (2026-06-10, pg-watchdog recovery at 03:43–03:44) ✓
- Note: Prom-King project not found in Github Repos; sync focused on accessible projects
- All accessible projects verified current with ledger entries
- Sync complete
