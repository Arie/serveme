import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

const COLORS = [
  "rgb(75, 192, 192)",
  "rgb(255, 99, 132)",
  "rgb(54, 162, 235)",
  "rgb(255, 206, 86)",
  "rgb(153, 102, 255)",
  "rgb(255, 159, 64)",
  "rgb(199, 199, 199)",
  "rgb(83, 102, 255)",
  "rgb(40, 159, 64)",
  "rgb(210, 199, 199)",
];

export default class extends Controller {
  static targets = ["table", "chart"];

  connect() {
    try {
      if (!this.hasChartTarget) {
        console.error("Chart target not found");
        return;
      }
      if (!this.hasTableTarget) {
        console.error("Table target not found");
        return;
      }

      this.pingManager = new PingManager(this.chartTarget);
      this.rows = Array.from(this.tableTarget.querySelectorAll("tr[data-ip]"));

      if (this.rows.length === 0) {
        console.error("No server rows found");
        return;
      }

      this.initializeChart();
      this.startPingCycle();
    } catch (error) {
      console.error("Error in ping controller connect:", error);
    }
  }

  disconnect() {
    try {
      if (this.pingManager) {
        this.pingManager.cleanup();
      }
    } catch (error) {
      console.error("Error in ping controller disconnect:", error);
    }
  }

  initializeChart() {
    try {
      const datasets = this.rows.map((row, index) => ({
        label: row.dataset.ip,
        data: Array(this.pingManager.maxHistoryLength).fill(null),
        borderColor: COLORS[index % COLORS.length],
        tension: 0.1,
        pointRadius: 0,
      }));

      this.pingManager.initChart(datasets);
    } catch (error) {
      console.error("Error initializing chart:", error);
    }
  }

  async startPingCycle() {
    try {
      let isFirstCycle = true;
      const cycle = async () => {
        try {
          await this.pingManager.pingAll(this.rows);
          if (isFirstCycle) {
            isFirstCycle = false;
            cycle();
          } else {
            setTimeout(cycle, 1000);
          }
        } catch (error) {
          setTimeout(cycle, 1000); // Keep trying even if there's an error
        }
      };
      cycle();
    } catch (error) {
      console.error("Error starting ping cycle:", error);
    }
  }
}

class PingManager {
  constructor(canvas) {
    try {
      this.canvas = canvas;
      this.sockets = {};
      this.isPinging = false;
      this.chart = null;
      this.maxHistoryLength = 20;
    } catch (error) {
      console.error("Error initializing PingManager:", error);
    }
  }

  updateChart(ip, ping, isError = false) {
    try {
      if (!this.chart) {
        console.error("Chart not initialized");
        return;
      }

      const datasetIndex = this.chart.data.datasets.findIndex(
        (ds) => ds.label === ip
      );
      if (datasetIndex === -1) {
        console.error(`No dataset found for IP ${ip}`);
        return;
      }

      const dataset = this.chart.data.datasets[datasetIndex];
      dataset.data.push(isError ? null : ping);
      if (dataset.data.length > this.maxHistoryLength) {
        dataset.data.shift();
      }

      dataset.borderColor = isError
        ? "rgba(255, 99, 132, 0.5)"
        : dataset.originalColor;
      dataset.backgroundColor = isError
        ? "rgba(255, 99, 132, 0.1)"
        : dataset.originalColor;

      this.chart.update("none");
    } catch (error) {
      console.error("Error updating chart:", error);
    }
  }

  initChart(datasets) {
    try {
      const ctx = this.canvas.getContext("2d");

      this.chart = new Chart(ctx, {
        type: "line",
        data: {
          labels: Array(this.maxHistoryLength).fill(""),
          datasets: datasets.map((ds) => ({
            ...ds,
            originalColor: ds.borderColor,
            data: Array(this.maxHistoryLength).fill(null),
            spanGaps: true,
          })),
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
              display: true,
              position: "top",
            },
            tooltip: {
              callbacks: {
                label: function (context) {
                  const value = context.parsed.y;
                  return `${context.dataset.label}: ${value === null ? "error" : value + "ms"}`;
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
              suggestedMin: 50,
              suggestedMax: 150,
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
    } catch (error) {
      console.error("Error initializing chart:", error);
    }
  }

  async ping(ip) {
    return new Promise((resolve) => {
      try {
        if (
          !this.sockets[ip] ||
          this.sockets[ip].readyState !== WebSocket.OPEN
        ) {
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
      } catch (error) {
        console.error("Error in ping:", error);
        resolve("error");
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
            this.updateChart(ip, result, false);
          } else {
            pingCell.textContent = result;
            this.updateChart(ip, null, true);
          }
        })
      );
    } catch (error) {
      console.error("Error in pingAll:", error);
    } finally {
      this.isPinging = false;
    }
  }

  cleanup() {
    try {
      Object.values(this.sockets).forEach((socket) => {
        try {
          socket.close();
        } catch (e) {
          // Ignore errors from already closed sockets
        }
      });
      this.sockets = {};
    } catch (error) {
      console.error("Error in cleanup:", error);
    }
  }
}
