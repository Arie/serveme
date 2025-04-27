import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.classList.add("highlight-download");
    setTimeout(() => {
      this.element.classList.remove("highlight-download");
    }, 3000);
    this.element.removeAttribute("data-controller");
  }
}
