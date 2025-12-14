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
    this.hideResults()

    this.boundHandleTabKey = this.handleTabKey.bind(this)
    this.queryTarget.addEventListener('keydown', this.boundHandleTabKey)
  }

  disconnect() {
    this.reset()
    this.clearDebounceTimer()

    if (this.boundHandleTabKey) {
      this.queryTarget.removeEventListener('keydown', this.boundHandleTabKey)
      this.boundHandleTabKey = null
    }
  }

  handleTabKey(event) {
    if (event.key === 'Tab') {
      const hasVisibleSuggestions = this.resultsTarget.querySelector('[data-suggestion]') &&
                                   this.resultsTarget.style.display !== 'none';

      if (hasVisibleSuggestions) {
        event.preventDefault()

        if (this.suggestionsResultsController) {
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
          this.resultsTarget.innerHTML = html

          const hasResults = html.trim() !== "" && html.includes("<li");

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

    if (event.keyCode === enterKey) {
      event.preventDefault();

      const hasVisibleSuggestions = this.hasResultsTarget &&
                                   this.resultsTarget.querySelector('[data-suggestion]') &&
                                   this.resultsTarget.style.display !== 'none';

      if (hasVisibleSuggestions && this.suggestionsResultsController) {
        this.suggestionsResultsController.navigateResults(event);
      } else {
        this.submitForm();
      }
      return;
    }

    if (!this.hasResultsTarget) {
      return;
    }

    const hasVisibleSuggestions = this.resultsTarget.querySelector('[data-suggestion]') &&
                                 this.resultsTarget.style.display !== 'none';

    if (!hasVisibleSuggestions) {
      return;
    }

    switch (event.keyCode) {
      case upKey:
      case downKey:
        event.preventDefault();
        if (this.suggestionsResultsController) {
          this.suggestionsResultsController.navigateResults(event);
        }
        break;
      case escapeKey:
        this.reset();
        break;
    }
  }

  submitForm(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }

    const form = this.element.tagName === 'FORM' ?
                 this.element :
                 this.element.closest('form');

    if (!form) {
      console.error('Form element not found');
      return;
    }

    if (this.hasResultsTarget) {
      this.hideResults();
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

      if (this.hasQueryTarget) {
        this.queryTarget.value = '';
      }

      if (this.hasResultsTarget) {
        this.reset();
      } else {
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

    if (element.dataset.suggestion) {
      suggestion = element.dataset.suggestion;
    } else {
      const parent = element.closest('[data-suggestion]');
      if (parent) {
        suggestion = parent.dataset.suggestion;
      } else {
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

  reset() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = "";
      this.hideResults();
    }
    this.previousQuery = null;
  }

  resetForm() {
    const form = this.element.tagName === 'FORM' ?
                 this.element :
                 this.element.closest('form');

    if (form && typeof form.reset === 'function') {
      form.reset();
    }

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
