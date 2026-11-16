# Ben's Home Assistant Add-ons

Repository: https://github.com/smangings/home-assistant-addons

## Add-ons

Two **Agent Host** add-ons with real filesystem boundaries. Each one is a remote for **Claude Code Remote Control** (claude.ai/code and the Claude app). Each can optionally be a **Cursor My Machines** worker and run a **Multica** daemon. Both ship Claude Code, Cursor Agent and Pi (OpenRouter). The add-on tries to update them onto `/data` once per container start.

| Add-on | `/config` | Remote Control name | Cursor machine | Multica computer |
|--------|-----------|---------------------|----------------|------------------|
| **Agent Host (read-only)** | read-only | `HA Agent Host (RO)` | `ha-agent-host-ro` | `HA Agent Host (RO)` |
| **Agent Host (read-write)** | read-write | `HA Agent Host (RW)` | `ha-agent-host-rw` | `HA Agent Host (RW)` |

Every environment name carries RO/RW, and custom names get the suffix added if it's missing.

These replace the **Multica Daemon** add-ons (`multica_ro` / `multica_rw`). The slugs are now `agent_host_ro` / `agent_host_rw`, so they install as new add-ons: re-enter options, sign in, then uninstall the old ones. Each add-on's docs have an old-to-new option table.

`auto_stop_minutes` (RW only) defaults to `0`, always on. Set it to `30` to turn the read-write add-on off 30 minutes after each start; that also ends its Remote Control sessions.

### Install

1. HA → **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Add `https://github.com/smangings/home-assistant-addons`
3. Install the RO and/or RW add-on and start it
4. **Remote Control:** open the **Agent Host RO/RW** sidebar panel and sign in (`claude-rc-login`). Then pick the environment at [claude.ai/code](https://claude.ai/code)
5. **Cursor (optional):** set `cursor_api_key` (personal user key) and `cursor_worker: true`
6. **Multica (optional):** set `multica_token` and provider keys. Point Multica `local_directory` at `/workspace` (RO) or `/config` / `/workspace` (RW)

Status sensors: `sensor.claude_remote_control_{ro,rw}_status`, `sensor.cursor_worker_{ro,rw}_status`, `sensor.multica_daemon_{ro,rw}_status`.

## Development

`shared/` holds everything both add-ons have in common: the Dockerfile, `run.sh` and `rootfs/`. Per-variant files are `config.yaml`, `Dockerfile.overlay` (the mode ENV, including `AGENT_HOST_MODE_LABEL`), `DOCS.md`, `CHANGELOG.md` and `translations/`.

```bash
./sync-addons.sh   # copy shared/ into agent_host_ro/ and agent_host_rw/
```
