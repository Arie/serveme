# Built on each docker host at provision time (see DockerHostSetupService).
# Floating `caddy:2-*` tags pull whatever the latest 2.x is at build time.

FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
