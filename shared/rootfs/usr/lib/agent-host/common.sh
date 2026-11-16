# shellcheck shell=bash
# Shared helpers for Agent Host s6 services (remote-control, cursor-worker,
# terminal). Source it; it defines functions only and exports nothing on load.

AH_OPTIONS_FILE="${AH_OPTIONS_FILE:-/data/options.json}"
AH_RUN_DIR="${AH_RUN_DIR:-/run/agent-host}"
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

# --- s6 lifecycle markers -------------------------------------------------
# s6 finish scripts get ~5s before they are killed, so backoff sleeps happen
# at the top of the next run instead of in finish.

ah_mark() { mkdir -p "${AH_RUN_DIR}"; : >"${AH_RUN_DIR}/$1.$2"; }
ah_has_mark() { [[ -e "${AH_RUN_DIR}/$1.$2" ]]; }
ah_clear_marks() { rm -f "${AH_RUN_DIR}/$1".* 2>/dev/null || true; }

# ah_backoff SERVICE COMPONENT SECONDS: sleep if the previous run crashed.
ah_backoff() {
  local svc="$1" component="$2" secs="$3" code=""
  if ah_has_mark "${svc}" crashed; then
    code="$(cat "${AH_RUN_DIR}/${svc}.crashed" 2>/dev/null || true)"
    echo "[${svc}] previous run exited ${code:-abnormally}; restarting in ${secs}s"
    [[ -n "${component}" ]] && ah_publish "${component}" error "Exited ${code:-abnormally}; restarting in ${secs}s"
    sleep "${secs}"
  fi
  ah_clear_marks "${svc}"
}

# ah_finish SERVICE EXIT_CODE SIGNAL: shared finish policy.
#   disabled marker -> 125 (s6: permanent, do not restart)
#   reload marker   -> 0   (restart now)
#   anything else   -> record crash, 0 (restart; run applies the backoff)
ah_finish() {
  local svc="$1" code="${2:-0}" sig="${3:-0}"
  if [[ "${code}" -eq 256 ]]; then
    code=$((128 + sig))
  fi
  if ah_has_mark "${svc}" disabled; then
    exit 125
  fi
  if ah_has_mark "${svc}" reload; then
    rm -f "${AH_RUN_DIR}/${svc}.reload"
    exit 0
  fi
  mkdir -p "${AH_RUN_DIR}"
  printf '%s' "${code}" >"${AH_RUN_DIR}/${svc}.crashed"
  exit 0
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
