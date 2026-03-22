# Layered Docker image for TF2 cloud servers
# Inspired by melkortf/tf2-servers architecture:
#   tf2-base → tf2-sourcemod → tf2-plugins → tf2-configs → final
#
# Each stage can be built independently with --target for debugging:
#   docker build --target tf2-base -t serveme/tf2-base .
#   docker build --target tf2-sourcemod -t serveme/tf2-sourcemod .
#
# BuildKit caches each stage independently, so plugin updates don't
# rebuild the TF2 base, and config changes don't rebuild plugins.

# ============================================================
# Stage: rcon-build (compile rcon CLI tool)
# ============================================================
FROM ubuntu:24.04 AS rcon-build
RUN apt-get update && apt-get install -y build-essential git cmake libglib2.0-dev \
    && git clone https://github.com/n0la/rcon.git /tmp/rcon \
    && cd /tmp/rcon && sed -i '/ADD_SUBDIRECTORY(tests)/d' CMakeLists.txt && cmake . && make \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ============================================================
# Stage: tf2-base (Ubuntu + SteamCMD + TF2 dedicated server)
# ============================================================
FROM ubuntu:24.04 AS tf2-base

RUN echo steam steam/question select "I AGREE" | debconf-set-selections \
    && echo steam steam/license note '' | debconf-set-selections \
    && apt-get -y update \
    && apt-get -y install software-properties-common \
    && add-apt-repository multiverse \
    && dpkg --add-architecture i386 \
    && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
        libstdc++6 libcurl3-gnutls wget libncurses6 bzip2 unzip vim nano \
        lib32gcc-s1 lib32stdc++6 steamcmd \
        ca-certificates lib32z1 libncurses6:i386 libbz2-1.0:i386 \
        libtinfo6:i386 libcurl3-gnutls:i386 \
        openssh-server iptables curl sudo iproute2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && useradd -m tf2 \
    && su tf2 -c '/usr/games/steamcmd +quit' \
    && mkdir -p /run/sshd \
    && ssh-keygen -A \
    && echo "tf2 ALL=(ALL) NOPASSWD: /sbin/iptables, /usr/sbin/iptables, /usr/sbin/sshd" > /etc/sudoers.d/tf2 \
    && chmod 0440 /etc/sudoers.d/tf2

ENV HOME=/home/tf2
ENV USER=tf2
USER tf2

# Install TF2 dedicated server + strip maps/resources to minimize image
# SteamCMD sometimes fails with 0x426 on first attempt, retry once
ARG TF2_VERSION=0
RUN echo "Building for TF2 version: ${TF2_VERSION}" \
    && (/usr/games/steamcmd +force_install_dir /home/tf2/hlserver/tf2 +login anonymous +app_update 232250 +quit || \
        /usr/games/steamcmd +force_install_dir /home/tf2/hlserver/tf2 +login anonymous +app_update 232250 +quit) \
    && cd /home/tf2/hlserver/tf2/tf/maps && rm -f *.bsp \
    && rm -f /home/tf2/hlserver/tf2/tf/resource/tf_*.txt

COPY --from=rcon-build /tmp/rcon/rcon /home/tf2/hlserver/rcon

# ============================================================
# Stage: tf2-sourcemod (MetaMod + SourceMod)
# ============================================================
FROM tf2-base AS tf2-sourcemod

RUN cd /home/tf2/hlserver/tf2/tf \
    && mm_url=$(wget -q -O - "https://www.metamodsource.net/downloads.php?branch=stable" | grep -oP -m1 "https://[a-z.]+/mmsdrop/[0-9.]+/mmsource-(.*)-linux.tar.gz") \
    && sm_url=$(wget -q -O - "http://www.sourcemod.net/downloads.php?branch=stable" | grep -oP -m1 "https://[a-z.]+/smdrop/[0-9.]+/sourcemod-(.*)-linux.tar.gz") \
    && wget -nv $mm_url \
    && wget -nv $sm_url \
    && tar -xzf mmsource-*-linux.tar.gz \
    && tar -xzf sourcemod-*-linux.tar.gz \
    && rm *.tar.gz \
    && rm -f addons/sourcemod/plugins/nextmap.smx \
           addons/sourcemod/plugins/funcommands.smx \
           addons/sourcemod/plugins/funvotes.smx

# ============================================================
# Stage: tf2-plugins (competitive + utility plugins)
# ============================================================
FROM tf2-sourcemod AS tf2-plugins

COPY --chown=tf2:tf2 ExtendHumiliation.smx /tmp/ExtendHumiliation.smx
RUN cd /home/tf2/hlserver/tf2/tf \
    # SteamWorks
    && wget -nv "https://github.com/KyleSanderson/SteamWorks/releases/download/1.2.3c/package-lin.tgz" -O "steamworks.tar.gz" \
    && tar -xf steamworks.tar.gz --strip-components 1 \
    && rm steamworks.tar.gz \
    # SOAP-DM
    && wget -nv "https://github.com/sapphonie/SOAP-TF2DM/releases/download/v4.4.8/soap.zip" -O "soap-dm.zip" \
    && unzip -o soap-dm.zip \
    && rm soap-dm.zip \
    # Improved-Match-Timer
    && wget -nv "https://github.com/b4nnyBot/Progressive-Ruleset-Timer-Plugins/archive/master.zip" -O "improved-match-timer.zip" \
    && unzip -o improved-match-timer.zip \
    && cp -r Progressive-Ruleset-Timer-Plugins-main/* ./ \
    && rm -r Progressive-Ruleset-Timer-Plugins-main \
    && rm improved-match-timer.zip \
    # Socket
    && wget -nv "https://raw.githubusercontent.com/spiretf/docker-comp-server/master/socket_3.0.1.zip" -O "socket.zip" \
    && unzip -o socket.zip \
    && rm socket.zip \
    # tf2-comp-fixes
    && wget -nv https://github.com/ldesgoui/tf2-comp-fixes/releases/download/v1.18.0/tf2-comp-fixes.zip \
    && unzip -o tf2-comp-fixes.zip \
    && rm tf2-comp-fixes.zip \
    # srctvplus
    && cd /home/tf2/hlserver/tf2/tf/addons \
    && wget -nv https://github.com/dalegaard/srctvplus/releases/download/v3.0/srctvplus.vdf \
    && wget -nv https://github.com/dalegaard/srctvplus/releases/download/v3.0/srctvplus.so \
    # neocurl
    && cd /home/tf2/hlserver/tf2/tf/addons/sourcemod \
    && wget -nv "https://github.com/sapphonie/SM-neocurl-ext/releases/download/v2.0.1-beta1/sm-neocurl-repack.zip" -O "sm-neocurl.zip" \
    && unzip -o sm-neocurl.zip \
    && rm sm-neocurl.zip \
    # Websockets
    && wget -nv "https://github.com/peace-maker/sm-websocket/archive/master.zip" -O "sm-websocket.zip" \
    && unzip -o sm-websocket.zip \
    && cp -r sm-websocket-master/* ./ \
    && rm -r sm-websocket-master \
    && rm sm-websocket.zip \
    # F2 plugins (MedicStats, SupStats, LogsTF, RecordSTV, WaitForStv, AFK, RestoreScore, FixStvSlot, Updater)
    && cd /home/tf2/hlserver/tf2/tf/addons/sourcemod/plugins \
    && wget -nv "https://github.com/F2/F2s-sourcemod-plugins/releases/download/20250908-1757334414124/f2-sourcemod-plugins.zip" -O "f2-sourcemod-plugins.zip" \
    && unzip -o f2-sourcemod-plugins.zip \
    && rm f2-sourcemod-plugins.zip \
    # mapdownloader
    && wget -nv https://codeberg.org/spire/mapdownloader/raw/master/plugin/mapdownloader.smx \
    # demos.tf uploader
    && wget -nv https://codeberg.org/demostf/plugin/raw/ba1b642b92585af142a885af7159fa652916c6e7/demostf.smx \
    # Pause
    && wget -nv https://codeberg.org/spire/docker-comp-server/raw/master/pause.smx \
    # SdrConnect
    && wget -nv https://codeberg.org/spire/sdrconnect/raw/main/plugin/sdrconnect.smx \
    # SetTeam
    && wget -nv https://codeberg.org/spire/setteam/raw/master/plugin/setteam.smx \
    # ProperPregame
    && wget -nv https://github.com/AJagger/ProperPregame/raw/master/addons/sourcemod/plugins/properpregame.smx \
    # ExtendHumiliation
    && cp /tmp/ExtendHumiliation.smx . \
    && rm /tmp/ExtendHumiliation.smx \
    && chmod 0664 *.smx \
    # SOAP config for ProperPregame
    && printf "\nsm plugins unload properpregame\n" >> /home/tf2/hlserver/tf2/tf/cfg/sourcemod/soap_live.cfg \
    && printf "\nsm plugins load properpregame\n" >> /home/tf2/hlserver/tf2/tf/cfg/sourcemod/soap_notlive.cfg

# Additional plugins (STAC, MGE, tf2rue, serveme web_rcon)
COPY --chown=tf2:tf2 plugins.sh /tmp/plugins.sh
RUN chmod +x /tmp/plugins.sh && /tmp/plugins.sh && rm /tmp/plugins.sh

# ============================================================
# Stage: tf2-configs (league configs + base configs)
# ============================================================
FROM tf2-plugins AS tf2-configs

# ETF2L configs
RUN cd /home/tf2/hlserver/tf2/tf/cfg \
    && wget -nv "https://github.com/ETF2L/gameserver-configs/releases/latest/download/etf2l_configs.zip" \
    && unzip etf2l_configs.zip \
    && rm *.zip \
    # WaitForSTV handles the stv delay better
    && sed -i 's/tv_delaymapchange_protect\s*"\?1"\?/tv_delaymapchange_protect 0/g' *.cfg

# RGL + ozfortress configs
RUN cd /home/tf2/hlserver/tf2/tf \
    && wget -nv "https://github.com/RGLgg/server-resources-updater/releases/download/v365/server-resources-updater.zip" -O rgl.zip \
    && unzip -o rgl.zip \
    && rm rgl.zip \
    && sed -i '/^sm_updater/d' cfg/rgl_base.cfg \
    && rm -f addons/sourcemod/plugins/rglqol.smx addons/sourcemod/plugins/rglupdater.smx \
    && wget -nv "https://github.com/ozfortress/server-configs/archive/refs/heads/master.tar.gz" -O ozfortress.tar.gz \
    && tar xzf ozfortress.tar.gz --strip-components=1 server-configs-master/cfg/ \
    && rm ozfortress.tar.gz

COPY --chown=tf2:tf2 base-configs/ /home/tf2/hlserver/tf2/tf/

# ============================================================
# Final stage: serveme-specific setup
# ============================================================
FROM tf2-configs

# Bake in ctf_turbine
RUN wget -nv "https://fastdl.serveme.tf/maps/ctf_turbine.bsp" -O "/home/tf2/hlserver/tf2/tf/maps/ctf_turbine.bsp"

# Bake in map list for maplist_override plugin (refreshed at container start)
RUN curl -sf --max-time 30 "https://direct.serveme.tf/api/maps.txt" -o /home/tf2/hlserver/tf2/tf/cfg/maplist_full.txt

# Serveme-specific plugins (.smx files copied from live server)
COPY --chown=tf2:tf2 serveme-plugins/ /home/tf2/hlserver/tf2/tf/addons/sourcemod/plugins/

COPY --chown=tf2:tf2 healthcheck.sh /home/tf2/hlserver/healthcheck.sh
COPY --chown=tf2:tf2 entrypoint.sh /home/tf2/hlserver/entrypoint.sh
RUN chmod +x /home/tf2/hlserver/entrypoint.sh /home/tf2/hlserver/healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /home/tf2/hlserver/healthcheck.sh

EXPOSE 27015/udp 27015/tcp 27020/udp 22/tcp

WORKDIR /home/tf2/hlserver

ENTRYPOINT ["./entrypoint.sh"]
CMD ["+sv_pure", "2", "+maxplayers", "24"]
