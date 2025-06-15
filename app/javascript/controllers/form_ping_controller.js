import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["selected"];

  connect() {
    console.log("Form ping controller connecting...");
    if (this.hasSelectedTarget) {
      console.log("Selected target found, setting up server selection");
      this.setupServerSelection();
      this.triggerInitialPing();
    } else {
      console.log("No selected target found");
    }
  }

  setupServerSelection() {
    const serverSelect = document.querySelector("#reservation_server_id");
    console.log("Setting up server selection for:", serverSelect);
    if (!serverSelect) return;

    serverSelect.addEventListener("change", () => {
      console.log("Server selection changed");
      const selectedValue = serverSelect.value;
      if (!selectedValue) return;

      const selectedServer = free_servers.find(
        (server) => server.id == selectedValue
      );
      console.log("Selected server:", selectedServer);
      if (selectedServer && selectedServer.ip) {
        this.updateSelectedServerPing(selectedServer.ip);
      }
    });
  }

  triggerInitialPing() {
    const serverSelect = document.querySelector("#reservation_server_id");
    if (serverSelect && serverSelect.value) {
      const selectedValue = serverSelect.value;
      const selectedServer = free_servers.find(
        (server) => server.id == selectedValue
      );
      console.log("Initial ping for server:", selectedServer);
      if (selectedServer && selectedServer.ip) {
        this.updateSelectedServerPing(selectedServer.ip);
      }
    }
  }

  updateSelectedServerPing(ip) {
    console.log("Updating ping for IP:", ip);
    if (!ip) return;

    window.pingManager.pingServer(ip, (result) => {
      console.log("Ping result:", result);
      if (this.hasSelectedTarget) {
        console.log("Setting ping value to:", result);
        this.selectedTarget.value = result;
      }
    });
  }
}
