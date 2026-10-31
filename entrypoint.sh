#!/bin/bash
# SPDX-FileCopyrightText: 2026 K. Chen
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Pterodactyl yolk-style entrypoint: expand {{VAR}} in $STARTUP, then exec it.
set -e
cd /home/container
if [ -z "${STARTUP}" ]; then
    echo "STARTUP is not set; run this image from the Pterodactyl egg." >&2
    exit 1
fi
# The engine dumps ~190 MB cores into the server directory on every crash.
ulimit -c 0
# Overlap-safe string copies and fast refusal of the retired Steam2 servers; see shim/memfix.c.
export LD_PRELOAD=/usr/local/lib/memfix.so
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')
printf '\033[1m\033[33mcontainer~ \033[0m%s\n' "${PARSED}"
eval "exec ${PARSED}"
