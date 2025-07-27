import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "fileInput",
    "submitButton",
    "progressContainer",
    "progressBar",
    "progressText",
  ];

  connect() {
    this.uploading = false;
  }

  async handleSubmit(e) {
    e.preventDefault();

    const file = this.fileInputTarget.files[0];
    if (!file) {
      alert("Please select a file");
      return;
    }

    if (!file.name.endsWith(".bsp")) {
      alert("Only .bsp files are allowed");
      return;
    }

    const maxSize = 500 * 1024 * 1024;
    if (file.size > maxSize) {
      alert("File size must be less than 500MB");
      return;
    }

    this.setLoading(true);

    try {
      const presignedData = await this.getPresignedUrl(
        file.name,
        "application/octet-stream"
      );
      await this.uploadToR2(file, presignedData);
      await this.completeUpload(presignedData.key, file.name);

      this.showSuccess(
        "Map uploaded successfully. It can take a few minutes for it to get synced to all servers."
      );
      const form = this.element.querySelector("form");
      if (form) form.reset();
    } catch (error) {
      this.showError(error.message || "Upload failed");
    } finally {
      this.setLoading(false);
      this.hideProgressBar();
    }
  }

  async getPresignedUrl(filename, contentType) {
    const response = await fetch("/map_uploads/presigned_url", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCsrfToken(),
      },
      body: JSON.stringify({ filename, content_type: contentType }),
    });

    if (!response.ok) {
      let errorMessage = "Failed to get upload URL";
      try {
        const error = await response.json();
        errorMessage = error.error || errorMessage;
      } catch (e) {
        errorMessage = `HTTP ${response.status}: ${response.statusText}`;
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  async uploadToR2(file, presignedData) {
    this.showProgressBar();

    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      xhr.upload.addEventListener("progress", (e) => {
        if (e.lengthComputable) {
          const percentComplete = (e.loaded / e.total) * 100;
          this.updateProgress(percentComplete);
        }
      });

      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve();
        } else {
          reject(new Error(`Upload failed with status ${xhr.status}`));
        }
      };

      xhr.onerror = () => {
        reject(new Error("Network error during upload"));
      };

      xhr.open("PUT", presignedData.url);
      xhr.setRequestHeader("Content-Type", "application/octet-stream");
      xhr.send(file);
    });
  }

  async completeUpload(key, filename) {
    const response = await fetch("/map_uploads/complete", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCsrfToken(),
      },
      body: JSON.stringify({ key, filename }),
    });

    if (!response.ok) {
      let errorMessage = "Failed to complete upload";
      try {
        const error = await response.json();
        errorMessage = error.error || errorMessage;
      } catch (e) {
        errorMessage = `HTTP ${response.status}: ${response.statusText}`;
      }
      throw new Error(errorMessage);
    }

    return response.json();
  }

  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || "";
  }

  setLoading(loading) {
    this.submitButtonTarget.disabled = loading;
    this.submitButtonTarget.textContent = loading ? "Uploading..." : "Upload";
    this.fileInputTarget.disabled = loading;
  }

  showProgressBar() {
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.style.display = "block";
    }
  }

  updateProgress(percentComplete) {
    if (this.hasProgressBarTarget) {
      const percent = Math.round(percentComplete);
      this.progressBarTarget.style.width = percent + "%";
      this.progressBarTarget.setAttribute("aria-valuenow", percent);
    }
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = Math.round(percentComplete) + "%";
    }
  }

  hideProgressBar() {
    if (this.hasProgressContainerTarget) {
      this.progressContainerTarget.style.display = "none";
      if (this.hasProgressBarTarget) {
        this.progressBarTarget.style.width = "0%";
        this.progressBarTarget.setAttribute("aria-valuenow", 0);
      }
      if (this.hasProgressTextTarget) {
        this.progressTextTarget.textContent = "0%";
      }
    }
  }

  showSuccess(message) {
    this.clearFlashMessages();
    let flashContainer = document.querySelector(".flash-messages");
    if (!flashContainer) {
      flashContainer = document.createElement("div");
      flashContainer.className = "flash-messages";
      this.element.parentElement.insertBefore(flashContainer, this.element);
    }

    const alert = document.createElement("div");
    alert.className = "alert alert-success alert-dismissible fade show";
    alert.textContent = message;

    flashContainer.appendChild(alert);
  }

  showError(message) {
    this.clearFlashMessages();
    let flashContainer = document.querySelector(".flash-messages");
    if (!flashContainer) {
      flashContainer = document.createElement("div");
      flashContainer.className = "flash-messages";
      this.element.parentElement.insertBefore(flashContainer, this.element);
    }

    const alert = document.createElement("div");
    alert.className = "alert alert-danger alert-dismissible fade show";
    alert.textContent = message;

    flashContainer.appendChild(alert);
  }

  clearFlashMessages() {
    const flashContainer = document.querySelector(".flash-messages");
    if (flashContainer) {
      flashContainer.innerHTML = "";
    }
  }
}
