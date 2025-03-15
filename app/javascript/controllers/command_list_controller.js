import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "input", "search", "commandItem"]

  connect() {
    // Initialize the controller
  }

  show(event) {
    event.preventDefault()

    // Toggle the command list
    if (this.listTarget.style.display === 'block') {
      this.hide()
    } else {
      this.showList()
    }
  }

  showList() {
    this.listTarget.style.display = 'block'

    // Focus the search input if it exists
    if (this.hasSearchTarget) {
      this.searchTarget.value = ''
      this.searchTarget.focus()
      this.filterCommands('')
    }
  }

  hide() {
    this.listTarget.style.display = 'none'
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

      if (commandText.includes(searchTerm) || commandDesc.includes(searchTerm)) {
        item.style.display = 'block'
      } else {
        item.style.display = 'none'
      }
    })
  }
}
