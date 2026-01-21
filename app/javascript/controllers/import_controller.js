import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url"]

  selectSource(event) {
    // Update visual selection
    const sources = this.element.querySelectorAll('.import-source')
    sources.forEach(source => source.classList.remove('selected'))
    event.currentTarget.classList.add('selected')
  }

  detectSource() {
    if (!this.hasUrlTarget) return

    const url = this.urlTarget.value.toLowerCase()
    let sourceValue = 'other'

    if (url.includes('google.com') || url.includes('googleapis.com')) {
      sourceValue = 'google'
    } else if (url.includes('apple.com') || url.includes('icloud.com')) {
      sourceValue = 'apple'
    }

    // Find and check the appropriate radio button
    const radioButton = this.element.querySelector(`input[name="calendar[import_source]"][value="${sourceValue}"]`)
    if (radioButton) {
      radioButton.checked = true

      // Update visual selection
      const sources = this.element.querySelectorAll('.import-source')
      sources.forEach(source => source.classList.remove('selected'))
      radioButton.closest('.import-source').classList.add('selected')
    }
  }
}
