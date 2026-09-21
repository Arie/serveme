import { Controller } from "@hotwired/stimulus"

// Bootstrap tooltips for content that Turbo Streams replace every second.
// Delegated, so new elements need no init. A replace removes the hovered
// element and its open tooltip, so that tooltip is shown again afterwards.
export default class extends Controller {
  connect() {
    this.selector = '[data-toggle="tooltip"]'
    this.tooltips = new bootstrap.Tooltip(this.element, { selector: this.selector, html: true })
    this.beforeStreamRender = (event) => {
      const render = event.detail.render
      event.detail.render = async (stream) => {
        const hoveredId = this.element.querySelector(`${this.selector}:hover`)?.id
        this.clear()
        await render(stream)
        this.reshow(hoveredId && document.getElementById(hoveredId))
      }
    }
    document.addEventListener("turbo:before-stream-render", this.beforeStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRender)
    this.tooltips.dispose()
    this.clear()
  }

  // :hover is not recalculated for the replacement until the mouse moves, so
  // the trigger is found by id. The next mouse move hides the tooltip if the
  // mouse has left.
  reshow(trigger) {
    if (!trigger) return

    const tooltip = bootstrap.Tooltip.getOrCreateInstance(trigger, { html: true })
    tooltip.show()
    document.addEventListener("mousemove", () => { if (!trigger.matches(":hover")) tooltip.hide() }, { once: true })
  }

  clear() {
    document.querySelectorAll(".tooltip").forEach((tooltip) => tooltip.remove())
  }
}
