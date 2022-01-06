import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.warnings = false
application.debug = false
window.Stimulus = application

export { application }
