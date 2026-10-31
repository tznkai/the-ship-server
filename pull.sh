#!/bin/bash
# SPDX-FileCopyrightText: 2026 K. Chen
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Try to pull the Linux dedicated server for The Ship (app 2403) with SteamCMD in Docker.
# Files land in ./server; SteamCMD's login cache in ./.steamcmd, so Steam Guard is needed once.
set -euo pipefail
cd "$(dirname "$0")"
set -a
# shellcheck source=/dev/null
source .env
set +a
if [ -z "${STEAM_USER}" ] || [ -z "${STEAM_PASS}" ]; then
    echo "Fill in STEAM_USER and STEAM_PASS in .env first." >&2
    exit 1
fi
mkdir -p server .steamcmd
docker run --rm -i -e STEAM_USER -e STEAM_PASS -e STEAM_AUTH \
    -v "$PWD/server:/data" -v "$PWD/.steamcmd:/root/.local/share/Steam" \
    --entrypoint bash steamcmd/steamcmd:latest -c '
        login=(+login "$STEAM_USER" "$STEAM_PASS")
        [ -n "$STEAM_AUTH" ] && login+=("$STEAM_AUTH")
        steamcmd +@sSteamCmdForcePlatformType linux +force_install_dir /data "${login[@]}" \
            +app_update 2403 validate +quit'
echo "--- result ---"
ls -la server
