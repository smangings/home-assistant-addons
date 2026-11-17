ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bookworm
FROM ${BUILD_FROM}

ARG BUILD_ARCH=amd64
ARG MULTICA_VERSION=0.8.0
ARG CLAUDE_VERSION=2.1.325
# Pinned SHA256 for Claude glibc binaries (Cursor Agent also requires glibc).
ARG CLAUDE_SHA256_X64=0dc4f4a9a165fc60746d7ae8489712e5fc352f1e7ad4eb22e7141bd0812eb0cf
ARG CLAUDE_SHA256_ARM64=7b6e484b1989a5a14a4b354709ccc8672518a3ec5b9ccd7981fc6254327fde67
# Official Node binary (bookworm apt is Node 18; Pi needs >=22.19 for /v regex).
ARG NODE_VERSION=22.23.0
ARG NODE_SHA256_X64=14d7de44f235534799f8b171a4050d9a6a4bc99c87e053a25d3d54afa580aa20
ARG NODE_SHA256_ARM64=4018815ac1bed4f18208901bbde524fee881253b591ee7bc952660e69bd057af
# ttyd (ingress web terminal) is not packaged for bookworm; use the pinned static release.
ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256_X64=8a217c968aba172e0dbf3f34447218dc015bc4d5e59bf51db2f2cd12b7be4f55
ARG TTYD_SHA256_ARM64=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165
# Caddy gates the ingress terminal (Debian ships 2.6.2; pin the upstream release).
# SHA-512 values are from the release's official checksums file.
ARG CADDY_VERSION=2.11.9
ARG CADDY_SHA512_X64=0e85544340290a16ce4bfb76fe7d65e9de1bf3a6e67f5ccfff30b30d27ea4c73e078077b7bf3e58ae60b6b12e44327705287059c775bca5782e8ee85ea7edd75
ARG CADDY_SHA512_ARM64=9e5e76d7888542924de2c25353ae87c5f77e2a22c5b1198633cae13688922282e05383d142599205c88d8d80eee5e967d291214d7abce4835329a191b20dd6e0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# IS_SANDBOX=1: Claude Code allows bypassPermissions as root inside containers.
ENV HOME=/root \
    DEBIAN_FRONTEND=noninteractive \
    IS_SANDBOX=1

# Seed Multica + Claude + Cursor + Pi. services.d/multica/run refreshes them onto /data once per container start.
# Debian/glibc base is required: Cursor Agent's bundled Node needs fcntl64 (fails on Alpine/musl).
RUN \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        less \
        openssh-client \
        procps \
        tar \
        tmux \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    \
    && case "${BUILD_ARCH}" in \
         amd64) \
           MULTICA_ARCH="amd64" \
           CLAUDE_PLATFORM="linux-x64" \
           CLAUDE_SHA256="${CLAUDE_SHA256_X64}" \
           NODE_ARCH="x64" \
           NODE_SHA256="${NODE_SHA256_X64}" \
           TTYD_ASSET="ttyd.x86_64" \
           TTYD_SHA256="${TTYD_SHA256_X64}" \
           CADDY_ARCH="amd64" \
           CADDY_SHA512="${CADDY_SHA512_X64}" \
           ;; \
         aarch64) \
           MULTICA_ARCH="arm64" \
           CLAUDE_PLATFORM="linux-arm64" \
           CLAUDE_SHA256="${CLAUDE_SHA256_ARM64}" \
           NODE_ARCH="arm64" \
           NODE_SHA256="${NODE_SHA256_ARM64}" \
           TTYD_ASSET="ttyd.aarch64" \
           TTYD_SHA256="${TTYD_SHA256_ARM64}" \
           CADDY_ARCH="arm64" \
           CADDY_SHA512="${CADDY_SHA512_ARM64}" \
           ;; \
         *) echo "Unsupported arch: ${BUILD_ARCH}" >&2; exit 1 ;; \
       esac \
    \
    && NODE_TGZ="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TGZ}" -o "/tmp/${NODE_TGZ}" \
    && echo "${NODE_SHA256}  /tmp/${NODE_TGZ}" | sha256sum -c - \
    && tar -xJf "/tmp/${NODE_TGZ}" -C /usr/local --strip-components=1 \
    && rm -f "/tmp/${NODE_TGZ}" \
    && node --version && npm --version \
    \
    && MULTICA_TGZ="multica-cli-${MULTICA_VERSION}-linux-${MULTICA_ARCH}.tar.gz" \
    && curl -fsSL \
         "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/checksums.txt" \
         -o /tmp/checksums.txt \
    && curl -fsSL \
         "https://github.com/multica-ai/multica/releases/download/v${MULTICA_VERSION}/${MULTICA_TGZ}" \
         -o "/tmp/${MULTICA_TGZ}" \
    && grep " ${MULTICA_TGZ}\$" /tmp/checksums.txt | (cd /tmp && sha256sum -c -) \
    && tar -xzf "/tmp/${MULTICA_TGZ}" -C /tmp \
    && install -m 0755 /tmp/multica /usr/local/bin/multica \
    && rm -rf /tmp/multica "/tmp/${MULTICA_TGZ}" /tmp/checksums.txt \
    \
    && curl -fsSL \
         "https://downloads.claude.ai/claude-code-releases/${CLAUDE_VERSION}/${CLAUDE_PLATFORM}/claude" \
         -o /tmp/claude \
    && echo "${CLAUDE_SHA256}  /tmp/claude" | sha256sum -c - \
    && install -m 0755 /tmp/claude /usr/local/bin/claude \
    && rm -f /tmp/claude \
    \
    && curl -fsS https://cursor.com/install | bash \
    && ln -sfn /root/.local/bin/cursor-agent /usr/local/bin/cursor-agent \
    && ln -sfn /root/.local/bin/agent /usr/local/bin/agent \
    \
    && curl -fsSL \
         "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/${TTYD_ASSET}" \
         -o /tmp/ttyd \
    && echo "${TTYD_SHA256}  /tmp/ttyd" | sha256sum -c - \
    && install -m 0755 /tmp/ttyd /usr/local/bin/ttyd \
    && rm -f /tmp/ttyd \
    \
    && CADDY_TGZ="caddy_${CADDY_VERSION}_linux_${CADDY_ARCH}.tar.gz" \
    && curl -fsSL \
         "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/${CADDY_TGZ}" \
         -o "/tmp/${CADDY_TGZ}" \
    && echo "${CADDY_SHA512}  /tmp/${CADDY_TGZ}" | sha512sum -c - \
    && tar -xzf "/tmp/${CADDY_TGZ}" -C /tmp caddy \
    && install -m 0755 /tmp/caddy /usr/local/bin/caddy \
    && rm -f /tmp/caddy "/tmp/${CADDY_TGZ}" \
    \
    && npm install -g --omit=dev @earendil-works/pi-coding-agent@latest \
    \
    && multica version \
    && claude --version \
    && cursor-agent --version \
    && pi --version \
    && ttyd --version \
    && caddy version

COPY rootfs /
# Globs (not a list) so new scripts can't be forgotten.
RUN chmod a+x \
      /usr/bin/ha-* /usr/bin/agent-host-* /usr/bin/claude-rc-* \
      /usr/bin/update-agent-tools \
      /etc/cont-init.d/* \
      /etc/services.d/*/run \
    && caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

# No `WORKDIR /workspace`: it bakes a real directory into the image and the
# persistent /workspace -> /data/workspace symlink (cont-init 50-workspace)
# could never be created.
WORKDIR /
# Entrypoint /init (from HA base) is PID 1. Longruns live in /etc/services.d.
# No CMD: s6 starts every service in /etc/services.d (multica, remote-control,
# cursor-worker, terminal, caddy).
