# Multica Daemon (read-only)

Read-only HA `/config` (and share/media), plus a **writable** `/workspace` for Multica agent workdirs.

Ships **Claude Code**, **Cursor Agent**, and **Pi** (OpenRouter). On container start, the add-on tries to update Multica and those CLIs onto `/data` before the daemon launches.

| Option | Purpose |
|--------|---------|
| `multica_token` | required |
| `anthropic_api_key` | Claude plan/API |
| `cursor_api_key` | Cursor plan (headless) |
| `openrouter_api_key` | Pi → OpenRouter |
| `device_name` | default `HA Config (read-only)` |

Point Multica `local_directory` at `/workspace` on this daemon.
