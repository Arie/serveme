import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["messages", "input", "sendButton"];
  static values = {
    defaultPrompt: { type: String, default: "Check for alt accounts, proxy usage, and poor chat behavior for " }
  };

  connect() {
    this.conversationHistory = [];
    // Restore prefilled prompt (browser form restore clears it on soft refresh)
    if (!this.inputTarget.value.trim()) {
      this.inputTarget.value = this.defaultPromptValue;
    }
    this.inputTarget.focus();
    const len = this.inputTarget.value.length;
    this.inputTarget.setSelectionRange(len, len);
  }

  send() {
    const message = this.inputTarget.value.trim();
    if (!message) return;

    this.inputTarget.value = "";
    this.appendMessage("user", message);
    this.conversationHistory.push({ role: "user", content: message });
    this.setEnabled(false);

    this.currentAssistantEl = null;
    this.rawAssistantText = "";
    this.allAssistantText = "";
    this.fetchStream();
  }

  async fetchStream() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

    try {
      const response = await fetch("/league-request/ai", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
        body: JSON.stringify({ messages: this.conversationHistory }),
      });

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop();

        for (const line of lines) {
          if (!line.startsWith("data: ")) continue;
          const json = line.slice(6);
          try {
            const event = JSON.parse(json);
            this.handleEvent(event);
          } catch {
            // skip malformed lines
          }
        }
      }
    } catch (error) {
      this.appendMessage("error", `Connection error: ${error.message}`);
    } finally {
      if (this.allAssistantText) {
        this.conversationHistory.push({
          role: "assistant",
          content: this.allAssistantText,
        });
      }
      this.setEnabled(true);
      this.inputTarget.focus();
    }
  }

  handleEvent(event) {
    switch (event.type) {
      case "token":
        if (!this.currentAssistantEl) {
          this.resolveToolIndicators();
          this.currentAssistantEl = this.appendMessage("assistant", "");
          this.rawAssistantText = "";
        }
        this.rawAssistantText += event.data;
        this.allAssistantText += event.data;
        this.currentAssistantEl.querySelector(".message-text").textContent =
          this.rawAssistantText;
        this.scrollToBottom();
        break;
      case "tool_call":
        // Close current assistant bubble so next round starts a new one
        this.currentAssistantEl = null;
        this.rawAssistantText = "";
        this.appendToolIndicator(event.data.id, event.data.label);
        break;
      case "done":
        this.resolveToolIndicators();
        break;
      case "error":
        this.resolveToolIndicators();
        this.appendMessage("error", event.data);
        break;
    }
  }

  appendMessage(role, text) {
    const wrapper = document.createElement("div");
    wrapper.style.marginBottom = "10px";
    wrapper.style.clear = "both";

    const bubble = document.createElement("div");
    bubble.style.padding = "8px 12px";
    bubble.style.borderRadius = "6px";
    bubble.style.display = "inline-block";
    bubble.style.wordWrap = "break-word";

    const textEl = document.createElement("pre");
    textEl.className = "message-text";
    textEl.style.margin = "0";
    textEl.style.fontFamily = "'SF Mono', 'Cascadia Code', 'Fira Code', 'JetBrains Mono', monospace";
    textEl.style.fontSize = "13px";
    textEl.style.whiteSpace = "pre-wrap";
    textEl.style.wordWrap = "break-word";
    textEl.style.maxWidth = "100%";
    textEl.style.overflowX = "hidden";
    textEl.style.background = "transparent";
    textEl.style.border = "none";
    textEl.style.padding = "0";
    textEl.style.color = "inherit";

    if (role === "user") {
      wrapper.style.textAlign = "right";
      bubble.style.backgroundColor = "#337ab7";
      bubble.style.color = "#fff";
      bubble.style.maxWidth = "60%";
      textEl.textContent = text;
    } else if (role === "assistant") {
      wrapper.style.textAlign = "left";
      bubble.style.backgroundColor = "#1a1a2e";
      bubble.style.color = "#e0e0e0";
      bubble.style.maxWidth = "95%";
      textEl.textContent = text;
    } else if (role === "error") {
      wrapper.style.textAlign = "left";
      bubble.style.backgroundColor = "#a94442";
      bubble.style.color = "#fff";
      bubble.style.maxWidth = "80%";
      textEl.textContent = text;
    }

    bubble.appendChild(textEl);
    wrapper.appendChild(bubble);

    const placeholder = this.messagesTarget.querySelector("p.text-muted");
    if (placeholder) placeholder.remove();

    this.messagesTarget.appendChild(wrapper);
    this.scrollToBottom();
    return wrapper;
  }

  appendToolIndicator(id, label) {
    const indicator = document.createElement("div");
    indicator.style.marginBottom = "8px";
    indicator.style.marginLeft = "4px";
    indicator.style.textAlign = "left";
    indicator.dataset.toolId = id;
    indicator.innerHTML = `<span style="display: inline-block; padding: 4px 10px; background: #2a2a3a; border-left: 3px solid #5bc0de; color: #8cc4e0; font-family: 'SF Mono', 'Cascadia Code', monospace; font-size: 12px;"><span class="glyphicon glyphicon-cog glyphicon-refresh-animate" style="margin-right: 6px;"></span>${this.escapeHtml(label)}</span>`;
    this.messagesTarget.appendChild(indicator);
    this.scrollToBottom();
  }

  resolveToolIndicators() {
    this.messagesTarget
      .querySelectorAll("[data-tool-id] .glyphicon-refresh-animate")
      .forEach((spinner) => {
        spinner.classList.remove("glyphicon-refresh-animate", "glyphicon-cog");
        spinner.classList.add("glyphicon-ok");
      });
  }

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
  }

  setEnabled(enabled) {
    this.inputTarget.disabled = !enabled;
    this.sendButtonTarget.disabled = !enabled;
  }
}
