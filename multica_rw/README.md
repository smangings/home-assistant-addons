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
| `auto_stop_minutes` | turn off this many minutes after start (default `30`; `0` leaves it running) |

Leave `runtime_name` blank so all three tools register as separate Multica runtimes.

The default `30` stops the add-on through the Supervisor stop API 30 minutes after start. Set `0` to leave it running. Start it again for another window.
