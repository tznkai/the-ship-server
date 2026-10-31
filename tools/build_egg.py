# SPDX-FileCopyrightText: 2026 K. Chen
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Write egg-the-ship.json, embedding install.sh as the egg's installation script."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def variable(name, env, default, description, rules, viewable=True, editable=True):
    return {
        "name": name,
        "description": description,
        "env_variable": env,
        "default_value": default,
        "user_viewable": viewable,
        "user_editable": editable,
        "rules": rules,
        "field_type": "text",
    }


EGG = {
    "_comment": "DO NOT EDIT: FILE GENERATED AUTOMATICALLY BY PTERODACTYL PANEL - PTERODACTYL.IO",
    "meta": {"version": "PTDL_v2", "update_url": None},
    "exported_at": "2026-10-31T00:00:00+00:00",
    "name": "The Ship: Murder Party",
    # The panel's import returns 500 unless author is an email address.
    "author": "tznkai@gmail.com",
    "description": "Dedicated server for The Ship: Murder Party (Steam app 2403, Linux Source dedicated server). Requires a Steam account to install.",
    "features": None,
    "docker_images": {"The Ship": "ghcr.io/tznkai/the-ship-server:latest"},
    "file_denylist": [],
    "startup": (
        "./srcds_run -game ship -console -norestart -port {{SERVER_PORT}} "
        "-maxplayers {{MAX_PLAYERS}} +ip 0.0.0.0 +ship_game_mode {{GAME_MODE}} +map {{SRCDS_MAP}} "
        '+hostname "{{SERVER_NAME}}" +sv_password "{{SERVER_PASSWORD}}" '
        '+rcon_password "{{RCON_PASSWORD}}"'
    ),
    "config": {
        "files": "{}",
        "startup": json.dumps({"done": "Connection to Steam servers successful"}),
        "logs": "{}",
        "stop": "quit",
    },
    "scripts": {
        "installation": {
            "script": (ROOT / "install.sh").read_text(),
            "container": "ghcr.io/parkervcp/installers:debian",
            "entrypoint": "bash",
        }
    },
    "variables": [
        variable(
            "Steam username",
            "STEAM_USER",
            "",
            "Steam account used to download the server. App 2403 is not available anonymously; "
            "any Steam account works. Hidden from server users.",
            "required|string|max:64",
            viewable=False,
            editable=False,
        ),
        variable(
            "Steam password",
            "STEAM_PASS",
            "",
            "Password for the Steam account above. Only used during install. Hidden from server users.",
            "required|string|max:128",
            viewable=False,
            editable=False,
        ),
        variable(
            "Steam Guard code",
            "STEAM_AUTH",
            "",
            "Optional. Current Steam Guard code, needed only if the account has Steam Guard enabled. "
            "Set it just before reinstalling; codes expire.",
            "nullable|string|max:10",
            viewable=False,
            editable=False,
        ),
        variable(
            "Server name",
            "SERVER_NAME",
            "The Ship Server",
            "Name shown in the server browser.",
            "required|string|max:64",
        ),
        variable(
            "Default map",
            "SRCDS_MAP",
            "batavier",
            "Map loaded at startup, without the .bsp extension.",
            "required|string|alpha_dash|max:64",
        ),
        variable(
            "Game mode",
            "GAME_MODE",
            "0",
            "0 Hunt, 1 Elimination, 2 Duel, 3 Deathmatch, 4 Team VIP, 5 Team Elimination, "
            "6 World Leader Hunt, 7 World Leader Elimination, 8 World Leader Deathmatch.",
            "required|integer|between:0,8",
        ),
        variable(
            "Max players",
            "MAX_PLAYERS",
            "16",
            "Maximum number of players.",
            "required|integer|between:2,32",
        ),
        variable(
            "Server password",
            "SERVER_PASSWORD",
            "",
            "Optional. Password players need to join. Leave blank for a public server.",
            'nullable|string|max:64|regex:/^[^"]*$/',
        ),
        variable(
            "RCON password",
            "RCON_PASSWORD",
            "",
            "Optional. Remote console password. Leave blank to disable RCON.",
            'nullable|string|max:64|regex:/^[^"]*$/',
        ),
    ],
}

if __name__ == "__main__":
    out = ROOT / "egg-the-ship.json"
    out.write_text(json.dumps(EGG, indent=4) + "\n")
    print(f"wrote {out}")
