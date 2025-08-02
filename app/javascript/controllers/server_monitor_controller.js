import { Controller } from "@hotwired/stimulus";
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

export default class extends Controller {
  static targets = [
    "serverSelect",
    "startButton",
    "stopButton",
    "fpsChart",
    "networkChart",
    "pingChart",
    "lossChart",
  ];
  static values = { servers: Array };

  connect() {
    this.isMonitoring = false;
    this.pollInterval = null;
    this.charts = {};
    this.maxDataPoints = 60;
  }

  disconnect() {
    this.stop();
    this.destroyExistingCharts();
  }

  onServerChange() {
    // Server change is now handled by the jQuery populateServerFields function
    // which automatically starts monitoring
  }

  start() {
    // Stop any existing monitoring first to prevent multiple intervals
    if (this.isMonitoring) {
      this.stop();
    }

    // Check if server is selected
    const serverId = this.serverSelectTarget.value;

    if (!serverId) {
      alert("Please select a server to monitor");
      return;
    }

    this.isMonitoring = true;
    this.startButtonTarget.disabled = true;
    this.stopButtonTarget.disabled = false;
    this.serverSelectTarget.disabled = true;

    // Clear any existing chart data and reinitialize
    this.clearChartData();
    this.initializeCharts();

    this.startPolling(serverId);
  }

  clearChartData() {
    // Clear data from existing charts without destroying them
    Object.values(this.charts).forEach((chart) => {
      if (chart && chart.data) {
        chart.data.datasets.forEach((dataset) => {
          dataset.data = Array(this.maxDataPoints).fill(null);
        });
        // For ping and loss charts, also clear all datasets since players will be different
        if (chart === this.charts.ping || chart === this.charts.loss) {
          chart.data.datasets = [];
        }
        chart.update("none");
      }
    });
  }

  stop() {
    this.isMonitoring = false;
    this.startButtonTarget.disabled = false;
    this.stopButtonTarget.disabled = true;
    this.serverSelectTarget.disabled = false;

    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }

    // Don't destroy charts on stop - just clear the interval
    // Charts will be reused when starting again
  }

  startPolling(serverId) {
    // Poll immediately, then every second
    this.pollServer(serverId);

    this.pollInterval = setInterval(() => {
      if (this.isMonitoring) {
        this.pollServer(serverId);
      }
    }, 1000); // Poll every second
  }


  async pollServer(serverId) {
    try {
      const response = await fetch("/server-monitoring/poll", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            .content,
        },
        body: `server_id=${serverId}`,
      });

      if (response.ok) {
        const turboStreamHTML = await response.text();

        // Check for authentication errors in the response
        if (this.checkForAuthenticationError(turboStreamHTML)) {
          return;
        }

        // Let Turbo handle the stream response
        Turbo.renderStreamMessage(turboStreamHTML);

        // Update charts after turbo stream updates the DOM, but only if monitoring is active
        if (this.isMonitoring) {
          setTimeout(() => this.updateChartsFromData(), 100);
        }
      } else {
        console.error("Poll request failed:", response.status);
        if (response.status === 403) {
          this.handleAuthenticationError(
            "Authentication failed - stopping monitoring"
          );
        }
      }
    } catch (error) {
      console.error("Error polling server:", error);
      this.handleAuthenticationError("Network error - stopping monitoring");
    }
  }


  updateChartsFromData() {
    const metricsData = document.querySelector(".server-metrics-data");
    if (!metricsData) return;

    const timestamp = new Date().toLocaleTimeString();
    const data = {
      fps: parseFloat(metricsData.dataset.fps) || 0,
      trafficIn: parseFloat(metricsData.dataset.trafficIn) || 0,
      trafficOut: parseFloat(metricsData.dataset.trafficOut) || 0,
      playerPings: JSON.parse(metricsData.dataset.playerPings || "[]"),
    };

    // Update FPS chart
    this.updateChart("fps", data.fps, timestamp, "FPS", "#4CAF50");

    // Update network chart (both in and out)
    this.updateNetworkChart(data.trafficIn, data.trafficOut, timestamp);

    // Update player pings chart
    this.updatePlayerPingsChart(data.playerPings, timestamp);

    // Update player loss chart
    this.updatePlayerLossChart(data.playerPings, timestamp);
  }

  updateChart(chartKey, value, timestamp, label, color) {
    const chart = this.charts[chartKey];
    if (!chart) return;

    // Add new data point
    chart.data.datasets[0].data.push(value);

    // Remove old data points (keep fixed size)
    if (chart.data.datasets[0].data.length > this.maxDataPoints) {
      chart.data.datasets[0].data.shift();
    }

    chart.update("none");
  }

  updateNetworkChart(trafficIn, trafficOut, timestamp) {
    const chart = this.charts.network;
    if (!chart) return;

    // Add new data points
    chart.data.datasets[0].data.push(trafficIn); // Traffic In
    chart.data.datasets[1].data.push(trafficOut); // Traffic Out

    // Remove old data points (keep fixed size)
    if (chart.data.datasets[0].data.length > this.maxDataPoints) {
      chart.data.datasets[0].data.shift();
      chart.data.datasets[1].data.shift();
    }

    chart.update("none");
  }

  updatePlayerPingsChart(playerPings, timestamp) {
    const chart = this.charts.ping;
    if (!chart) return;

    // Update or create datasets for each player
    playerPings.forEach((player, index) => {
      let dataset = chart.data.datasets[index];

      if (!dataset) {
        // Create new dataset for this player
        const color = this.getPlayerColor(index);
        dataset = {
          label: player.name,
          data: Array(this.maxDataPoints).fill(null),
          borderColor: color,
          backgroundColor: color + "20",
          fill: false,
          tension: 0.4,
          pointRadius: 1,
          pointHoverRadius: 3,
          spanGaps: true,
        };
        chart.data.datasets.push(dataset);
      }

      // Add current ping and shift if needed
      dataset.data.push(player.ping);
      if (dataset.data.length > this.maxDataPoints) {
        dataset.data.shift();
      }

      // Update label in case player name changed
      dataset.label = player.name;
    });

    // Remove datasets for players who left
    if (chart.data.datasets.length > playerPings.length) {
      chart.data.datasets.splice(playerPings.length);
    }

    // Calculate dynamic Y-axis scale based on current ping values
    this.updatePingChartScale(chart);

    chart.update("none");
  }

  updatePlayerLossChart(playerPings, timestamp) {
    const chart = this.charts.loss;
    if (!chart) return;

    // Update or create datasets for each player
    playerPings.forEach((player, index) => {
      let dataset = chart.data.datasets[index];

      if (!dataset) {
        // Create new dataset for this player
        const color = this.getPlayerColor(index);
        dataset = {
          label: player.name,
          data: Array(this.maxDataPoints).fill(null),
          borderColor: color,
          backgroundColor: color + "20",
          fill: false,
          tension: 0.4,
          pointRadius: 1,
          pointHoverRadius: 3,
          spanGaps: true,
        };
        chart.data.datasets.push(dataset);
      }

      // Add current loss and shift if needed
      dataset.data.push(player.loss);
      if (dataset.data.length > this.maxDataPoints) {
        dataset.data.shift();
      }

      // Update label in case player name changed
      dataset.label = player.name;
    });

    // Remove datasets for players who left
    if (chart.data.datasets.length > playerPings.length) {
      chart.data.datasets.splice(playerPings.length);
    }

    chart.update("none");
  }

  updatePingChartScale(chart) {
    // Collect all current ping values from all datasets
    let allPings = [];
    chart.data.datasets.forEach((dataset) => {
      dataset.data.forEach((ping) => {
        if (ping !== null && ping !== undefined) {
          allPings.push(ping);
        }
      });
    });

    if (allPings.length === 0) {
      // No data yet, use default scale
      chart.options.scales.y.max = 100;
      return;
    }

    const maxPing = Math.max(...allPings);
    const minPing = Math.min(...allPings);

    // Add some padding above max ping (20% or at least 20ms)
    const padding = Math.max(maxPing * 0.2, 20);
    const suggestedMax = Math.ceil((maxPing + padding) / 10) * 10; // Round up to nearest 10

    // Set minimum scale to at least 50ms for small ping values
    chart.options.scales.y.max = Math.max(suggestedMax, 50);
  }

  initializeCharts() {
    this.destroyExistingCharts();

    if (this.hasFpsChartTarget) {
      this.charts.fps = this.createChart(this.fpsChartTarget, {
        label: "FPS",
        color: "#4CAF50",
        yAxisLabel: "Frames Per Second",
        suggestedMax: 100,
      });
    }

    // Initialize Network Chart (dual dataset)
    if (this.hasNetworkChartTarget) {
      this.charts.network = this.createNetworkChart(this.networkChartTarget);
    }

    // Initialize Player Pings Chart
    if (this.hasPingChartTarget) {
      this.charts.ping = this.createPlayerPingsChart(this.pingChartTarget);
    }

    // Initialize Player Loss Chart
    if (this.hasLossChartTarget) {
      this.charts.loss = this.createPlayerLossChart(this.lossChartTarget);
    }
  }

  destroyExistingCharts() {
    Object.values(this.charts).forEach((chart) => {
      if (chart && typeof chart.destroy === "function") {
        chart.destroy();
      }
    });
    this.charts = {};
  }

  createChart(canvas, options) {
    const ctx = canvas.getContext("2d");

    const chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: Array(this.maxDataPoints).fill(""),
        datasets: [
          {
            label: options.label,
            data: Array(this.maxDataPoints).fill(null),
            borderColor: options.color,
            backgroundColor: options.color + "20",
            fill: false,
            tension: 0.4,
            pointRadius: 2,
            pointHoverRadius: 4,
          },
        ],
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
            suggestedMax: options.suggestedMax,
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            title: {
              display: true,
              text: options.yAxisLabel,
            },
          },
          x: {
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            ticks: {
              maxTicksLimit: 10,
            },
          },
        },
        plugins: {
          legend: {
            display: true,
            position: "top",
          },
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: {
              labelColor: function(context) {
                return {
                  borderColor: context.dataset.borderColor,
                  backgroundColor: context.dataset.borderColor, // Use solid color instead of transparent
                };
              },
            },
          },
        },
      },
    });

    return chart;
  }

  createNetworkChart(canvas) {
    const ctx = canvas.getContext("2d");

    return new Chart(ctx, {
      type: "line",
      data: {
        labels: Array(this.maxDataPoints).fill(""),
        datasets: [
          {
            label: "Traffic In (KB/s)",
            data: Array(this.maxDataPoints).fill(null),
            borderColor: "#00BCD4",
            backgroundColor: "#00BCD420",
            fill: false,
            tension: 0.4,
            pointRadius: 2,
            pointHoverRadius: 4,
          },
          {
            label: "Traffic Out (KB/s)",
            data: Array(this.maxDataPoints).fill(null),
            borderColor: "#FF9800",
            backgroundColor: "#FF980020",
            fill: false,
            tension: 0.4,
            pointRadius: 2,
            pointHoverRadius: 4,
          },
        ],
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
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            title: {
              display: true,
              text: "Bandwidth (KB/s)",
            },
          },
          x: {
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            ticks: {
              maxTicksLimit: 10,
            },
          },
        },
        plugins: {
          legend: {
            display: true,
            position: "top",
          },
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: {
              label: function (context) {
                return `${context.dataset.label}: ${context.parsed.y.toFixed(
                  2
                )} KB/s`;
              },
              labelColor: function(context) {
                return {
                  borderColor: context.dataset.borderColor,
                  backgroundColor: context.dataset.borderColor, // Use solid color instead of transparent
                };
              },
            },
          },
        },
      },
    });
  }

  createPlayerPingsChart(canvas) {
    const ctx = canvas.getContext("2d");

    return new Chart(ctx, {
      type: "line",
      data: {
        labels: Array(this.maxDataPoints).fill(""),
        datasets: [], // Will be populated dynamically when players are detected
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
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            title: {
              display: true,
              text: "Ping (ms)",
            },
          },
          x: {
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            ticks: {
              maxTicksLimit: 10,
            },
          },
        },
        plugins: {
          legend: {
            display: true,
            position: "top",
            labels: {
              usePointStyle: true,
              generateLabels: function(chart) {
                const labels = Chart.defaults.plugins.legend.labels.generateLabels(chart);
                
                labels.forEach((label, index) => {
                  const dataset = chart.data.datasets[index];
                  if (dataset) {
                    // Use solid colors for both text and legend square
                    label.color = dataset.borderColor;
                    label.fillStyle = dataset.borderColor; // Make the square solid, not transparent
                    label.strokeStyle = dataset.borderColor;
                  }
                });
                
                return labels;
              }
            },
          },
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: {
              label: function (context) {
                const value = context.parsed.y;
                return `${context.dataset.label}: ${
                  value === null ? "no data" : value + "ms"
                }`;
              },
              labelColor: function(context) {
                return {
                  borderColor: context.dataset.borderColor,
                  backgroundColor: context.dataset.borderColor, // Use solid color instead of transparent
                };
              },
            },
          },
        },
      },
    });
  }

  createPlayerLossChart(canvas) {
    const ctx = canvas.getContext("2d");

    return new Chart(ctx, {
      type: "line",
      data: {
        labels: Array(this.maxDataPoints).fill(""),
        datasets: [], // Will be populated dynamically when players are detected
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
            suggestedMax: 10,
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            title: {
              display: true,
              text: "Loss (%)",
            },
          },
          x: {
            grid: {
              color: "rgba(0, 0, 0, 0.1)",
            },
            ticks: {
              maxTicksLimit: 10,
            },
          },
        },
        plugins: {
          legend: {
            display: true,
            position: "top",
            labels: {
              usePointStyle: true,
              generateLabels: function(chart) {
                const labels = Chart.defaults.plugins.legend.labels.generateLabels(chart);
                
                labels.forEach((label, index) => {
                  const dataset = chart.data.datasets[index];
                  if (dataset) {
                    // Use solid colors for both text and legend square
                    label.color = dataset.borderColor;
                    label.fillStyle = dataset.borderColor; // Make the square solid, not transparent
                    label.strokeStyle = dataset.borderColor;
                  }
                });
                
                return labels;
              }
            },
          },
          tooltip: {
            mode: "index",
            intersect: false,
            callbacks: {
              label: function (context) {
                const value = context.parsed.y;
                return `${context.dataset.label}: ${
                  value === null ? "no data" : value + "%"
                }`;
              },
              labelColor: function(context) {
                return {
                  borderColor: context.dataset.borderColor,
                  backgroundColor: context.dataset.borderColor, // Use solid color instead of transparent
                };
              },
            },
          },
        },
      },
    });
  }

  checkForAuthenticationError(turboStreamHTML) {
    // Check for common authentication error messages
    const authErrors = [
      "Not authenticated yet",
      "Authentication failed",
      "RCON authentication failed",
      "Connection refused",
      "Invalid RCON password",
    ];

    for (const errorText of authErrors) {
      if (turboStreamHTML.includes(errorText)) {
        this.handleAuthenticationError(
          `Authentication error detected: ${errorText}`
        );
        return true;
      }
    }
    return false;
  }

  handleAuthenticationError(message) {
    console.error("Authentication error:", message);

    // Stop monitoring
    this.stop();

    // Show alert to user
    alert(
      `Server monitoring stopped: ${message}\n\nPlease check your server credentials and try again.`
    );
  }

  getPlayerColor(index) {
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
      "#FF8A65",
      "#A1C181",
      "#B39DDB",
      "#F8BBD9",
    ];
    return colors[index % colors.length];
  }

}
