import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

class PingManager {
  constructor() {
    this.sockets = new Map();
    this.lastPingTime = new Map();
    this.minPingInterval = 1000;
    this.pingCallbacks = new Map();
    this.pingQueue = new Map();
    this.chart = null;
    this.failedServers = new Map();
    this.failureCooldown = 30000; // 30 seconds cooldown
  }

  setChart(chart) {
    this.chart = chart;
  }

  updateChart(ip, ping, isError = false) {
    if (!this.chart) return;

    const datasetIndex = this.chart.data.datasets.findIndex(
      (ds) => ds.label === ip
    );
    if (datasetIndex === -1) return;

    const dataset = this.chart.data.datasets[datasetIndex];
    dataset.data.push(isError ? null : ping);
    if (dataset.data.length > 20) {
      dataset.data.shift();
    }

    dataset.borderColor = isError
      ? "rgba(255, 99, 132, 0.5)"
      : dataset.originalColor;
    dataset.backgroundColor = isError
      ? "rgba(255, 99, 132, 0.1)"
      : dataset.originalColor;

    this.chart.update("none");
  }

  async pingServer(ip, callback) {
    try {
      const now = Date.now();
      const lastPing = this.lastPingTime.get(ip) || 0;
      const timeSinceLastPing = now - lastPing;

      if (timeSinceLastPing < this.minPingInterval) {
        this.pingQueue.set(ip, callback);
        return;
      }

      await this.executePing(ip, callback);
    } catch (error) {
      callback("error");
      this.updateChart(ip, null, true);
    }
  }

  async executePing(ip, callback) {
    this.lastPingTime.set(ip, Date.now());

    try {
      let socket = this.sockets.get(ip);
      let retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          if (!socket || socket.readyState !== WebSocket.OPEN) {
            socket = new WebSocket("wss://" + ip + "/ping");
            this.sockets.set(ip, socket);

            socket.addEventListener("message", (event) => {
              try {
                const callbacks = this.pingCallbacks.get(ip) || [];
                const start = callbacks.shift();
                if (start) {
                  const ping = Date.now() - start;
                  callback(ping + " ms");
                  this.updateChart(ip, ping, false);
                }
                if (callbacks.length === 0) {
                  this.pingCallbacks.delete(ip);
                } else {
                  this.pingCallbacks.set(ip, callbacks);
                }

                this.processQueue(ip);
              } catch (error) {
                callback("error");
                this.updateChart(ip, null, true);
              }
            });

            socket.addEventListener("error", () => {
              try {
                const callbacks = this.pingCallbacks.get(ip) || [];
                callbacks.forEach(() => {
                  callback("error");
                  this.updateChart(ip, null, true);
                });
                this.pingCallbacks.delete(ip);
                this.sockets.delete(ip);
                this.processQueue(ip);
              } catch (error) {}
            });

            socket.addEventListener("close", () => {
              try {
                const callbacks = this.pingCallbacks.get(ip) || [];
                callbacks.forEach(() => {
                  callback("error");
                  this.updateChart(ip, null, true);
                });
                this.pingCallbacks.delete(ip);
                this.sockets.delete(ip);
                this.processQueue(ip);
              } catch (error) {}
            });

            await new Promise((resolve, reject) => {
              const timeout = setTimeout(() => {
                reject(new Error("WebSocket connection timeout"));
              }, 5000);

              socket.addEventListener("open", () => {
                clearTimeout(timeout);
                resolve();
              });
              socket.addEventListener("error", (error) => {
                clearTimeout(timeout);
                reject(error);
              });
            });

            break;
          } else {
            break;
          }
        } catch (error) {
          retryCount++;
          if (retryCount === maxRetries) {
            throw error;
          }
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }
      }

      const start = Date.now();
      let callbacks = this.pingCallbacks.get(ip) || [];
      callbacks.push(start);
      this.pingCallbacks.set(ip, callbacks);

      let timeout = setTimeout(() => {
        try {
          const callbacks = this.pingCallbacks.get(ip) || [];
          const index = callbacks.indexOf(start);
          if (index !== -1) {
            callbacks.splice(index, 1);
            if (callbacks.length === 0) {
              this.pingCallbacks.delete(ip);
            } else {
              this.pingCallbacks.set(ip, callbacks);
            }
            callback("timeout");
            this.updateChart(ip, null, true);
            this.processQueue(ip);
          }
        } catch (error) {}
      }, 5000);

      socket.send("Ping!");
    } catch (error) {
      callback("error");
      this.updateChart(ip, null, true);
      this.processQueue(ip);
    }
  }

  processQueue(ip) {
    try {
      const callback = this.pingQueue.get(ip);
      if (callback) {
        this.pingQueue.delete(ip);
        this.executePing(ip, callback);
      }
    } catch (error) {
      console.error(`Error processing queue for ${ip}:`, error);
    }
  }

  cleanup() {
    this.sockets.forEach((socket) => {
      try {
        socket.close();
      } catch (error) {}
    });
    this.sockets.clear();
    this.pingCallbacks.clear();
    this.pingQueue.clear();
  }
}

window.pingManager = new PingManager();

export default class extends Controller {
  static targets = ["table", "chart", "selected"];

  connect() {
    try {
      if (this.hasTableTarget) {
        this.rows = Array.from(
          this.tableTarget.querySelectorAll("tr[data-ip]")
        );
        if (this.rows.length > 0) {
          if (this.hasChartTarget) {
            this.initializeChart();
          }
          this.rows.forEach((row) => {
            const pingCell = row.querySelector(".ping");
            if (pingCell) pingCell.textContent = "Checking...";
          });
          this.startPingCycle();
        }
      }

      if (this.hasSelectedTarget) {
        this.setupServerSelection();
        document.addEventListener("server-ping-update", (event) => {
          const { ip, ping } = event.detail;
          const serverSelect = $("#reservation_server_id");
          if (serverSelect.length && serverSelect.val()) {
            const selectedServer = free_servers.find(
              (server) => server.id == serverSelect.val()
            );
            if (selectedServer && selectedServer.ip === ip) {
              this.selectedTarget.value = ping;
            }
          }
        });
      }
    } catch (error) {
      console.error("Error in ping controller connect:", error);
    }
  }

  disconnect() {
    if (this.pingTimeout) {
      clearTimeout(this.pingTimeout);
    }
    document.removeEventListener("server-ping-update", this.handlePingUpdate);
    if (window.pingManager) {
      window.pingManager.cleanup();
    }
  }

  setupServerSelection() {
    const serverSelect = $("#reservation_server_id");
    if (!serverSelect.length) return;

    serverSelect.on("change", () => {
      const selectedServer = free_servers.find(
        (server) => server.id == serverSelect.val()
      );
      if (selectedServer && selectedServer.ip) {
        const modalElement = document.querySelector(
          "#pingsModal #server-pings[data-controller='ping']"
        );
        if (modalElement) {
          const row = modalElement.querySelector(
            `tr[data-ip="${selectedServer.ip}"]`
          );
          if (row) {
            const pingCell = row.querySelector(".ping");
            if (pingCell) {
              this.selectedTarget.value = pingCell.textContent;
            }
          }
        }
      }
    });
  }

  startPingCycle() {
    try {
      this.rows.forEach((row) => {
        const ip = row.dataset.ip;
        if (!ip) return;

        const pingCell = row.querySelector(".ping");
        if (!pingCell) return;

        const updatePing = (result) => {
          pingCell.textContent = result;
          if (result === "error" || result === "timeout") {
            pingCell.classList.add("text-danger");
            pingCell.title = "Server is not responding";
          } else {
            pingCell.classList.remove("text-danger");
            pingCell.title = "";
          }

          const event = new CustomEvent("server-ping-update", {
            detail: { ip, ping: result },
          });
          document.dispatchEvent(event);

          if (this.hasChartTarget) {
            const ping = parseInt(result);
            if (!isNaN(ping)) {
              const datasetIndex = this.chart.data.datasets.findIndex(
                (ds) => ds.label === ip
              );
              if (datasetIndex !== -1) {
                const dataset = this.chart.data.datasets[datasetIndex];
                dataset.data.push(ping);
                if (dataset.data.length > 20) {
                  dataset.data.shift();
                }
                this.chart.update("none");
              }
            }
          }
        };

        window.pingManager.pingServer(ip, updatePing);
      });

      this.pingTimeout = setTimeout(() => this.startPingCycle(), 1000);
    } catch (error) {
      this.pingTimeout = setTimeout(() => this.startPingCycle(), 1000);
    }
  }

  initializeChart() {
    const ctx = this.chartTarget.getContext("2d");
    const datasets = this.rows.map((row) => {
      const ip = row.dataset.ip;
      const color = this.getRandomColor();
      return {
        label: ip,
        data: Array(20).fill(null),
        borderColor: color,
        backgroundColor: color + "20",
        originalColor: color,
        fill: false,
        tension: 0.4,
        pointRadius: 0,
        spanGaps: true,
      };
    });

    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: Array(20).fill(""),
        datasets: datasets,
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        interaction: {
          mode: "index",
          intersect: false,
        },
        scales: {
          y: {
            beginAtZero: true,
            suggestedMin: 0,
            suggestedMax: 100,
            grid: {
              color: "rgba(255, 255, 255, 0.1)",
            },
            ticks: {
              color: "rgba(255, 255, 255, 0.7)",
              callback: function (value) {
                return value + "ms";
              },
            },
          },
          x: {
            display: false,
            grid: {
              color: "rgba(255, 255, 255, 0.1)",
            },
          },
        },
        plugins: {
          legend: {
            labels: {
              color: "rgba(255, 255, 255, 0.7)",
            },
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
      },
    });
  }

  getRandomColor() {
    const colors = [
      "#FF5252",
      "#4CAF50",
      "#2196F3",
      "#FFC107",
      "#9C27B0",
      "#FF5722",
      "#00BCD4",
      "#FFEB3B",
      "#E91E63",
      "#3F51B5",
      "#009688",
      "#FF9800",
      "#795548",
      "#607D8B",
      "#8BC34A",
      "#CDDC39",
      "#FF4081",
      "#7C4DFF",
      "#00E5FF",
      "#FFD740",
    ];

    if (!this.usedColors) {
      this.usedColors = new Set();
    }

    const availableColors = colors.filter(
      (color) => !this.usedColors.has(color)
    );
    if (availableColors.length === 0) {
      this.usedColors.clear();
      return colors[0];
    }

    const color = availableColors[0];
    this.usedColors.add(color);
    return color;
  }
}
