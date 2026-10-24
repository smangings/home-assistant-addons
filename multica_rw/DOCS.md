# Multica Daemon (read-write)

## Configuration

| Option | Default when blank | Description |
|--------|--------------------|-------------|
| `multica_token` | **required** | Multica PAT (`mul_…`) |
| `server_url` / `app_url` | Multica Cloud | Self-host override |
| `device_name` | `HA Config (read-write)` | Computer name in Multica |
| `runtime_name` | *(empty)* | Leave blank so Claude, Cursor, and Pi each register |
| `anthropic_api_key` | — | Claude Code **API/Console** key (API billing, not Pro usage) |
| `claude_code_oauth_token` | — | Claude Code **Pro/Max** OAuth token from `claude setup-token` |
| `cursor_api_key` | — | Cursor Agent API key (Cursor plan) |
| `openrouter_api_key` | — | Pi → OpenRouter |
| `openrouter_model` | `anthropic/claude-sonnet-4` | Default Pi model on OpenRouter |
| `max_concurrent_tasks` | `2` | Concurrency |
| `auto_stop_minutes` | `30` | Stop the add-on this many minutes after start. `0` leaves it running |

## Access boundary

`/config` is read-write. `/workspace` is also available as a writable agent scratch dir.

## Auto-stop

Each start of this add-on opens a write-access window of `auto_stop_minutes` (30 by default). When the window ends, the add-on asks Supervisor to stop it. That is a requested stop, so the add-on stays off — including when Watchdog is on — until you start it again. Starting it opens a new window. In-progress agent tasks are interrupted at stop.

The timer starts when the add-on starts, including after a Home Assistant restart if boot is set to auto. Set `auto_stop_minutes` to `0` to keep write access up. The read-only add-on is not on this timer.

## Status sensor

On boot the add-on posts lifecycle state to `sensor.multica_daemon_rw_status`:

| State | Meaning |
|-------|---------|
| `starting` | Setup began |
| `authenticated` | Multica login / stored credentials OK |
| `ready` | About to start the daemon (setup finished) |
| `error` | Permanent config/auth failure, or auto-stop could not reach Supervisor |
| `stopped` | Auto-stop fired and Supervisor was asked to stop the add-on |

Use this for dashboard colors (e.g. yellow while `starting`/`authenticated`, green on `ready`).

## Runtimes & updates

Image seeds Claude Code, Cursor Agent (`cursor-agent`), and Pi. On every start (and every 6h) `update-agent-tools` refreshes them to the latest verified releases.

## Plan / provider login

- **Claude Pro/Max (subscription usage):** leave `anthropic_api_key` empty; set `claude_code_oauth_token` from `claude setup-token` on a machine with a browser (see [authentication](https://code.claude.com/docs/en/authentication)).
- **Claude API billing:** set `anthropic_api_key` instead (the add-on prefers OAuth when the token option is filled).
- **Claude interactive:** leave both blank and login once under `/data/.claude` from a shell.
- **Cursor:** set `cursor_api_key` from Cursor dashboard.
- **Pi / OpenRouter:** set `openrouter_api_key`.
