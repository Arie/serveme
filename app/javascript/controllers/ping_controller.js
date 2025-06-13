import { Controller } from "@hotwired/stimulus";
import { Chart } from "chart.js";

export default class extends Controller {
  static targets = ["table"];

  connect() {
    this.pingManager = new PingManager();
    this.rows = Array.from(this.tableTarget.querySelectorAll("tr[data-ip]"));
    this.initializeCharts();
    this.startPingCycle();
  }

  disconnect() {
    this.pingManager.cleanup();
  }

  initializeCharts() {
    this.rows.forEach((row) => {
      const ip = row.dataset.ip;
      const canvas = row.querySelector(".ping-graph");
      this.pingManager.initChart(canvas, ip);
    });
  }

  async startPingCycle() {
    let isFirstCycle = true;
    const cycle = async () => {
      await this.pingManager.pingAll(this.rows);
      if (isFirstCycle) {
        isFirstCycle = false;
        cycle();
      } else {
        setTimeout(cycle, 1000);
      }
    };
    cycle();
  }
}

class PingManager {
  constructor() {
    this.sockets = {};
    this.isPinging = false;
    this.pingHistory = {};
    this.charts = {};
    this.maxHistoryLength = 20;
  }

  updateChart(ip, ping) {
    if (!this.charts[ip]) return;

    const chart = this.charts[ip];
    const data = chart.data.datasets[0].data;

    data.push(ping);
    if (data.length > this.maxHistoryLength) {
      data.shift();
    }

    chart.update("none");
  }

  initChart(canvas, ip) {
    const ctx = canvas.getContext("2d");
    this.charts[ip] = new Chart(ctx, {
      type: "line",
      data: {
        labels: Array(this.maxHistoryLength).fill(""),
        datasets: [
          {
            data: Array(this.maxHistoryLength).fill(null),
            borderColor: "rgb(75, 192, 192)",
            tension: 0.1,
            pointRadius: 0,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false,
        },
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            callbacks: {
              label: function (context) {
                return `${context.parsed.y}ms`;
              },
            },
          },
        },
        scales: {
          x: {
            display: false,
          },
          y: {
            type: "linear",
            beginAtZero: true,
            display: true,
            min: 0,
            max: 150,
            ticks: {
              display: true,
              callback: function (value) {
                return value + "ms";
              },
            },
          },
        },
        animation: false,
      },
    });
  }

  async ping(ip) {
    return new Promise((resolve) => {
      if (!this.sockets[ip] || this.sockets[ip].readyState !== WebSocket.OPEN) {
        try {
          this.sockets[ip] = new WebSocket("wss://" + ip + "/ping");

          return new Promise((connectResolve) => {
            this.sockets[ip].onopen = () => {
              connectResolve();
            };
            this.sockets[ip].onerror = () => {
              resolve("error");
            };
          }).then(() => {
            const socket = this.sockets[ip];
            const start = Date.now();
            let timeout;

            const cleanup = () => {
              clearTimeout(timeout);
              socket.removeEventListener("message", onMessage);
              socket.removeEventListener("error", onError);
              socket.removeEventListener("close", onClose);
            };

            const onMessage = () => {
              cleanup();
              const ping = Date.now() - start;
              this.updateChart(ip, ping);
              resolve(ping);
            };

            const onError = () => {
              cleanup();
              resolve("error");
            };

            const onClose = () => {
              cleanup();
              resolve("error");
            };

            timeout = setTimeout(() => {
              cleanup();
              resolve("timeout");
            }, 5000);

            socket.addEventListener("message", onMessage);
            socket.addEventListener("error", onError);
            socket.addEventListener("close", onClose);

            socket.send("Ping!");
          });
        } catch (e) {
          resolve("error");
        }
      } else {
        const socket = this.sockets[ip];
        const start = Date.now();
        let timeout;

        const cleanup = () => {
          clearTimeout(timeout);
          socket.removeEventListener("message", onMessage);
          socket.removeEventListener("error", onError);
          socket.removeEventListener("close", onClose);
        };

        const onMessage = () => {
          cleanup();
          const ping = Date.now() - start;
          this.updateChart(ip, ping);
          resolve(ping);
        };

        const onError = () => {
          cleanup();
          resolve("error");
        };

        const onClose = () => {
          cleanup();
          resolve("error");
        };

        timeout = setTimeout(() => {
          cleanup();
          resolve("timeout");
        }, 5000);

        socket.addEventListener("message", onMessage);
        socket.addEventListener("error", onError);
        socket.addEventListener("close", onClose);

        socket.send("Ping!");
      }
    });
  }

  async pingAll(rows) {
    if (this.isPinging) return;
    this.isPinging = true;

    try {
      await Promise.all(
        rows.map(async (row) => {
          const ip = row.dataset.ip;
          const result = await this.ping(ip);
          const pingCell = row.querySelector(".ping");
          if (typeof result === "number") {
            pingCell.textContent = result + " ms";
          } else {
            pingCell.textContent = result;
          }
        })
      );
    } finally {
      this.isPinging = false;
    }
  }

  cleanup() {
    Object.values(this.sockets).forEach((socket) => {
      try {
        socket.close();
      } catch (e) {
        // Ignore errors from already closed sockets
      }
    });
    this.sockets = {};
  }
}
