# Agent Host (read-write)

Claude Code **Remote Control**, an optional **Cursor My Machines** worker and the **Multica** daemon, all inside one Home Assistant add-on. `/config` is mounted read-write.

Every environment this add-on registers carries **RW** in its name, so you can tell it apart from the read-only add-on:

| Where | Default name |
|-------|--------------|
| claude.ai/code · Claude app (Remote Control) | `HA Agent Host (RW)` |
| Cursor → My Machines | `ha-agent-host-rw` |
| Multica → Runtimes | `HA Agent Host (RW)` |
| HA sidebar | `Agent Host RW` |

Custom names (`claude_remote_control_name`, `cursor_worker_name`, `multica_device_name`) get ` (RW)` / `-rw` appended unless they already say RW or read-write.

## Claude Code Remote Control

A **read-write editor**: Remote Control sessions change `/config` directly from your phone or browser. Keep `/config` in git if you want an easy undo.

**First-time sign-in** (needed once per add-on, and again when the login expires):

1. Start the add-on, then open **Agent Host RW** in the HA sidebar.
2. Answer **Y** to "Sign in Remote Control now?" (or run `claude-rc-login`).
3. Open the printed URL, approve, and paste the code back into the terminal.
4. Within about 15 seconds Remote Control starts. Pick **HA Agent Host (RW)** at [claude.ai/code](https://claude.ai/code) or in the Claude app.

Use a Claude Pro/Max/Team/Enterprise account. The `claude_code_oauth_token` option (`claude setup-token`) can't be used for Remote Control: it is inference-only. The add-on keeps it away from Remote Control by giving RC its own HOME (`/data/remote-control`). The terminal panel is admin-only, and Caddy admits only the Supervisor ingress proxy.

| Option | Default | Description |
|--------|---------|-------------|
| `claude_remote_control` | `true` | Run Remote Control |
| `claude_remote_control_name` | `HA Agent Host (RW)` | Name at claude.ai/code |
| `claude_remote_control_directory` | `/config` | Where sessions start (falls back to `/workspace` if missing) |
| `claude_remote_control_permission_mode` | `default` | `default` asks for approval in the app. Other values: `acceptEdits`, `plan`, `auto`, `bypassPermissions` |

Sessions get a user `CLAUDE.md` describing this add-on's RW boundary and the `ha-states` / `ha-history` / `ha-api` helpers.

## Cursor My Machines (optional)

Lets Cursor cloud agents run their shell and file tools on this add-on ([docs](https://cursor.com/docs/cloud-agent/self-hosted/my-machines)). The connection is outbound only; no port is opened.

1. Set `cursor_api_key` to a **personal user API key**. Admin and org keys can't start workers.
2. Set `cursor_worker: true` and restart.
3. Pick **ha-agent-host-rw** under My Machines at [cursor.com/agents](https://cursor.com/agents).

Cursor routes a repo request by git remote. By default the worker registers `/config` (if it's a git checkout with a remote) plus each `/workspace/*` checkout that has a remote. Override with `cursor_worker_dirs` (colon-separated). New clones are picked up within about a minute. The worker's environment holds only the Cursor key: no Multica, Claude or OpenRouter secrets, and no `SUPERVISOR_TOKEN`. It still runs as root with access to `/data` (including `options.json` and the Remote Control login) and the Supervisor token on disk, so **anyone who can drive your Cursor account can read this add-on's other secrets**. Only enable it for a Cursor account you trust.

| Option | Default | Description |
|--------|---------|-------------|
| `cursor_worker` | `false` | Run the My Machines worker |
| `cursor_worker_name` | `ha-agent-host-rw` | Machine name (`worker=<name>` triggers) |
| `cursor_worker_dirs` | *(auto)* | Colon-separated checkout roots |

## Multica daemon (optional)

| Option | Default when blank | Description |
|--------|--------------------|-------------|
| `multica_token` | — | Multica PAT (`mul_…`). Blank = daemon not started |
| `multica_server_url` / `multica_app_url` | Multica Cloud | Self-host override |
| `multica_device_name` | `HA Agent Host (RW)` | Computer name in Multica |
| `multica_runtime_name` | *(empty)* | Leave blank so Claude, Cursor, and Pi each register |
| `claude_api_key` | — | Claude Code **API/Console** key (API billing, not Pro usage) |
| `claude_code_oauth_token` | — | Claude Code **Pro/Max** OAuth token from `claude setup-token` (daemon only) |
| `cursor_api_key` | — | Cursor personal user API key (daemon + My Machines worker) |
| `pi_openrouter_api_key` | — | Pi → OpenRouter |
| `pi_openrouter_model` | `anthropic/claude-sonnet-4` | Default Pi model on OpenRouter |
| `multica_max_concurrent_tasks` | `2` | Concurrency |
| `auto_stop_minutes` | `0` | Turn the whole add-on off this many minutes after start. `0` leaves it running |


- **Claude Pro/Max:** leave `claude_api_key` empty and set `claude_code_oauth_token`. See [authentication](https://code.claude.com/docs/en/authentication).
- **Claude API billing:** set `claude_api_key` instead. The add-on prefers OAuth when both are filled.
- **Pi / OpenRouter:** set `pi_openrouter_api_key`. This writes `~/.pi/agent/auth.json` and the default provider settings.

## Auto-stop

`auto_stop_minutes` defaults to `0`, which leaves the add-on on. Set it to `30` to turn the add-on off 30 minutes after each start; any positive number uses that window instead. The window covers the **whole add-on** and runs as its own service, so it applies even when Multica isn't configured or fails to log in, and restarting a crashed service does not extend it. When it ends, the add-on asks Supervisor to stop it, which also ends Remote Control sessions and the Cursor worker. That is a requested stop, so the add-on stays off (even with Watchdog on) until you start it again, and starting it opens a new window.

## Moving from Multica Daemon (read-write)

This add-on replaces **Multica Daemon (read-write)** under a new slug (`agent_host_rw`, was `multica_rw`). Home Assistant treats it as a separate add-on, so nothing carries over automatically.

1. Copy anything you need out of the old add-on's `/workspace`.
2. Install **Agent Host (read-write)** and enter your options using the table below.
3. Start it and sign in to Remote Control from the **Agent Host RW** panel.
4. Uninstall **Multica Daemon (read-write)**.
5. In Multica, delete the old `HA Config (read-write)` computer; this add-on registers as `HA Agent Host (RW)`.

| Old option (`multica_rw`) | New option |
|---|---|
| `anthropic_api_key` | `claude_api_key` |
| `claude_code_oauth_token` | `claude_code_oauth_token` |
| `cursor_api_key` | `cursor_api_key` |
| `multica_token` | `multica_token` |
| `server_url` | `multica_server_url` |
| `app_url` | `multica_app_url` |
| `workspace_id` | `multica_workspace_id` |
| `device_name` | `multica_device_name` |
| `runtime_name` | `multica_runtime_name` |
| `max_concurrent_tasks` | `multica_max_concurrent_tasks` |
| `openrouter_api_key` | `pi_openrouter_api_key` |
| `openrouter_model` | `pi_openrouter_model` |
| `auto_stop_minutes` | `auto_stop_minutes` |

## Access boundary

| Path | Access |
|------|--------|
| `/config`, `/share`, `/media` | **read-write**: Remote Control sessions edit your live HA config |
| `/ssl` | read-only |
| `/workspace` → `/data/workspace` | read-write scratch |

## Status sensors

| Entity | States |
|--------|--------|
| `sensor.multica_daemon_rw_status` | `starting` → `authenticated` → `ready` / `error` / `disabled`, and `stopped` after auto-stop |
| `sensor.claude_remote_control_rw_status` | `waiting_for_login` → `ready` / `error` / `disabled` |
| `sensor.cursor_worker_rw_status` | `ready` / `error` / `disabled` |

A useful automation: notify when `sensor.claude_remote_control_rw_status` becomes `waiting_for_login`. That means the claude.ai login expired and needs the panel again.

A Home Assistant restart clears these sensors. The add-on keeps the last state and publishes it again within about 15 seconds. The add-on does not have to restart.

## Runtimes & updates

The image seeds Multica, Claude Code, Cursor Agent and Pi. Once per container start, the add-on tries to update them onto `/data`. If the image copy is newer it is kept, and a failed download falls back to what is already on disk. The update runs whether or not Multica is configured. Remote Control and the Cursor worker start in parallel, so on a first boot they may run the image's CLI version until the next restart.
