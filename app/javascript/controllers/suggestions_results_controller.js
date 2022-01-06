import { Controller } from "@hotwired/stimulus"

const upKey = 38
const downKey = 40
const enterKey = 13
const escapeKey = 27
const navigationKeys = [upKey, downKey, enterKey, escapeKey]

export default class extends Controller {
  static classes = ["current"]
  static targets = ["result"]

  connect() {
    this.currentResultIndex = 0
    this.selectCurrentResult()
  }

  navigateResults(event) {
    if (!navigationKeys.includes(event.keyCode)) {
      return
    }

    switch (event.keyCode) {
      case downKey:
        event.preventDefault()
        this.selectNextResult()
        break;
      case upKey:
        event.preventDefault()
        this.selectPreviousResult()
        break;
      case escapeKey:
        this.clearResults()
        break;
      case enterKey:
        if (this.resultTargets.length > 0) {
          event.preventDefault()
          this.goToSelectedResult()
          break;
        }
    }
  }

  // private

  selectCurrentResult() {
    this.resultTargets.forEach((element, index) => {
      element.classList.toggle(this.currentClass, index == this.currentResultIndex)
    })
  }

  selectNextResult() {
    if (this.currentResultIndex < this.resultTargets.length - 1) {
      this.currentResultIndex++
      this.selectCurrentResult()
    }
  }

  selectPreviousResult() {
    if (this.currentResultIndex > 0) {
      this.currentResultIndex--
      this.selectCurrentResult()
    }
  }

  clearResults() {
    this.element.parentElement.innerHTML = ""
    this.element.focus()
  }

  goToSelectedResult() {
    if (this.resultTargets[this.currentResultIndex]) {
      this.resultTargets[this.currentResultIndex].click()
    }
  }
}