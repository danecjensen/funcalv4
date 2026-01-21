import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  toggleForm() {
    if (this.hasFormTarget) {
      this.formTarget.classList.toggle('visible')

      // Focus first input when opening
      if (this.formTarget.classList.contains('visible')) {
        const firstInput = this.formTarget.querySelector('input[type="text"]')
        if (firstInput) {
          setTimeout(() => firstInput.focus(), 100)
        }
      }
    }
  }
}
