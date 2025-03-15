import { Controller } from "@hotwired/stimulus"

const upKey = 38
const downKey = 40
const enterKey = 13
const escapeKey = 27
const tabKey = 9
const navigationKeys = [upKey, downKey, enterKey, escapeKey]

export default class extends Controller {
  static classes = ["current"]
  static targets = ["result"]

  connect() {
    this.currentResultIndex = -1
    this.selectCurrentResult()
  }

  navigateResults(event) {
    if (event.keyCode === tabKey) {
      return
    }

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
        // Always prevent default for Enter key to prevent Steam overlay from closing
        event.preventDefault()
        if (this.resultTargets.length > 0 && this.currentResultIndex >= 0) {
          this.goToSelectedResult()
        } else {
          // If no result is selected, submit the form via the parent controller
          const parentController = this.application.getControllerForElementAndIdentifier(
            this.element.closest('[data-controller="suggestions"]'),
            "suggestions"
          )
          if (parentController && typeof parentController.submitForm === 'function') {
            parentController.submitForm()
          }
        }
        break;
    }
  }

  // private

  selectCurrentResult() {
    this.resultTargets.forEach((element, index) => {
      element.classList.toggle(this.currentClass, index == this.currentResultIndex)

      // Only scroll if we have a valid selection
      if (index == this.currentResultIndex && this.currentResultIndex >= 0) {
        this.scrollToElement(element)
      }
    })
  }

  scrollToElement(element) {
    if (!element) return

    const container = this.element
    if (!container) return

    const containerRect = container.getBoundingClientRect()
    const elementRect = element.getBoundingClientRect()

    // Add a small margin to make scrolling more user-friendly
    const margin = 5

    // Check if the element is outside the visible area of the container
    if (elementRect.top < containerRect.top + margin) {
      // Element is above the visible area, scroll up
      container.scrollTop += elementRect.top - containerRect.top - margin
    } else if (elementRect.bottom > containerRect.bottom - margin) {
      // Element is below the visible area, scroll down
      container.scrollTop += elementRect.bottom - containerRect.bottom + margin
    }
  }

  selectNextResult() {
    if (this.currentResultIndex < this.resultTargets.length - 1) {
      this.currentResultIndex++
    } else {
      this.currentResultIndex = 0  // Wrap to first item
    }
    this.selectCurrentResult()
  }

  selectPreviousResult() {
    if (this.currentResultIndex > 0) {
      this.currentResultIndex--
    } else {
      this.currentResultIndex = this.resultTargets.length - 1  // Wrap to last item
    }
    this.selectCurrentResult()
  }

  clearResults() {
    this.element.parentElement.innerHTML = ""
    this.element.focus()
  }

  goToSelectedResult() {
    if (this.resultTargets[this.currentResultIndex]) {
      const selectedElement = this.resultTargets[this.currentResultIndex];

      // Find the suggestion value - first try data-suggestion attribute
      let suggestion = selectedElement.dataset.suggestion ||
                       selectedElement.getAttribute('data-suggestion');

      // If not found, look for a child element with the command class
      if (!suggestion) {
        const commandElement = selectedElement.querySelector('.command');
        if (commandElement) {
          suggestion = commandElement.textContent.trim();
        } else {
          suggestion = selectedElement.textContent.trim();
        }
      }

      // Find the parent suggestions controller
      const parentController = this.application.getControllerForElementAndIdentifier(
        this.element.closest('[data-controller="suggestions"]'),
        "suggestions"
      );

      if (parentController && suggestion) {
        // Set the input value
        if (parentController.hasQueryTarget) {
          parentController.queryTarget.value = suggestion;
          parentController.queryTarget.focus();
        }

        // Reset the suggestions
        parentController.reset();
      } else {
        // Fallback to click if we can't find the parent controller or suggestion
        selectedElement.click();
      }
    }
  }
}
