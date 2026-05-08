// Minimal websocket echo server with a GET /health endpoint for
// kamal-proxy's healthcheck (the upstream websockets/websocket-echo-server
// returns 426 on every HTTP path, which kamal-proxy rejects).
const http = require("http");
const { WebSocketServer } = require("ws");

const port = parseInt(process.env.BIND_PORT || "8083", 10);
const host = process.env.BIND_ADDRESS || "0.0.0.0";

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end("ok");
  } else {
    res.writeHead(426, { "Content-Type": "text/plain", Connection: "close" });
    res.end("Upgrade Required");
  }
});

const wss = new WebSocketServer({ server });
wss.on("connection", (ws) => {
  ws.on("message", (msg, isBinary) => ws.send(msg, { binary: isBinary }));
});

server.listen(port, host, () => {
  console.log(`ws-echo listening on ${host}:${port}`);
});
