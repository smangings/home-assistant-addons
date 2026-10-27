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
| `auto_stop_minutes` | turn off this many minutes after start (`0`, the default, leaves it running) |

Leave `runtime_name` blank so all three tools register as separate Multica runtimes.

With the default `0`, the add-on stays on. A positive value stops it through the Supervisor stop API when the window ends. Start it again for another window.
