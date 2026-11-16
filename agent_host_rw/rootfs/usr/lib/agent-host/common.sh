# shellcheck shell=bash
# Shared helpers for the Agent Host s6 services (services.d/*/run) and the
# terminal scripts. Source it; it defines functions only and exports nothing
# on load.

AH_OPTIONS_FILE="${AH_OPTIONS_FILE:-/data/options.json}"
AH_RC_HOME="${AH_RC_HOME:-/data/remote-control}"

# ah_option KEY [DEFAULT]: string value from the add-on options file.
# Blank or null values return DEFAULT.
ah_option() {
  local key="$1" default="${2:-}" value=""
  if [[ -f "${AH_OPTIONS_FILE}" ]]; then
    value="$(jq -r --arg key "${key}" '.[$key] // empty | tostring' "${AH_OPTIONS_FILE}" 2>/dev/null || true)"
  fi
  if [[ -z "${value//[[:space:]]/}" ]]; then
    printf '%s' "${default}"
  else
    printf '%s' "${value}"
  fi
}

# ah_bool KEY DEFAULT(true|false): exit 0 when the option is true.
# Uses has() so an explicit false is not swallowed by jq's // operator.
ah_bool() {
  local key="$1" default="${2:-false}" value="${2:-false}"
  if [[ -f "${AH_OPTIONS_FILE}" ]]; then
    value="$(jq -r --arg key "${key}" --arg d "${default}" \
      'if has($key) and .[$key] != null then .[$key] | tostring else $d end' \
      "${AH_OPTIONS_FILE}" 2>/dev/null || printf '%s' "${default}")"
  fi
  [[ "${value}" == "true" ]]
}

# Env the status publisher (and ha-api in sessions) needs.
ah_ha_env() {
  export HA_URL="${HA_URL:-http://supervisor/core/api}"
  export HA_TOKEN="${HA_TOKEN:-${SUPERVISOR_TOKEN:-}}"
  export MULTICA_ACCESS_MODE="${MULTICA_ACCESS_MODE:-rw}"
  export MULTICA_HA_CONFIG=/config
  export MULTICA_WORKSPACE=/workspace
}

# ah_publish COMPONENT STATE [MESSAGE]: best effort, never fails the caller.
ah_publish() {
  local component="$1"; shift
  STATUS_COMPONENT="${component}" ha-publish-status "$@" || true
}

ah_mode_label() {
  if [[ -n "${AGENT_HOST_MODE_LABEL:-}" ]]; then
    printf '%s' "${AGENT_HOST_MODE_LABEL}"
  elif [[ "${MULTICA_ACCESS_MODE:-rw}" == "ro" ]]; then
    printf 'RO'
  else
    printf 'RW'
  fi
}

# --- Service lifecycle -----------------------------------------------------
# Each services.d/<name>/run states its own restart policy with these three
# helpers, so there are no finish scripts. s6 restarts a service whenever its
# run script exits, unless the script asked to stay down first.

# ah_stay_down SERVICE: when this run exits, s6 must not restart it
# (disabled, missing configuration). Same effect as a finish script
# returning 125.
ah_stay_down() {
  s6-svc -O "/run/service/$1" 2>/dev/null || true
}

# ah_run CMD...: run CMD as a child and return its exit code. SIGTERM/SIGINT
# (add-on stop) are passed on to CMD, then the script exits without any
# restart delay.
ah_run() {
  "$@" &
  AH_CHILD=$!
  trap 'kill -TERM "${AH_CHILD}" 2>/dev/null; wait "${AH_CHILD}"; exit 143' TERM INT
  wait "${AH_CHILD}"
  local rc=$?
  trap - TERM INT
  return "${rc}"
}

# ah_restart_after SERVICE COMPONENT SECONDS EXIT_CODE: log (and publish to
# the component's HA sensor, if any) that the service exited, wait, then exit
# so s6 restarts it. The wait keeps a crashing service from looping.
ah_restart_after() {
  local svc="$1" component="$2" secs="$3" rc="$4"
  echo "[${svc}] exited ${rc}; restarting in ${secs}s"
  [[ -n "${component}" ]] && ah_publish "${component}" error "Exited ${rc}; restarting in ${secs}s"
  sleep "${secs}"
  exit "${rc}"
}

# --- Claude Remote Control ------------------------------------------------

# Isolated env for Remote Control and the login terminal. A separate HOME
# keeps this refresh token away from the Multica daemon's Claude (two
# processes rotating one refresh token log each other out). Inference-only
# tokens are unset because they outrank a stored claude.ai login.
rc_env() {
  export HOME="${AH_RC_HOME}"
  export XDG_CONFIG_HOME="${HOME}/.config"
  export XDG_DATA_HOME="${HOME}/.local/share"
  export XDG_CACHE_HOME="${HOME}/.cache"
  export IS_SANDBOX=1
  export PATH="/data/bin:/data/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  unset CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CONFIG_DIR || true
  mkdir -p "${HOME}" && chmod 0700 "${HOME}"
  mkdir -p "${HOME}/.claude" "${XDG_CONFIG_HOME}" "${XDG_DATA_HOME}" "${XDG_CACHE_HOME}"
  ah_ha_env
}

rc_name() { agent-host-name display "$(ah_option claude_remote_control_name "")"; }

rc_directory() {
  local dir
  dir="$(ah_option claude_remote_control_directory /config)"
  if [[ ! -d "${dir}" ]]; then
    dir=/workspace
  fi
  printf '%s' "${dir}"
}

# True when this HOME holds a claude.ai subscription login Remote Control can
# use. Prefers the CLI's own view (stable contract); falls back to the
# credentials file if the installed CLI predates `auth status --json`.
rc_login_ready() {
  local status
  status="$(timeout 30 claude auth status --json 2>/dev/null || true)"
  if jq -e 'type == "object"' >/dev/null 2>&1 <<<"${status}"; then
    jq -e '.loggedIn == true
           and (.authMethod == "claude.ai" or .storedClaudeAiLogin == true)' \
      >/dev/null 2>&1 <<<"${status}"
    return
  fi
  # Fallback. A blanked file ("" values after refresh-token expiry) and an
  # expired refresh token both count as not ready.
  jq -e '.claudeAiOauth
    | (.refreshToken | type == "string" and length > 0)
      and ((.refreshTokenExpiresAt | type) != "number"
           or .refreshTokenExpiresAt > (now * 1000))' \
    "${HOME}/.claude/.credentials.json" >/dev/null 2>&1
}
