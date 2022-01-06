// based on https://github.com/mrhead/stimulus-search
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results"]
  static values = { url: String }

  disconnect() {
    this.reset()
  }

  fetchResults() {
    if (this.query == "") {
      this.reset()
      return
    }

    if (this.query == this.previousQuery) {
      return
    }
    this.previousQuery = this.query

    const url = new URL(this.urlValue)
    url.searchParams.append("query", this.query)

    this.abortPreviousFetchRequest()

    this.abortController = new AbortController()
    fetch(url, { signal: this.abortController.signal })
      .then(response => response.text())
      .then(html => {
        this.resultsTarget.innerHTML = html
      })
      .catch(() => { })
  }

  navigateResults(event) {
    if (this.suggestionsResultsController) {
      this.suggestionsResultsController.navigateResults(event)
    }
  }

  fillInput(event) {
    const element = event.target
    this.queryTarget.value = element.dataset.suggestion
    this.queryTarget.focus()
    this.resultsTarget.innerHTML = ""
  }

  // private

  reset() {
    this.resultsTarget.innerHTML = ""
    this.queryTarget.value = ""
    this.previousQuery = null
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
    return this.application.getControllerForElementAndIdentifier(this.resultsTarget.firstElementChild, "suggestions-results")
  }
}