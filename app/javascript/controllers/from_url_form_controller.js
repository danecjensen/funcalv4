import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["formContent", "loading", "heading", "subtitle", "progressBar"]

  submit() {
    this.formContentTarget.style.display = "none"
    this.loadingTarget.style.display = "block"
    this.headingTarget.textContent = "Extracting Events..."
    this.subtitleTarget.textContent = "Scanning the page with AI — hang tight."
    this.startProgress()
  }

  startProgress() {
    this.startTime = Date.now()
    this.duration = 20000
    this.animate()
  }

  animate() {
    const elapsed = Date.now() - this.startTime
    const pct = Math.min((elapsed / this.duration) * 100, 95)
    this.progressBarTarget.style.width = `${pct}%`

    if (pct < 95) {
      requestAnimationFrame(() => this.animate())
    }
  }
}
