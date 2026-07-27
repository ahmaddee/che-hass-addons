# ============================================================================
# CHE Claude in HomE Assistant — Dockerfile
# ----------------------------------------------------------------------------
# BUILD_FROM is deprecated in Supervisor 2026.04.0+. Use explicit ARG default
# so both `docker build` and Supervisor's `home-assistant/builder` action work.
# The arg is overridden per-arch by build.yaml at build time.
# ============================================================================
ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base:3.21
FROM ${BUILD_FROM}

# ---------------------------------------------------------------------------
# System packages (single layer, minimal cache)
# ---------------------------------------------------------------------------
RUN apk add --no-cache \
        bash \
        curl \
        wget \
        git \
        jq \
        yq \
        nano \
        vim \
        tree \
        tmux \
        ttyd \
        nodejs \
        npm \
        python3 \
        py3-pip \
        py3-requests \
        py3-yaml \
        openssh-client \
        ca-certificates \
        tzdata

# ---------------------------------------------------------------------------
# Architecture detection
# Supervisor passes BUILD_ARCH; BuildKit sets TARGETARCH/TARGETVARIANT.
# Fall back to uname -m so plain `docker build` also works.
# ---------------------------------------------------------------------------
ARG BUILD_ARCH
ARG TARGETARCH
ARG TARGETVARIANT

RUN ADDON_ARCH="${BUILD_ARCH}"; \
    if [ -z "${ADDON_ARCH}" ]; then \
        case "${TARGETARCH}/${TARGETVARIANT}" in \
            amd64/*)  ADDON_ARCH="amd64" ;; \
            arm64/*)  ADDON_ARCH="aarch64" ;; \
            arm/v7)   ADDON_ARCH="armv7" ;; \
            arm/v6)   ADDON_ARCH="armhf" ;; \
            arm/)     ADDON_ARCH="armv7" ;; \
            386/*)    ADDON_ARCH="i386" ;; \
        esac; \
    fi; \
    if [ -z "${ADDON_ARCH}" ]; then \
        case "$(uname -m)" in \
            x86_64)        ADDON_ARCH="amd64" ;; \
            aarch64|arm64) ADDON_ARCH="aarch64" ;; \
            armv7l)        ADDON_ARCH="armv7" ;; \
            armv6l)        ADDON_ARCH="armhf" ;; \
        esac; \
    fi; \
    [ -z "${ADDON_ARCH}" ] && echo "Cannot determine arch" && exit 1; \
    printf '%s\n' "${ADDON_ARCH}" > /etc/addon-arch; \
    echo "Resolved add-on architecture: ${ADDON_ARCH}"

# ---------------------------------------------------------------------------
# Claude Code CLI — native install for 64-bit, npm for 32-bit ARM
# 32-bit ARM has no native binary; pins the last portable 1.x npm release.
# When claude_source != baked, run.sh overrides this at startup.
# ---------------------------------------------------------------------------
RUN ADDON_ARCH=$(cat /etc/addon-arch); \
    if [ "${ADDON_ARCH}" = "armv7" ] || [ "${ADDON_ARCH}" = "armhf" ]; then \
        echo "32-bit ARM (${ADDON_ARCH}): npm install claude-code 1.0.128 (last portable)"; \
        npm install -g @anthropic-ai/claude-code@1.0.128; \
    else \
        (curl -fsSL https://claude.ai/install.sh | bash \
            && ln -sf /root/.local/bin/claude /usr/local/bin/claude) \
        || npm install -g @anthropic-ai/claude-code; \
    fi

# ---------------------------------------------------------------------------
# Home Assistant CLI (`ha` command)
# ---------------------------------------------------------------------------
RUN ADDON_ARCH=$(cat /etc/addon-arch); \
    case "${ADDON_ARCH}" in \
        amd64)   HA_ARCH="amd64";   HA_VERSION="latest" ;; \
        aarch64) HA_ARCH="aarch64"; HA_VERSION="latest" ;; \
        armv7)   HA_ARCH="armv7";   HA_VERSION="4.46.0" ;; \
        armhf)   HA_ARCH="armhf";   HA_VERSION="4.46.0" ;; \
    esac; \
    if [ "${HA_VERSION}" = "latest" ]; then \
        HA_VERSION=$(curl -fsSL https://api.github.com/repos/home-assistant/cli/releases/latest | jq -r '.tag_name'); \
    fi; \
    curl -fsSL -o /usr/bin/ha \
        "https://github.com/home-assistant/cli/releases/download/${HA_VERSION}/ha_${HA_ARCH}" && \
    chmod +x /usr/bin/ha

# ---------------------------------------------------------------------------
# GitHub CLI (`gh` command) — armv7/armhf use armv6 binary (pinned last available)
# ---------------------------------------------------------------------------
RUN ADDON_ARCH=$(cat /etc/addon-arch); \
    case "${ADDON_ARCH}" in \
        amd64)   GH_ARCH="amd64"; GH_VERSION="latest" ;; \
        aarch64) GH_ARCH="arm64"; GH_VERSION="latest" ;; \
        armv7)   GH_ARCH="armv6"; GH_VERSION="2.96.0" ;; \
        armhf)   GH_ARCH="armv6"; GH_VERSION="2.96.0" ;; \
    esac; \
    if [ "${GH_VERSION}" = "latest" ]; then \
        GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//'); \
    fi; \
    curl -fsSL -o /tmp/gh.tar.gz \
        "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz" && \
    tar -xzf /tmp/gh.tar.gz -C /tmp && \
    mv /tmp/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh /usr/bin/gh && \
    chmod +x /usr/bin/gh && \
    rm -rf /tmp/gh*

# ---------------------------------------------------------------------------
# Bake the CHE rootfs on top: services.d, cont-init.d, profile.d, helpers
# ---------------------------------------------------------------------------
COPY rootfs/ /

RUN chmod +x /usr/local/bin/* \
    && chmod +x /etc/services.d/*/run \
    && chmod +x /etc/services.d/*/finish 2>/dev/null || true \
    && chmod +x /etc/cont-init.d/*

# ---------------------------------------------------------------------------
# Seed skills into /opt so first-boot init can copy them to /data/home/.claude/
# ---------------------------------------------------------------------------
COPY seeds/.claude/ /opt/.claude/

WORKDIR /config

# s6 supervises everything — no CMD needed; base image sets ENTRYPOINT to /init
