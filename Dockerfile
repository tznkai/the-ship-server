# SPDX-FileCopyrightText: 2026 K. Chen
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Runtime image for The Ship: Murder Party dedicated server (Steam app 2403).
# The server is a 2007-era 32-bit Source build. It needs a 32-bit userland with glibc < 2.25:
# its engine waits on a misaligned futex, which newer glibc treats as fatal. Debian 9 (glibc 2.24)
# is the newest release that runs it. Game files are not baked in: the egg installs them.
FROM --platform=linux/386 debian/eol:stretch AS shim
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev
COPY shim/memfix.c /src/memfix.c
RUN gcc -O2 -shared -fPIC -fno-builtin -Wall -o /src/memfix.so /src/memfix.c -ldl

FROM --platform=linux/386 debian/eol:stretch
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates dumb-init iproute2 libgcc1 libstdc++6 zlib1g libncurses5 libtinfo5 \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -d /home/container -s /bin/bash container

COPY --from=shim /src/memfix.so /usr/local/lib/memfix.so
COPY --chmod=755 entrypoint.sh /entrypoint.sh

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/entrypoint.sh"]
