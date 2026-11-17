<!-- SPDX-FileCopyrightText: 2026 K. Chen -->
<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->

# The Ship: Murder Party — Pterodactyl egg

## Human to human
Hi, human author here. I wrote this section of the README myself so you don't have get through Claudese to understand what's happening. This entire project solves a me-shaped problem: how do I let my wife play The Ship, which I host on my homelab. I hope it can be useful to you in playing this classic game that never quite got the love it deserved.

Outside of this section of the README, including the rest of this file, this project, was directed by K.Chen through iterative instruction and testing, orchestrated by Claude Code using Opus 5.5, and audited and coded by various Claude models of that generation. This presents certain risks to you. Your best way to alleviate those risks is what it always is with free and open source software: audit the code yourself, and fork as required.

## What this is

This project runs a dedicated server for *The Ship: Murder Party* in a container, built for the
[Pterodactyl](https://pterodactyl.io) game server panel. The game's Linux dedicated server (Steam
app 2403) was last updated in 2013 and no longer runs on a modern Linux system as shipped. This
project supplies what it needs to run again.

It has two parts:

- **The egg** (`egg-the-ship.json`), which you import into Pterodactyl. It describes the server's
  settings and contains the install script, which downloads the game files with SteamCMD and fixes
  them so they run.
- **The runtime image** (`ghcr.io/tznkai/the-ship-server`), the container the server runs in. It
  provides an old enough Linux userland and a small compatibility library for the 2007 engine. It
  does not contain the game files; the egg's installer puts those on the server's disk.

### Other platforms (unsupported)

Pterodactyl is the only supported platform. The image and install script are ordinary Docker
pieces, so they can be run elsewhere, but nothing outside Pterodactyl is tested:

- **Pelican** and other Pterodactyl forks that import `PTDL_v2` eggs may work as is.
- **Plain Docker** works in principle, by doing by hand what the panel does. See
  [Running without a panel](#running-without-a-panel-unsupported) in the technical reference.
- The image needs an x86 host (amd64 or i386). It does not run on ARM without emulation.

## Installing on Pterodactyl

You need panel admin access: the Steam fields can only be set and cleared from the admin area.

### What you need

- A Steam account. Steam does not give app 2403 to anonymous logins, but any Steam account works,
  and it does not need to own the game. A throwaway Steam account will work.
- If the account uses Steam Guard, access to its current Steam Guard code at install time.
- A port for the server, by default 27015. Players connect over UDP. RCON uses TCP on the same port.

### Install

1. Import the egg: **Admin → Nests**, choose a nest (or create one), **Import Egg**, and upload
   `egg-the-ship.json`.
2. Create the server: **Admin → Servers → Create New**. Pick the egg, and give the server a primary
   allocation (for example 27015).
3. In the server's variables, fill in:
   - **Steam username**
   - **Steam password**
   - **Steam Guard code**, only if the account uses Steam Guard. Enter the current code right
     before you create the server or start the install; codes expire after a short time.

   **All three are needed for the initial install and for every reinstall.** The install fails
   without the username and password.
4. Create the server. The install runs on its own. It is done when the install log ends with
   `The Ship dedicated server installed.`
5. **Clear the Steam credentials** (next section) before you hand the server to anyone.

### Clear the Steam credentials after every install

Pterodactyl has no install-only variables. Every egg variable, including the hidden ones, is also
passed into the running game server, where anything running inside it can read it. That includes a
plugin a server user uploads, or an exploit against the 2013 engine. "Hidden" only hides a value in
the panel. The Steam password should stay in the panel only as long as the install takes.

After **every** install or reinstall:

1. Go to **Admin → Servers**, open the server, and select the **Startup** tab.
2. Under the service variables, delete the contents of **Steam password** and **Steam Guard code**.
   Leave the fields empty.
3. Click **Save Modifications**.
4. Restart the server (stop, then start, from the server's console page). **Do not skip this.** The
   running container keeps the old values until it is recreated, and a restart recreates it.

The username can stay. It is shown to server users anyway, because SteamCMD prints it in the install
console.

To check from the Wings node that the values are gone, run this. It prints the names of any Steam
variables that still have a value, and prints nothing if they are clear. It never prints the values.

```sh
docker exec <server-uuid> sh -c "tr '\0' '\n' < /proc/1/environ | grep -E '^STEAM_(PASS|AUTH)=.+' | cut -d= -f1"
```

Whatever account you use is exposed to anything that runs on the server while its password is set.
A throwaway Steam account will work.

### Reinstalling

1. In **Admin → Servers → (server) → Startup**, enter the Steam password again, and a fresh Steam
   Guard code if the account uses one. Save.
2. Reinstall: **Admin → Servers → (server) → Manage → Reinstall Server**, or **Settings → Reinstall
   Server** on the server's own page.
3. When the install finishes, clear the credentials again, as above, and restart.

### Configuring the server

These are egg variables, on the server's **Startup** page:

| Variable | Sets | Notes |
|---|---|---|
| Server name | `hostname` | Name in the server browser. |
| Default map | `+map` | Without `.bsp`. Default `batavier`. |
| Game mode | `ship_game_mode` | 0 Hunt, 1 Elimination, 2 Duel, 3 Deathmatch, 4 Team VIP, 5 Team Elimination, 6–8 World Leader Hunt / Elimination / Deathmatch. |
| Max players | `-maxplayers` | 2–32. |
| Server password | `sv_password` | Blank for a public server. |
| RCON password | `rcon_password` | Blank disables RCON. |
| LAN only | `sv_lan` | 1 means LAN clients only and no master-server heartbeat. Add `-insecure` to Extra launch options if Steam validation rejects players. |
| Enable bots | `ship_enable_bots` | Off by default. With 0, no bots join whatever the quota says. |
| Bot quota | `bot_quota` | Default 4. |
| Bot quota mode | `bot_quota_mode` | `normal` (always N bots), `fill` (top up to N players), `match` (N bots per human). |
| Bot difficulty | `bot_difficulty` | 0 easy to 3 expert. |
| Bots wait for players | `bot_join_after_player` | 1 keeps bots out of an empty server. |
| Minimum participants | `ship_num_participants` | Players in the kill loop; 0 is the game default. |
| Extra launch options | appended | For example `-insecure`, `-tickrate 100`, `-nohltv`, `+sv_region 3`, `+exec my.cfg`. Letters, digits, spaces and `_ . + / -` only. |

Other game settings, such as round timers, go in `ship/cfg/server.cfg`, which ships fully
commented. Anything you uncomment there runs at every map load and overrides the egg variables.

---

## Technical reference

This section is for maintainers and for agents working on the repository. It records what each
piece does, the constraints it works under, and why each fix exists, so that changes don't
reintroduce a failure that was already debugged.

### Repository layout

| Path | Role |
|---|---|
| `Dockerfile` | Runtime image. Two stages on `debian/eol:stretch` (`linux/386`): the first compiles `shim/memfix.c`, the second is the runtime with `dumb-init`, the shim at `/usr/local/lib/memfix.so`, and user `container` (uid 1000, home `/home/container`). |
| `entrypoint.sh` | Image entrypoint, run under `dumb-init`. Deletes a leftover `.steamcmd-install`, disables core dumps, sets `LD_PRELOAD` to the shim, expands `{{VAR}}` in `$STARTUP` to `${VAR}`, echoes the command and `exec`s it (yolk-style). |
| `shim/memfix.c` | `LD_PRELOAD` library. Overrides `memcpy`, `strcpy`, `strncpy`, `strcat` with overlap-safe versions and makes `connect` to TCP ports 27030–27039 fail with `ECONNREFUSED`. |
| `install.sh` | Egg install script. Runs as root in `ghcr.io/parkervcp/installers:debian` with the server volume at `/mnt/server`. |
| `tools/build_egg.py` | Source of truth for the egg. Generates `egg-the-ship.json` and embeds `install.sh` into it. |
| `egg-the-ship.json` | Generated. Never edit by hand. |
| `pull.sh` | Local test helper. Downloads app 2403 into `./server` with `steamcmd/steamcmd`, reading credentials from `.env`, and caching the Steam login in `./.steamcmd`. It does **not** apply the install fixes below, so its output does not run as is. |
| `.github/workflows/image.yml` | CI. See below. |
| `LICENSES/` | AGPL-3.0-or-later. Every source file has an SPDX header. |

### Build and release

- After editing `install.sh` or `tools/build_egg.py`, run `python3 tools/build_egg.py` and commit
  the regenerated `egg-the-ship.json`. CI fails if the committed egg differs from the generated one.
- CI runs `shellcheck` on `install.sh`, `entrypoint.sh` and `pull.sh` on every push to `main` and on
  pull requests, then builds the image.
- Pushing a `v*` tag publishes the image to `ghcr.io/tznkai/the-ship-server` with `latest`, the
  semver tag and a sha tag. Changes to `Dockerfile`, `entrypoint.sh` or the shim reach servers only
  after a tag is pushed. Changes to `install.sh` or the egg reach servers when the egg is
  re-imported.
- The image is built and tagged as `linux/amd64` even though its userland is 32-bit, because amd64
  Wings nodes refuse to pull a `linux/386`-only image.
- The egg's `author` must be an email address, or the panel's import fails with a 500.

### Egg contract

- Startup: `./srcds_run -game ship -console -norestart -port {{SERVER_PORT}} -maxplayers ... +map {{SRCDS_MAP}}`.
  `+map` is last so every setting is in place before the map loads. String values are quoted, so
  their validation rules forbid `"`. `EXTRA_ARGS` is unquoted and limited to `[A-Za-z0-9_ .+/-]`.
- Start detection: the panel marks the server running on the console line
  `Connection to Steam servers successful`. Stop command: `quit`.
- `file_denylist`: `.steamcmd-install`.
- Steam variables: `STEAM_USER` is viewable and not editable by server users. `STEAM_PASS` and
  `STEAM_AUTH` are hidden and not editable. All three are `nullable` in the panel so an admin can
  clear them after install. `install.sh` enforces that `STEAM_USER` and `STEAM_PASS` are set.

### Install script

In order:

1. Exits with an error if `STEAM_USER` or `STEAM_PASS` is empty.
2. Installs `ca-certificates curl lib32gcc-s1` in the installer container.
3. Deletes, then recreates, `/mnt/server/.steamcmd-install`, and points `HOME` inside it. SteamCMD
   runs from the server disk because it needs about 250 MB free to update itself, more than Wings'
   `/tmp` tmpfs (100 MB by default). An `EXIT` trap deletes the folder.
4. Runs SteamCMD: `+@sSteamCmdForcePlatformType linux +force_install_dir /mnt/server +login ... +app_update 2403 validate +quit`.
   Forcing the Linux platform is required because the app only defines a Windows launch config.
   SteamCMD's exit code is ignored; success is checked by the presence of `srcds_run`.
5. Copies SteamCMD's `linux32/steamclient.so` over `bin/steamclient_i486.so`. `validate` restores
   the old file, so this runs on every install.
6. Creates lowercase symlinks for mixed-case files and directories under `ship/`.

### Compatibility fixes

Each of these was found by running the server and debugging the failure. Removing any of them
brings the failure back.

- **Debian 9 (glibc 2.24).** The engine passes a misaligned address to `futex`. glibc 2.25 and later
  abort with "The futex facility returned an unexpected error code". Debian 9 is the newest release
  with an older glibc, so the base image cannot be upgraded.
- **Overlap-safe string copies (shim).** The engine copies strings between overlapping buffers,
  which modern optimised `memcpy`/`strcpy` corrupt. The symptom is garbled console commands, so
  `+map` never runs. The shim routes these through `memmove`.
- **Steam2 connect refusal (shim).** The engine blocks its main thread on a TCP connect to the
  retired Steam2 servers (ports 27030–27039). The shim fails those connects at once.
- **Modern `steamclient.so`.** The bundled 2008 library cannot log on to today's Steam, and players
  are kicked with "STEAM validation rejected". SteamCMD's current 32-bit build still implements the
  `SteamClient006` and `SteamGameServer002` interfaces the engine uses, so the installer swaps it in.
- **Lowercase links.** The game files are mixed case (`scripts/Needs`, `GameInfo.txt`), but the code
  asks for lowercase paths. Without the links the server cannot find `gameinfo.txt`, and it crashes
  when a player spawns. For every mixed-case path under `ship/` that has no lowercase twin, the
  installer adds a symlink with the lowercase name pointing at the original, so both spellings
  resolve.
- **No core dumps.** The engine writes a ~190 MB core into the server directory on every crash;
  `entrypoint.sh` sets `ulimit -c 0`.

### Credential handling

- Pterodactyl passes every egg variable, hidden or not, into both the installer and the runtime
  container as environment variables. There is no install-only variable. In the runtime container,
  `dumb-init` is PID 1 and runs as the same user as the server, so unsetting the variables in
  `entrypoint.sh` would not help: `/proc/1/environ` still has them. The only fix is for the admin to
  clear them and recreate the container, which is why the user instructions above insist on it.
- SteamCMD's folder holds `config/config.vdf`, a cached login token that works without the password,
  and sentry files. In the installer, bash is PID 1 and ignores `SIGTERM`, so an install timeout,
  stop or OOM kill ends in `SIGKILL` and the `EXIT` trap never runs. Three layers cover this: the
  folder is on the egg's `file_denylist`, `install.sh` wipes it before use (so nothing a user
  planted in it runs as root with the credentials), and `entrypoint.sh` deletes it at every start.
- SteamCMD prints `Logging in user '<name>'` to the install console, which server users can see and
  Wings keeps in its install logs. That is why the username is not hidden.
- Never add the Steam variables to the startup command or print them from a script.

### Running without a panel (unsupported)

Untested. This reproduces by hand what Pterodactyl does:

1. **Install.** Run `install.sh` as root in the installer image, with the server directory mounted
   at `/mnt/server` and the Steam variables set:

   ```sh
   mkdir -p server
   docker run --rm -e STEAM_USER -e STEAM_PASS -e STEAM_AUTH \
       -v "$PWD/server:/mnt/server" -v "$PWD/install.sh:/install.sh:ro" \
       ghcr.io/parkervcp/installers:debian bash /install.sh
   sudo chown -R 1000:1000 server   # Wings does this after an install; the runtime runs as uid 1000
   ```

2. **Run.** Mount the directory at `/home/container`, publish the port on UDP and TCP, and set
   `STARTUP`. Do not pass the Steam variables to this container.

   ```sh
   docker run -it --name the-ship -p 27015:27015/udp -p 27015:27015/tcp \
       -v "$PWD/server:/home/container" \
       -e STARTUP='./srcds_run -game ship -console -norestart -port 27015 -maxplayers 16 +ip 0.0.0.0 +map batavier' \
       ghcr.io/tznkai/the-ship-server:latest
   ```

   `{{VAR}}` placeholders in `STARTUP` are expanded from the container's environment, so the egg's
   full startup line works if each variable it names is also passed with `-e`.

### Known issues

- `The nav mesh needs a full nav_analyze` appears on map load. It is a warning only; every stock map
  ships a `.nav` mesh and bots work on all of them.
- If Steam is unreachable at startup, the panel shows the server as starting even though it is
  running, because it waits for `Connection to Steam servers successful`.
