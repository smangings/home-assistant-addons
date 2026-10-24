# Multica Daemon (read-write)

Read-write HA `/config`, plus `/workspace` for agent scratch.

Ships **Claude Code**, **Cursor Agent**, and **Pi** (OpenRouter). CLIs refresh on start and every 6 hours.

| Option | Purpose |
|--------|---------|
| `multica_token` | required |
| `anthropic_api_key` | Claude plan/API |
| `cursor_api_key` | Cursor plan (headless) |
| `openrouter_api_key` | Pi → OpenRouter |
| `device_name` | default `HA Config (read-write)` |
| `auto_stop_minutes` | stop the add-on this many minutes after start (default `30`; `0` disables) |

Leave `runtime_name` blank so all three tools register as separate Multica runtimes.

The add-on stops itself when that window ends, via the Supervisor stop API. Start it again for another window.
