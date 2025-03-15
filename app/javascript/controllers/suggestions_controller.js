// based on https://github.com/mrhead/stimulus-search
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results"]
  static values = {
    url: String,
    debounce: { type: Number, default: 150 },
    preventDefaultSubmission: { type: Boolean, default: false }
  }

  connect() {
    this.debounceTimer = null
    // Ensure results container is hidden on connect
    this.hideResults()

    // Add event listener for tab key
    this.boundHandleTabKey = this.handleTabKey.bind(this)
    this.queryTarget.addEventListener('keydown', this.boundHandleTabKey)
  }

  disconnect() {
    this.reset()
    this.clearDebounceTimer()

    // Remove event listener for tab key
    if (this.boundHandleTabKey) {
      this.queryTarget.removeEventListener('keydown', this.boundHandleTabKey)
      this.boundHandleTabKey = null
    }
  }

  handleTabKey(event) {
    // Check if the key pressed is Tab
    if (event.key === 'Tab') {
      // If there are results and the results container is visible
      const hasVisibleSuggestions = this.resultsTarget.querySelector('[data-suggestion]') &&
                                   this.resultsTarget.style.display !== 'none';

      if (hasVisibleSuggestions) {
        event.preventDefault() // Prevent default tab behavior

        if (this.suggestionsResultsController) {
          // Forward or backward navigation based on shift key
          if (event.shiftKey) {
            this.suggestionsResultsController.selectPreviousResult()
          } else {
            this.suggestionsResultsController.selectNextResult()
          }
        }
      }
    }
  }

  fetchResults() {
    if (!this.hasResultsTarget) return;

    if (this.query == "") {
      this.reset()
      return
    }

    if (this.query == this.previousQuery) {
      return
    }

    // For very short queries (1-2 chars), use a longer debounce
    // For longer queries, use a shorter debounce for snappier response
    const debounceTime = this.query.length <= 2 ? this.debounceValue : Math.max(50, this.debounceValue / 2)

    this.clearDebounceTimer()

    this.debounceTimer = setTimeout(() => {
      this.previousQuery = this.query

      const url = new URL(this.urlValue)
      url.searchParams.append("query", this.query)

      this.abortPreviousFetchRequest()

      this.abortController = new AbortController()
      fetch(url, { signal: this.abortController.signal })
        .then(response => response.text())
        .then(html => {
          // First, update the innerHTML
          this.resultsTarget.innerHTML = html

          // Check if there are actual results in the HTML
          const hasResults = html.trim() !== "" && html.includes("<li");

          // Show or hide based on results
          if (hasResults) {
            this.showResults();
          } else {
            this.hideResults();
          }
        })
        .catch((error) => {
          console.error("Error fetching autocomplete results:", error);
        })
    }, debounceTime)
  }

  navigateResults(event) {
    const upKey = 38;
    const downKey = 40;
    const enterKey = 13;
    const escapeKey = 27;

    // Always prevent default for Enter key to prevent Steam overlay from closing
    if (event.keyCode === enterKey) {
      event.preventDefault();

      // Check if we have visible suggestions
      const hasVisibleSuggestions = this.hasResultsTarget &&
                                   this.resultsTarget.querySelector('[data-suggestion]') &&
                                   this.resultsTarget.style.display !== 'none';

      if (hasVisibleSuggestions && this.suggestionsResultsController) {
        // If we have visible suggestions, let the suggestions controller handle it
        this.suggestionsResultsController.navigateResults(event);
      } else {
        // Otherwise, submit the form
        this.submitForm();
      }
      return;
    }

    // If we don't have a results target, we can't navigate further
    if (!this.hasResultsTarget) {
      return;
    }

    // Check if we have visible suggestions for other navigation keys
    const hasVisibleSuggestions = this.resultsTarget.querySelector('[data-suggestion]') &&
                                 this.resultsTarget.style.display !== 'none';

    if (!hasVisibleSuggestions) {
      return;
    }

    // Handle other navigation keys
    switch (event.keyCode) {
      case upKey:
      case downKey:
        event.preventDefault(); // Prevent cursor movement
        if (this.suggestionsResultsController) {
          this.suggestionsResultsController.navigateResults(event);
        }
        break;
      case escapeKey:
        this.reset();
        break;
    }
  }

  // Handle form submission event
  submitForm(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }

    // Find the actual form element
    const form = this.element.tagName === 'FORM' ?
                 this.element :
                 this.element.closest('form');

    if (!form) {
      console.error('Form element not found');
      return;
    }

    const formData = new FormData(form);
    const url = form.action;
    const method = form.method || 'post';

    fetch(url, {
      method: method,
      body: formData,
      headers: {
        'Accept': 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml'
      }
    })
    .then(response => response.text())
    .then(html => {
      // Process Turbo Stream response
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');
      const turboStreamElements = doc.querySelectorAll('turbo-stream');

      if (turboStreamElements.length > 0) {
        turboStreamElements.forEach(streamElement => {
          const template = document.createElement('template');
          template.innerHTML = streamElement.outerHTML;
          Turbo.renderStreamMessage(template.innerHTML);
        });
      }

      // Clear the input field instead of resetting the form
      if (this.hasQueryTarget) {
        this.queryTarget.value = '';
      }

      // Clear results if we have the results target
      if (this.hasResultsTarget) {
        this.reset();
      } else {
        // If we don't have the results target, we're in the parent controller
        // Find the nested suggestions controller and reset it
        const nestedController = this.application.controllers.find(
          c => c.context.identifier === 'suggestions' &&
               c !== this &&
               c.element.closest('[data-controller="suggestions"]') === this.element
        );

        if (nestedController && nestedController.hasResultsTarget) {
          nestedController.reset();
        }
      }
    })
    .catch(error => {
      console.error('Error submitting form:', error);
    });
  }

  fillInput(event) {
    const element = event.currentTarget;
    let suggestion = null;

    // First try data-suggestion attribute
    if (element.dataset.suggestion) {
      suggestion = element.dataset.suggestion;
    } else {
      // If the clicked element doesn't have the suggestion data attribute,
      // look for it in the parent elements
      const parent = element.closest('[data-suggestion]');
      if (parent) {
        suggestion = parent.dataset.suggestion;
      } else {
        // If still not found, look for a child element with the command class
        const commandElement = element.querySelector('.command');
        if (commandElement) {
          suggestion = commandElement.textContent.trim();
        } else {
          suggestion = element.textContent.trim();
        }
      }
    }

    if (suggestion && this.hasQueryTarget) {
      this.queryTarget.value = suggestion;
      this.queryTarget.focus();
      this.reset();
    }
  }

  // private

  reset() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = "";
      this.hideResults();
    }
    this.previousQuery = null;
  }

  resetForm() {
    // Find the form element
    const form = this.element.tagName === 'FORM' ?
                 this.element :
                 this.element.closest('form');

    if (form && typeof form.reset === 'function') {
      form.reset();
    }

    // Clear the input field
    if (this.hasQueryTarget) {
      this.queryTarget.value = '';
    }

    this.reset();
  }

  hideResults() {
    if (!this.hasResultsTarget) return;

    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.style.display = "none"
    this.resultsTarget.style.visibility = "hidden"
    this.resultsTarget.style.height = "0"
    this.resultsTarget.style.overflow = "hidden"
  }

  showResults() {
    if (!this.hasResultsTarget) return;

    this.resultsTarget.classList.remove("hidden")
    this.resultsTarget.style.display = "block"
    this.resultsTarget.style.visibility = "visible"
    this.resultsTarget.style.height = "auto"
    this.resultsTarget.style.maxHeight = "300px"
    this.resultsTarget.style.overflow = "auto"
  }

  clearDebounceTimer() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
      this.debounceTimer = null
    }
  }

  abortPreviousFetchRequest() {
    if (this.abortController) {
      this.abortController.abort()
    }
  }

  get query() {
    return this.queryTarget.value
  }

  get suggestionsResultsController() {
    if (!this.hasResultsTarget || !this.resultsTarget.firstElementChild) {
      return null;
    }
    return this.application.getControllerForElementAndIdentifier(this.resultsTarget.firstElementChild, "suggestions-results")
  }
}
