# Changelog

## 0.4.0

- **Options renamed by the tool that uses them**: `claude_*` (Claude Remote Control, `claude_api_key`), `multica_*` (`multica_server_url`, `multica_app_url`, `multica_workspace_id`, `multica_device_name`, `multica_runtime_name`, `multica_max_concurrent_tasks`) and `pi_*` (`pi_openrouter_api_key`, `pi_openrouter_model`). Your existing values are migrated on first start, and the add-on restarts once to apply them. `cursor_*`, `claude_code_oauth_token`, `multica_token` and `auto_stop_minutes` are unchanged
- Renamed to **Agent Host (read-only)**. The slug (`multica_ro`), options and `/data` are unchanged, so this installs as a normal update
- **Claude Code Remote Control**: new s6 service. This add-on appears at claude.ai/code as `HA Agent Host (RO)`, and sessions start in `/config` (read-only)
  - Uses its own HOME (`/data/remote-control`) and an env scrubbed of `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY`, so the daemon's tokens never override the claude.ai login
  - Pre-seeds workspace trust and the "Enable Remote Control?" prompt, and writes a user `CLAUDE.md` describing the RO boundary
  - Status sensor `sensor.claude_remote_control_ro_status` (`waiting_for_login` → `ready` / `error` / `disabled`)
- **Agent Host RO sidebar panel**: ingress web terminal (ttyd 1.7.7 + tmux) with a guided `claude-rc-login`. nginx admits only the Supervisor ingress proxy
- **Cursor My Machines worker** (opt-in `cursor_worker`): registers `/config` and `/workspace/*` git checkouts and restarts when checkouts change. Runs with a scrubbed env that holds only the Cursor key. Sensor `sensor.cursor_worker_ro_status`
- Environment names always carry the mode: blank defaults are `HA Agent Host (RO)` / `ha-agent-host-ro`, and custom names get `(RO)`/`-ro` appended when missing
  - **Multica:** if `multica_device_name` was blank, the computer is now named `HA Agent Host (RO)`. Delete the stale `HA Config (read-only)` entry in Multica
- `multica_token` is now optional. Without it the daemon stays parked and the other services keep running
- Fix: s6 finish scripts now use exit 125 for "do not restart". Exit 1 restarted the service, so config/auth failures (exit 78) looped
- Fix: `multica auth status` exits 0 when unauthenticated; its output is now checked, so a missing token no longer crash-loops the daemon
- Fix: `/workspace` is now really persisted in `/data/workspace`. `WORKDIR /workspace` had baked a real directory into the image, so the symlink was never created. Anything in `/workspace` on a 0.3.x container lived in the container layer
- The boot CLI update also runs when the daemon is parked, so Remote Control and the Cursor worker get current CLIs
- Claude Code baseline 2.1.318 → 2.1.325

## 0.3.12

- On boot, try to update Multica, Claude, Cursor, and Pi before the daemon starts, and keep the copies on `/data`
- If the image binary is newer than the `/data` copy, use the image copy before the download
- Run that pass once per container start, after credentials succeed, and cap it at 25 minutes
- Drop the 6-hour background updater
- Image fallback is Multica 0.8.0 and Claude Code 2.1.318

## 0.3.10

- Publish lifecycle status to `sensor.multica_daemon_ro_status` (`starting` → `authenticated` → `ready` / `error`) via `ha-publish-status` (works in RO; bypasses `ha-api` write block)

## 0.3.9

- Add `claude_code_oauth_token` for Claude Pro/Max subscription (via `claude setup-token`); clears API key env when set

## 0.3.8

- Set `IS_SANDBOX=1` so Claude Code can use bypassPermissions as root in the add-on container

## 0.3.7

- Verbose Pi updater diagnostics: exit reason (timeout vs kill), disk free, npm log tail

## 0.3.6

- Pi updater: skip npm install when already current; raise timeout to 15m (SIGTERM was our 3m cap)

## 0.3.5

- Version bump so Home Assistant Supervisor can offer/apply the 0.3.4 boot fix as a clean update

## 0.3.4

- Stop running Claude/Cursor/Pi updates in cont-init (Pi `npm install` hung and Supervisor restarted the add-on)
- Refresh tools in the background tool-updater service after boot, with per-step timeouts

## 0.3.3

- Set `init: false` so s6-overlay can be PID 1 (fixes `s6-overlay-suexec: fatal: can only run as pid 1`)

## 0.3.2

- Install Node.js 22 from official binaries (bookworm apt Node 18 cannot run Pi)
- Switch Pi package to `@earendil-works/pi-coding-agent`

## 0.3.1

- Switch to Debian bookworm base (glibc) so Cursor Agent's bundled Node works
- Use glibc Claude binaries to match the new base

## 0.3.0

- Install Claude Code, Cursor Agent, and Pi; keep them current via start + 6h update hooks
- Add `cursor_api_key`, `openrouter_api_key`, `openrouter_model` for plan/provider auth
- Add writable `/workspace` (even when `/config` is read-only) for Multica agent workdirs
- Leave default `runtime_name` empty so all three tools register

## 0.2.1

- Require Multica token; stop s6 crash-loops on auth/config failure
- Pin Multica + Claude downloads with SHA256 verification
- Re-login when token option is set (token rotation)
- Mount share/media read-only to match the RO threat model
- Remove unused log_level option

## 0.2.0

- Dedicated read-only Multica daemon container
- Overrideable `device_name` / `runtime_name`
- s6-overlay service supervision

## 0.1.0

- Initial combined add-on (superseded)
