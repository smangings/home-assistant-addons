#!/usr/bin/env bash
# Copy shared/ into each add-on folder. Supervisor builds every add-on from
# its own folder only, so the shared Dockerfile, build.yaml and rootfs/ must
# be copied in. Each add-on's Dockerfile.overlay (its RO/RW ENV) is appended.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

make_scripts_executable() {
  find "$1/rootfs/usr/bin" "$1/rootfs/etc/services.d" "$1/rootfs/etc/cont-init.d" \
    -type f -exec chmod a+x {} +
}

sync_addon() {
  local dest="$1"
  cp "${ROOT}/shared/Dockerfile" "${ROOT}/shared/build.yaml" "${dest}/"
  rsync -a --delete --exclude '.DS_Store' "${ROOT}/shared/rootfs/" "${dest}/rootfs/"
  cat "${dest}/Dockerfile.overlay" >> "${dest}/Dockerfile"
  make_scripts_executable "${dest}"
  echo "synced ${dest}"
}

make_scripts_executable "${ROOT}/shared"
sync_addon "${ROOT}/agent_host_ro"
sync_addon "${ROOT}/agent_host_rw"
