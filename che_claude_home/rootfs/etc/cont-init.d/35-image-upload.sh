#!/usr/bin/with-contenv bashio
# ============================================================================
# 35-image-upload.sh — make `enable_image_upload` actually do something
#
# Up to 0.1.5 this option existed in config.yaml and in the schema with NO
# implementation anywhere in the repo. Toggling it did nothing, silently, with
# no error — the worst kind of the bugs found on 2026-07-27, because the others
# at least pointed at a wrong path. This one was a switch wired to nothing.
#
# What it does now: install the trzsz receiver. ttyd 1.7.7 already ships the
# entire client half (TrzszAddon, TrzszUploadFiles, and trzszDragInitTimeout for
# drag-and-drop) — the only missing piece was the binary on this side. No
# sidecar service, no extra port, no HTTP endpoint.
#
# Usage note for whoever reads this next: Claude Code occupies the terminal, so
# there is no shell prompt to type `trz` into. Run it from a tmux popup instead:
#     tmux display-popup -E trz
# then drag the file onto the window. Claude itself can open that popup on the
# user's behalf.
#
# Files also arrive perfectly well via /share/che-uploads (Samba), the HA Media
# browser (/media), or the File Editor add-on — none of which need this hook.
# ============================================================================
set -euo pipefail

if bashio::config.true 'enable_image_upload'; then
    TRZ_BIN="/data/packages/python/venv/bin/trz"

    if [ ! -x "$TRZ_BIN" ]; then
        bashio::log.info "[35-upload] Installing trzsz receiver into /data/packages"
        # Non-fatal: a boot without network must not abort container start.
        if persist-install --python trzsz >/dev/null 2>&1; then
            bashio::log.info "[35-upload] trzsz ready"
        else
            bashio::log.warning "[35-upload] trzsz install failed (offline?) — will retry next start"
        fi
    fi

    # A known landing spot, so "where do I put it" has one answer.
    if [ ! -d /share/che-uploads ]; then
        mkdir -p /share/che-uploads
        cat > /share/che-uploads/README.txt <<'EOF'
Drop files here for Claude to read.

Ways in, easiest first:
  - HA Media browser  : Settings -> Media -> upload   (lands in /media)
  - Samba             : \\homeassistant\share\che-uploads
  - File Editor addon : upload into /config
  - Terminal          : ask Claude to open a trzsz popup, then drag the file on

Then just say "check uploads". There is no watcher and no daemon --
you are the trigger.
EOF
        bashio::log.info "[35-upload] Created /share/che-uploads"
    fi
else
    bashio::log.info "[35-upload] enable_image_upload=false — skipping"
fi
