import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "rawToggle", "allCheckbox", "filterCheckbox"]

  // All possible log types (must match LogLineFormatter event_type symbols)
  static logTypes = [
    'kill', 'suicide', 'assist', 'domination', 'revenge',
    'say', 'team_say', 'console_say', 'rcon',
    'connect', 'disconnect', 'joined_team', 'spawn', 'role_change',
    'round_win', 'round_start', 'round_stalemate', 'round_length',
    'current_score', 'final_score', 'match_end', 'point_capture', 'capture_block',
    'damage', 'headshot_damage', 'airshot',
    'heal', 'airshot_heal', 'pickup_item',
    'charge_ready', 'charge_deployed', 'charge_ended',
    'medic_death', 'medic_death_ex', 'lost_uber_advantage', 'empty_uber', 'first_heal_after_spawn',
    'builtobject', 'killedobject', 'player_extinguished',
    'shot_fired', 'shot_hit', 'position_report',
    'unknown'
  ]

  connect() {
    this.applyFilters()
  }

  toggleAll(event) {
    const showAll = event.target.checked

    // Uncheck all other filters when "All" is checked
    if (showAll) {
      this.filterCheckboxTargets.forEach(checkbox => {
        checkbox.checked = false
      })
    }

    this.applyFilters()
  }

  toggleFilter(event) {
    // Uncheck "All" when any specific filter is checked
    if (event.target.checked && this.hasAllCheckboxTarget) {
      this.allCheckboxTarget.checked = false
    }

    // If no filters are checked, check "All"
    const anyFilterChecked = this.filterCheckboxTargets.some(cb => cb.checked)
    if (!anyFilterChecked && this.hasAllCheckboxTarget) {
      this.allCheckboxTarget.checked = true
    }

    this.applyFilters()
  }

  toggleRaw(event) {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.toggle('raw-view', event.target.checked)
    }
  }

  applyFilters() {
    if (!this.hasContainerTarget) return

    const container = this.containerTarget
    const showAll = this.hasAllCheckboxTarget && this.allCheckboxTarget.checked

    // Defer DOM changes to next frame so checkbox feels responsive
    requestAnimationFrame(() => {
      if (showAll) {
        // Remove all hide classes - show everything
        this.constructor.logTypes.forEach(type => {
          container.classList.remove(`hide-${type}`)
        })
        return
      }

      // Get types that should be VISIBLE (from checked filters)
      const visibleTypes = new Set()
      this.filterCheckboxTargets.forEach(checkbox => {
        if (checkbox.checked) {
          const types = checkbox.dataset.logFilterType.split(',')
          types.forEach(t => visibleTypes.add(t.trim()))
        }
      })

      // Add hide-* classes for types NOT in visibleTypes
      this.constructor.logTypes.forEach(type => {
        const shouldHide = !visibleTypes.has(type)
        container.classList.toggle(`hide-${type}`, shouldHide)
      })
    })
  }

  toggleRawLine(event) {
    // Don't toggle if clicking on a link
    if (event.target.tagName === 'A') return

    const logLine = event.currentTarget
    logLine.classList.toggle('expanded')
  }
}
