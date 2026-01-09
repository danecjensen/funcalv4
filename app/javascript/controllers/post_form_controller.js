import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["eventFields"]

  toggleEvent() {
    const fields = this.eventFieldsTarget
    if (fields.style.display === "none") {
      fields.style.display = "block"
    } else {
      fields.style.display = "none"
    }
  }
}
