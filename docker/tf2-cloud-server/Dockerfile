FROM spiretf/docker-comp-server

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        iptables \
        curl \
        sudo \
        iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && ssh-keygen -A \
    && echo "tf2 ALL=(ALL) NOPASSWD: /sbin/iptables, /usr/sbin/iptables, /usr/sbin/sshd" > /etc/sudoers.d/tf2 \
    && chmod 0440 /etc/sudoers.d/tf2

USER tf2

# Update TF2 to latest version (base image may be behind)
# SteamCMD sometimes fails with 0x426 on first attempt, retry once
# Then strip maps and resource files to minimize image size (like base image's clean.sh)
RUN /usr/games/steamcmd +force_install_dir /home/tf2/hlserver/tf2 +login anonymous +app_update 232250 +quit || \
    /usr/games/steamcmd +force_install_dir /home/tf2/hlserver/tf2 +login anonymous +app_update 232250 +quit \
    && cd /home/tf2/hlserver/tf2/tf/maps && rm -f *.bsp \
    && rm -f /home/tf2/hlserver/tf2/tf/resource/tf_*.txt

# Download additional plugins (STAC, MGE, tf2rue, funcommands, funvotes)
COPY --chown=tf2:tf2 plugins.sh /tmp/plugins.sh
RUN chmod +x /tmp/plugins.sh && /tmp/plugins.sh && rm /tmp/plugins.sh

# RGL configs, whitelists, and plugins (v365)
RUN cd /home/tf2/hlserver/tf2/tf \
    && wget -nv "https://github.com/RGLgg/server-resources-updater/releases/download/v365/server-resources-updater.zip" -O rgl.zip \
    && unzip -o rgl.zip \
    && rm rgl.zip \
    && sed -i '/^sm_updater/d' cfg/rgl_base.cfg \
    && rm -f addons/sourcemod/plugins/rglqol.smx addons/sourcemod/plugins/rglupdater.smx

# ozfortress configs and whitelists
RUN cd /home/tf2/hlserver/tf2/tf \
    && wget -nv "https://github.com/ozfortress/server-configs/archive/refs/heads/master.tar.gz" -O ozfortress.tar.gz \
    && tar xzf ozfortress.tar.gz --strip-components=1 server-configs-master/cfg/ \
    && rm ozfortress.tar.gz

# Bake in ctf_turbine (stock map is VPK-packed, we need the .bsp for changelevel)
RUN wget -nv "https://fastdl.serveme.tf/maps/ctf_turbine.bsp" -O "/home/tf2/hlserver/tf2/tf/maps/ctf_turbine.bsp"

# Add serveme-specific plugins (.smx files copied from live server)
COPY --chown=tf2:tf2 serveme-plugins/ /home/tf2/hlserver/tf2/tf/addons/sourcemod/plugins/

COPY --chown=tf2:tf2 entrypoint.sh /home/tf2/hlserver/entrypoint.sh
RUN chmod +x /home/tf2/hlserver/entrypoint.sh

EXPOSE 27015/udp 27015/tcp 27020/udp 22/tcp

WORKDIR /home/tf2/hlserver

ENTRYPOINT ["./entrypoint.sh"]
CMD ["+sv_pure", "2", "+maxplayers", "24"]
