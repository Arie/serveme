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

# Download additional plugins (STAC, MGE, tf2rue, funcommands, funvotes)
COPY --chown=tf2:tf2 plugins.sh /tmp/plugins.sh
RUN chmod +x /tmp/plugins.sh && /tmp/plugins.sh && rm /tmp/plugins.sh

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
