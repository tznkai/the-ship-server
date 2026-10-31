<!-- SPDX-FileCopyrightText: 2026 K. Chen -->
<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->

# The Ship: Murder Party — Pterodactyl egg

Pterodactyl egg and runtime image for a The Ship: Murder Party dedicated server
(Steam app 2403, the Linux Source dedicated server last updated in 2013).

## Files

- `Dockerfile`, `entrypoint.sh`: runtime image. Debian 9 i386, with the shim preloaded and yolk-style `{{VAR}}` startup expansion.
- `shim/memfix.c`: compatibility shim for the 2007 engine, preloaded with `LD_PRELOAD`.
- `install.sh`: the egg's install script. It runs in `ghcr.io/parkervcp/installers:debian`.
- `tools/build_egg.py`: generates `egg-the-ship.json` and embeds `install.sh` in it. Run `python3 tools/build_egg.py` after editing either file.
- `pull.sh`: downloads the server into `./server` outside the panel, for local testing. It reads Steam credentials from `.env`.

## Publishing the image

CI builds the image on every push. Pushing a `v*` tag also publishes `ghcr.io/tznkai/the-ship-server`.
The image is published as `linux/amd64` even though everything in it is 32-bit, so that amd64 Wings
nodes can pull it.

## Deploy

1. Import `egg-the-ship.json` in the panel (Admin → Nests → Import Egg).
2. Create a server with a primary allocation, by default 27015. Players connect over UDP; TCP is only for RCON.
3. Set **Steam username** and **Steam password**. Steam does not serve app 2403 to anonymous
   logins, but any Steam account works and it does not need to own the game. The installer starts
   with no saved login every time. If the account uses Steam Guard, enter the current code in
   **Steam Guard code** just before installing. A dedicated account without Steam Guard is easiest.
4. Install, then start. Game settings such as bots and timers go in `ship/cfg/server.cfg`, which ships fully commented.

## Why the image is built this way

Each of these was found by running the server and debugging the failures:

- **Debian 9 (glibc 2.24):** the engine passes a misaligned address to `futex`. glibc 2.25 and
  later abort on the resulting error ("The futex facility returned an unexpected error code").
- **The shim:** the engine copies strings between overlapping buffers, which modern
  `memcpy`/`strcpy` corrupt. The visible symptom is garbled startup commands, so `+map` never runs.
  The engine also blocks its main thread on a TCP connect to retired Steam2 servers
  (ports 27030–27039). The shim makes those connects fail at once.
- **Modern `steamclient.so`:** the bundled 2008 library cannot log on to today's Steam, and players
  are then kicked with "STEAM validation rejected". The install script swaps in SteamCMD's current
  32-bit build, which still implements the `SteamClient006` and `SteamGameServer002` interfaces the
  engine uses.
- **Lowercase links:** the game files are mixed case (`scripts/Needs`, `GameInfo.txt`), but the
  code asks for lowercase paths. Without the links the server cannot find `gameinfo.txt`, and it
  crashes when a player spawns.

## Known issues

- `The nav mesh needs a full nav_analyze` appears on map load. It is a warning only.
- If Steam is unreachable at startup, the panel shows the server as starting even though it is
  running. The panel waits for the console line `Connection to Steam servers successful`.
