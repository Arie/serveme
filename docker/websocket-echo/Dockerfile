# Backs the Caddy /ping reverse-proxy on every docker host.
# Built on each host at provision time (see DockerHostSetupService).

FROM node:20-alpine

WORKDIR /opt/websocket-echo-server

ARG WS_ECHO_REF=master
RUN apk add --no-cache git \
    && git clone https://github.com/websockets/websocket-echo-server.git . \
    && git checkout "$WS_ECHO_REF" \
    && npm install --omit=dev \
    && apk del git \
    && rm -rf /var/cache/apk/* /tmp/*

ENV BIND_PORT=8083 \
    BIND_ADDRESS=127.0.0.1

EXPOSE 8083
CMD ["node", "index.js"]
