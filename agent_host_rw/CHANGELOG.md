# Changelog

## 0.4.0

- **New add-on: Agent Host (read-write)**, slug `agent_host_rw`. It replaces **Multica Daemon (read-write)** (`multica_rw`). Because the slug changed, this is a fresh install: re-enter options, sign in again, and uninstall the old add-on (see "Moving from Multica Daemon" in the docs). The version history below is from `multica_rw`
- Options are prefixed by the tool that uses them: `claude_*`, `cursor_*`, `multica_*`, `pi_*`. `auto_stop_minutes` is add-on-wide
- **Claude Code Remote Control**: new s6 service. This add-on appears at claude.ai/code as `HA Agent Host (RW)`, and sessions start in `/config` (read-write)
  - Uses its own HOME (`/data/remote-control`) and an env scrubbed of `CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY`, so the daemon's tokens never override the claude.ai login
  - Pre-seeds workspace trust and the "Enable Remote Control?" prompt, and writes a user `CLAUDE.md` describing the RW boundary
  - Status sensor `sensor.claude_remote_control_rw_status` (`waiting_for_login` → `ready` / `error` / `disabled`)
- **Agent Host RW sidebar panel**: ingress web terminal (ttyd 1.7.7 + tmux) behind Caddy 2.11.9, with a guided `claude-rc-login`. Caddy admits only the Supervisor ingress proxy
- **Cursor My Machines worker** (opt-in `cursor_worker`): registers `/config` and `/workspace/*` git checkouts and restarts when checkouts change. Runs with a scrubbed env that holds only the Cursor key. Sensor `sensor.cursor_worker_rw_status`
- Environment names always carry the mode: blank defaults are `HA Agent Host (RW)` / `ha-agent-host-rw`, and custom names get `(RW)`/`-rw` appended when missing
- `multica_token` is now optional. Without it the daemon stays parked and the other services keep running
- Fix: config/auth failures (exit 78) no longer restart-loop. The old finish script returned 1, which s6 treats as "restart". Services now mark themselves down with `s6-svc -O`
- Each service is a single `services.d/<name>/run` file with its restart policy written inline; there are no finish scripts, and Multica's `run.sh` now lives in `services.d/multica/run`
- Fix: `multica auth status` exits 0 when unauthenticated; its output is now checked, so a missing token no longer crash-loops the daemon
- Fix: `/workspace` is persisted in `/data/workspace`. The old image's `WORKDIR /workspace` baked a real directory into the image, so the symlink was never created and its contents were lost on every update
- The boot CLI update also runs when the daemon is parked, so Remote Control and the Cursor worker get current CLIs
- `auto_stop_minutes` now covers the whole add-on: it is armed even without a Multica token, and the stop also ends Remote Control and Cursor worker sessions
- Claude Code baseline 2.1.318 → 2.1.325

## 0.3.12

- On boot, try to update Multica, Claude, Cursor, and Pi before the daemon starts, and keep the copies on `/data`
- If the image binary is newer than the `/data` copy, use the image copy before the download
- Run that pass once per container start, after credentials succeed, and cap it at 25 minutes
- Drop the 6-hour background updater
- Image fallback is Multica 0.8.0 and Claude Code 2.1.318

## 0.3.11

- `auto_stop_minutes` defaults to 0, so the add-on stays on. Set it to 30 on the read-write add-on to turn that container off 30 minutes after start. The stop goes through the Supervisor API, and it stays off until you start it again
- A restarted service replaces any timer left from a crashed daemon. `stopped` is published only after Supervisor accepts the stop

## 0.3.10

- Publish lifecycle status to `sensor.multica_daemon_rw_status` (`starting` → `authenticated` → `ready` / `error`) via `ha-publish-status`

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
- Add writable `/workspace` for Multica agent workdirs
- Leave default `runtime_name` empty so all three tools register

## 0.2.1

- Require Multica token; stop s6 crash-loops on auth/config failure
- Pin Multica + Claude downloads with SHA256 verification
- Re-login when token option is set (token rotation)
- Remove unused log_level option

## 0.2.0

- Dedicated read-write Multica daemon container
- Overrideable `device_name` / `runtime_name`
- s6-overlay service supervision

## 0.1.0

- Initial combined add-on (superseded)
