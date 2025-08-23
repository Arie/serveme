import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateInput"]
  static values = {
    format: String,
    showMeridian: Boolean
  }

  extendDate(event) {
    const days = parseInt(event.currentTarget.dataset.days)
    let date

    const existingExpiration = this.dateInputTarget.value

    if (existingExpiration && existingExpiration.trim() !== '') {
      if (existingExpiration.includes('T')) {
        date = new Date(existingExpiration)
      } else {
        date = this.parseDateFromFormat(existingExpiration, this.formatValue)
      }
    } else {
      date = new Date()
    }

    date.setDate(date.getDate() + days)

    if (this.dateInputTarget.type === 'datetime-local') {
      const formattedDate = this.formatForDatetimeLocal(date)
      this.dateInputTarget.value = formattedDate
    } else {
      const formattedDate = this.formatDateToLocale(date, this.formatValue, this.showMeridianValue)
      this.dateInputTarget.value = formattedDate
    }

    this.dateInputTarget.dispatchEvent(new Event('change'))
  }

  clearDate() {
    this.dateInputTarget.value = ''
    this.dateInputTarget.dispatchEvent(new Event('change'))
  }

  parseDateFromFormat(dateString, format) {
    let day, month, year, hours = 23, minutes = 59, isPM = false

    if (format.includes('mm/dd/yyyy')) {
      const parts = dateString.split(' ')
      const dateParts = parts[0].split('/')
      const timeParts = parts[1] ? parts[1].split(':') : ['11', '59']
      isPM = parts[2] && parts[2].toLowerCase() === 'pm'

      month = parseInt(dateParts[0]) - 1
      day = parseInt(dateParts[1])
      year = parseInt(dateParts[2])
      hours = parseInt(timeParts[0])
      minutes = parseInt(timeParts[1])

      if (isPM && hours !== 12) hours += 12
      if (!isPM && hours === 12) hours = 0

    } else {
      const parts = dateString.split(' ')
      const dateParts = parts[0].split('-')
      const timeParts = parts[1] ? parts[1].split(':') : ['23', '59']
      isPM = parts[2] && parts[2].toLowerCase() === 'pm'

      day = parseInt(dateParts[0])
      month = parseInt(dateParts[1]) - 1
      year = parseInt(dateParts[2])
      hours = parseInt(timeParts[0])
      minutes = parseInt(timeParts[1])

      if (format.includes('p')) {
        if (isPM && hours !== 12) hours += 12
        if (!isPM && hours === 12) hours = 0
      }
    }

    return new Date(year, month, day, hours, minutes)
  }

  formatDateToLocale(date, format, showMeridian) {
    const day = String(date.getDate()).padStart(2, '0')
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const year = date.getFullYear()
    let hours = date.getHours()
    const minutes = String(date.getMinutes()).padStart(2, '0')

    if (format.includes('mm/dd/yyyy')) {
      const period = showMeridian ? (hours >= 12 ? ' PM' : ' AM') : ''
      if (showMeridian) {
        hours = hours % 12
        if (hours === 0) hours = 12
      }
      const hoursStr = String(hours).padStart(2, '0')
      return `${month}/${day}/${year} ${hoursStr}:${minutes}${period}`

    } else {
      const period = showMeridian ? (hours >= 12 ? ' PM' : ' AM') : ''
      if (showMeridian) {
        hours = hours % 12
        if (hours === 0) hours = 12
      }
      const hoursStr = String(hours).padStart(2, '0')
      return `${day}-${month}-${year} ${hoursStr}:${minutes}${period}`
    }
  }

  formatForDatetimeLocal(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')

    return `${year}-${month}-${day}T${hours}:${minutes}`
  }
}
