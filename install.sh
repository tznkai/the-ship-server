#!/bin/bash
# SPDX-FileCopyrightText: 2026 K. Chen
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Pterodactyl install script for The Ship: Murder Party dedicated server.
# Runs as root in the installer container with the server's files mounted at /mnt/server.
# This file is embedded in egg-the-ship.json; run tools/build_egg.py after editing it.
#
# App 2403 is not in Steam's anonymous dedicated-server license, so a real Steam account
# is required (the app is free on demand; the account does not need to own the game).
set -euo pipefail

APP_ID=2403
SERVER_DIR=/mnt/server

if [ -z "${STEAM_USER:-}" ] || [ -z "${STEAM_PASS:-}" ]; then
    echo "STEAM_USER and STEAM_PASS are required: Steam does not serve app ${APP_ID} to anonymous logins." >&2
    exit 1
fi

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl lib32gcc-s1

# SteamCMD and its login state live in /tmp, not the server directory, so the
# account's cached credentials never end up in files the panel lets users browse.
export HOME=/tmp/steamhome
mkdir -p "${HOME}" /tmp/steamcmd "${SERVER_DIR}"
curl -sSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz -C /tmp/steamcmd
cd /tmp/steamcmd

LOGIN=(+login "${STEAM_USER}" "${STEAM_PASS}")
if [ -n "${STEAM_AUTH:-}" ]; then
    LOGIN+=("${STEAM_AUTH}")
fi

# The app only defines a Windows launch config; forcing Linux gets the Linux binaries.
./steamcmd.sh +@sSteamCmdForcePlatformType linux +force_install_dir "${SERVER_DIR}" \
    "${LOGIN[@]}" +app_update "${APP_ID}" validate +quit || true

if [ ! -f "${SERVER_DIR}/srcds_run" ]; then
    echo "Install failed: ${SERVER_DIR}/srcds_run is missing. Check the Steam login output above." >&2
    exit 1
fi

# The bundled 2008 steamclient cannot log on to today's Steam, so players fail validation.
# SteamCMD's current 32-bit steamclient still implements the interfaces this engine asks for.
# app_update validate restores the old file, so this runs on every install.
cp -f /tmp/steamcmd/linux32/steamclient.so "${SERVER_DIR}/bin/steamclient_i486.so"

# The game's files are mixed case (scripts/Needs, GameInfo.txt) but its code asks for
# lowercase paths. Without these, spawning a player crashes the server. Give every mixed-case
# file and directory a lowercase symlink beside it so both spellings resolve.
links=0
while IFS= read -r -d '' path; do
    dir=$(dirname "${path}")
    name=$(basename "${path}")
    lower=$(printf '%s' "${name}" | tr '[:upper:]' '[:lower:]')
    if [ ! -e "${dir}/${lower}" ] && [ ! -L "${dir}/${lower}" ]; then
        ln -s "${name}" "${dir}/${lower}"
        links=$((links + 1))
    fi
done < <(find "${SERVER_DIR}/ship" -name '*[A-Z]*' ! -type l -print0)
echo "Created ${links} lowercase links."

rm -rf /tmp/steamcmd /tmp/steamhome
echo "The Ship dedicated server installed."
