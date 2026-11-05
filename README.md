# Ben's Home Assistant Add-ons

Repository: https://github.com/smangings/home-assistant-addons

## Add-ons

Two Multica daemon containers with real filesystem boundaries. Each ships **Claude Code**, **Cursor Agent**, and **Pi** (OpenRouter). On container start, before the daemon launches, the add-on tries to update Multica and those CLIs onto `/data`.

| Add-on | Config / share / media | Agent workspace | Default device name |
|--------|------------------------|-----------------|---------------------|
| **Multica Daemon (read-only)** | read-only | `/workspace` (RW) | `HA Config (read-only)` |
| **Multica Daemon (read-write)** | RW (ssl RO) | `/workspace` (RW) | `HA Config (read-write)` |

`auto_stop_minutes` defaults to `0` (always on). Set it to `30` on the read-write add-on so that container turns off 30 minutes after each start. The read-only add-on stays up.

Leave `runtime_name` blank so Multica registers Claude, Cursor, and Pi as separate runtimes.

### Auth options

- `anthropic_api_key` — Claude Code / plan-linked API key
- `cursor_api_key` — Cursor Agent headless plan key
- `openrouter_api_key` + `openrouter_model` — Pi via OpenRouter

### Install

1. HA → **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Add: `https://github.com/smangings/home-assistant-addons`
3. Install RO and/or RW add-ons, set `multica_token` + provider keys, start
4. Point Multica `local_directory` at `/workspace` on the RO daemon (and `/config` or `/workspace` on RW)

## Development

```bash
./sync-addons.sh
```
