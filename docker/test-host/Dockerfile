# Fake host for script/test_docker_host_provisioning. Ubuntu 24.04 + systemd
# + sshd so DockerHostSetupService can SSH in and run its scripts.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

RUN apt-get update && apt-get install -y --no-install-recommends \
        systemd systemd-sysv dbus dbus-user-session \
        openssh-server sudo iproute2 iputils-ping curl ca-certificates gnupg \
        iptables fuse-overlayfs \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && id ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu \
    && install -d -m 0755 -o ubuntu -g ubuntu /home/ubuntu \
    && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
    && chmod 440 /etc/sudoers.d/ubuntu \
    && install -d -m 0700 -o ubuntu -g ubuntu /home/ubuntu/.ssh \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config \
    && install -d -m 0700 -o root -g root /root/.ssh \
    && systemctl enable ssh \
    && rm -f /lib/systemd/system/multi-user.target.wants/getty.target \
            /etc/systemd/system/getty.target.wants/* \
            /lib/systemd/system/anaconda.target.wants/* \
            /lib/systemd/system/plymouth* \
            /lib/systemd/system/systemd-update-utmp*

# Authorized key gets injected at build time.
ARG TEST_SSH_PUBKEY
RUN echo "$TEST_SSH_PUBKEY" > /home/ubuntu/.ssh/authorized_keys \
    && chmod 600 /home/ubuntu/.ssh/authorized_keys \
    && chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys \
    && echo "$TEST_SSH_PUBKEY" > /root/.ssh/authorized_keys \
    && chmod 600 /root/.ssh/authorized_keys

EXPOSE 22 80 443 8083

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
