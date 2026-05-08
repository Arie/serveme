# Minimal websocket echo server for the /ping latency tester. Adds a
# GET /health endpoint so kamal-proxy's healthcheck can pass (the
# upstream websockets/websocket-echo-server returns 426 on every HTTP
# path).
#
# Used by config/deploy.ws-echo.yml (regional /ping) and pushed
# separately to Docker Hub for DockerHostSetupService cloud hosts.
FROM node:20-alpine

WORKDIR /opt/websocket-echo

COPY package.json ./
RUN npm install --omit=dev && rm -rf ~/.npm /tmp/*

COPY index.js ./

ENV BIND_PORT=8083 \
    BIND_ADDRESS=0.0.0.0

EXPOSE 8083
CMD ["node", "index.js"]
