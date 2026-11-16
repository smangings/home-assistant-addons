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

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# IS_SANDBOX=1: Claude Code allows bypassPermissions as root inside containers.
ENV HOME=/root \
    DEBIAN_FRONTEND=noninteractive \
    IS_SANDBOX=1

# Seed Multica + Claude + Cursor + Pi. /run.sh tries to refresh them onto /data before the daemon starts.
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
        nginx \
        openssh-client \
        procps \
        tar \
        tmux \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default \
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
           ;; \
         aarch64) \
           MULTICA_ARCH="arm64" \
           CLAUDE_PLATFORM="linux-arm64" \
           CLAUDE_SHA256="${CLAUDE_SHA256_ARM64}" \
           NODE_ARCH="arm64" \
           NODE_SHA256="${NODE_SHA256_ARM64}" \
           TTYD_ASSET="ttyd.aarch64" \
           TTYD_SHA256="${TTYD_SHA256_ARM64}" \
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
    && npm install -g --omit=dev @earendil-works/pi-coding-agent@latest \
    \
    && multica version \
    && claude --version \
    && cursor-agent --version \
    && pi --version \
    && ttyd --version \
    && nginx -v

COPY rootfs /
COPY run.sh /run.sh
# Globs (not a list) so new scripts can't be forgotten.
RUN chmod a+x /run.sh \
      /usr/bin/ha-* /usr/bin/agent-host-* /usr/bin/claude-rc-* \
      /usr/bin/update-agent-tools \
      /etc/cont-init.d/* \
      /etc/services.d/*/run /etc/services.d/*/finish

# No `WORKDIR /workspace`: it bakes a real directory into the image and the
# persistent /workspace -> /data/workspace symlink (cont-init 50-workspace)
# could never be created.
WORKDIR /
# Entrypoint /init (from HA base) is PID 1. Longruns live in /etc/services.d.
# Do not set CMD to /run.sh — that would start a second Multica alongside services.d.

# Access-mode defaults for this add-on variant (appended by sync-addons.sh).
# AGENT_HOST_MODE_LABEL drives every environment name (agent-host-name).
ENV \
    MULTICA_ACCESS_MODE=rw \
    AGENT_HOST_MODE_LABEL=RW \
    MULTICA_DEFAULT_RUNTIME_NAME=""
