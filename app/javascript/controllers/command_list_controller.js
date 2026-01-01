import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "input", "search", "commandItem"]

  connect() {
    // Initialize the controller
  }

  show(event) {
    event.preventDefault()
    this.listTarget.classList.toggle('show')

    // Focus the search input when opening
    if (this.listTarget.classList.contains('show') && this.hasSearchTarget) {
      this.searchTarget.value = ''
      this.searchTarget.focus()
      this.filterCommands('')
    }
  }

  hide() {
    this.listTarget.classList.remove('show')
  }

  selectCommand(event) {
    event.preventDefault()
    const command = event.currentTarget.getAttribute('data-command')
    this.inputTarget.value = command
    this.inputTarget.focus()
    this.hide()
  }

  filterCommands(event) {
    const searchTerm = (event?.target?.value || '').toLowerCase()

    this.commandItemTargets.forEach(item => {
      const commandText = item.getAttribute('data-command-text').toLowerCase()
      const commandDesc = item.getAttribute('data-command-desc').toLowerCase()
      const matches = commandText.includes(searchTerm) || commandDesc.includes(searchTerm)
      item.classList.toggle('hidden', !matches)
    })
  }
}
