import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js";
Chart.register(...registerables);

export default class extends Controller {
    static targets = ['myChart'];
    static values = {
        chartData: Object,
        chartType: String
    }

    connect() {
        if (this.chartDataValue) {
            this.initializeChart();
        }
    }

    initializeChart() {
        const ctx = this.myChartTarget.getContext('2d');
        const data = this.chartDataValue;

        new Chart(ctx, {
            type: 'bar',
            data: {
                labels: data.labels,
                datasets: [{
                    label: data.title,
                    data: data.values,
                    backgroundColor: 'rgba(0, 68, 204, 0.8)',
                    borderColor: 'rgb(16, 119, 255)',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: data.yAxisLabel || ''
                        }
                    }
                }
            }
        });
    }
}
